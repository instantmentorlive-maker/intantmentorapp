import 'dart:math' as math;
import 'package:dio/dio.dart';
import '../utils/logger.dart';

/// Request retry configuration and policies
class RetryConfig {
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool enableJitter;
  final List<int> retryStatusCodes;
  final List<DioExceptionType> retryExceptionTypes;

  const RetryConfig({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.enableJitter = true,
    this.retryStatusCodes = const [408, 429, 500, 502, 503, 504],
    this.retryExceptionTypes = const [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ],
  });

  @override
  String toString() {
    return 'RetryConfig('
        'maxRetries: $maxRetries, '
        'baseDelay: ${baseDelay.inMilliseconds}ms, '
        'backoffMultiplier: $backoffMultiplier'
        ')';
  }
}

/// HTTP request retry interceptor with exponential backoff
class HttpRetryInterceptor extends Interceptor {
  final RetryConfig config;
  final math.Random _random = math.Random();

  HttpRetryInterceptor({
    this.config = const RetryConfig(),
  });

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    final extra = err.requestOptions.extra;
    final currentAttempt = (extra['retry_attempt'] as int?) ?? 0;

    if (currentAttempt >= config.maxRetries) {
      Logger.warning('Max retry attempts (${config.maxRetries}) reached for ${err.requestOptions.path}');
      return handler.next(err);
    }

    final nextAttempt = currentAttempt + 1;
    final delay = _calculateDelay(nextAttempt);

    Logger.info('Retrying request ${err.requestOptions.path} (attempt $nextAttempt/${config.maxRetries}) after ${delay.inMilliseconds}ms');

    // Wait before retrying
    await Future.delayed(delay);

    try {
      // Clone the original request options
      final retryOptions = err.requestOptions.copyWith();
      retryOptions.extra['retry_attempt'] = nextAttempt;

      // Create a new Dio instance to avoid interceptor recursion
      final dio = Dio();
      
      // Copy essential configuration from original request
      dio.options.baseUrl = err.requestOptions.baseUrl;
      dio.options.headers = Map.from(err.requestOptions.headers);
      dio.options.connectTimeout = err.requestOptions.connectTimeout;
      dio.options.receiveTimeout = err.requestOptions.receiveTimeout;
      dio.options.sendTimeout = err.requestOptions.sendTimeout;

      final response = await dio.fetch(retryOptions);
      
      Logger.info('Retry successful for ${err.requestOptions.path} on attempt $nextAttempt');
      return handler.resolve(response);
    } catch (e) {
      Logger.warning('Retry attempt $nextAttempt failed for ${err.requestOptions.path}: $e');
      
      if (e is DioException) {
        // Update the error with the new attempt count
        e.requestOptions.extra['retry_attempt'] = nextAttempt;
        return onError(e, handler);
      } else {
        // Convert non-Dio errors to DioException
        final newError = DioException(
          requestOptions: err.requestOptions,
          error: e,
          type: DioExceptionType.unknown,
          message: e.toString(),
        );
        newError.requestOptions.extra['retry_attempt'] = nextAttempt;
        return onError(newError, handler);
      }
    }
  }

  /// Check if error should be retried
  bool _shouldRetry(DioException error) {
    // Check status code
    final statusCode = error.response?.statusCode;
    if (statusCode != null && config.retryStatusCodes.contains(statusCode)) {
      return true;
    }

    // Check exception type
    if (config.retryExceptionTypes.contains(error.type)) {
      return true;
    }

    // Don't retry client errors (4xx except specific ones)
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      // Only retry specific 4xx errors
      return config.retryStatusCodes.contains(statusCode);
    }

    return false;
  }

  /// Calculate delay for retry with exponential backoff and jitter
  Duration _calculateDelay(int attemptNumber) {
    // Exponential backoff: baseDelay * (backoffMultiplier ^ (attemptNumber - 1))
    final exponentialDelay = config.baseDelay.inMilliseconds * 
        math.pow(config.backoffMultiplier, attemptNumber - 1);

    var delayMs = math.min(exponentialDelay, config.maxDelay.inMilliseconds).round();

    // Add jitter to prevent thundering herd
    if (config.enableJitter) {
      final jitterMs = _random.nextInt((delayMs * 0.1).round() + 1);
      delayMs = delayMs + jitterMs;
    }

    return Duration(milliseconds: delayMs);
  }
}

/// Request options extension for retry configuration
extension RequestRetryOptions on RequestOptions {
  /// Set retry configuration for this request
  void setRetryConfig(RetryConfig config) {
    extra['retry_config'] = config;
  }

  /// Get retry configuration for this request
  RetryConfig getRetryConfig() {
    return extra['retry_config'] as RetryConfig? ?? const RetryConfig();
  }

  /// Get current retry attempt number
  int get retryAttempt => (extra['retry_attempt'] as int?) ?? 0;

  /// Check if this request has retry configuration
  bool get hasRetryConfig => extra.containsKey('retry_config');
}

/// Retry policy presets for common scenarios
class RetryPolicies {
  /// Conservative policy for critical operations
  static const conservative = RetryConfig(
    maxRetries: 2,
    baseDelay: Duration(seconds: 2),
    backoffMultiplier: 1.5,
    retryStatusCodes: [500, 502, 503, 504],
  );

  /// Aggressive policy for non-critical operations
  static const aggressive = RetryConfig(
    maxRetries: 5,
    baseDelay: Duration(milliseconds: 500),
    backoffMultiplier: 2.0,
    retryStatusCodes: [408, 429, 500, 502, 503, 504],
  );

  /// Network-focused policy for connection issues
  static const networkFocused = RetryConfig(
    maxRetries: 4,
    baseDelay: Duration(seconds: 1),
    backoffMultiplier: 2.0,
    retryStatusCodes: [408, 502, 503, 504],
    retryExceptionTypes: [
      DioExceptionType.connectionTimeout,
      DioExceptionType.connectionError,
    ],
  );

  /// Rate-limit aware policy
  static const rateLimitAware = RetryConfig(
    maxRetries: 3,
    baseDelay: Duration(seconds: 5),
    backoffMultiplier: 2.0,
    retryStatusCodes: [429, 503],
  );
}

/// Retry statistics tracker
class RetryStats {
  int totalRequests = 0;
  int retriedRequests = 0;
  int successfulRetries = 0;
  int failedRetries = 0;
  final Map<int, int> retriesByAttempt = {};
  final Map<int, int> retriesByStatusCode = {};

  void recordRequest() {
    totalRequests++;
  }

  void recordRetry(int attempt, int? statusCode) {
    if (attempt == 1) {
      retriedRequests++;
    }
    
    retriesByAttempt[attempt] = (retriesByAttempt[attempt] ?? 0) + 1;
    
    if (statusCode != null) {
      retriesByStatusCode[statusCode] = (retriesByStatusCode[statusCode] ?? 0) + 1;
    }
  }

  void recordSuccess() {
    successfulRetries++;
  }

  void recordFailure() {
    failedRetries++;
  }

  double get retryRate => totalRequests > 0 ? (retriedRequests / totalRequests) : 0.0;
  double get successRate => retriedRequests > 0 ? (successfulRetries / retriedRequests) : 0.0;

  Map<String, dynamic> toJson() => {
    'totalRequests': totalRequests,
    'retriedRequests': retriedRequests,
    'successfulRetries': successfulRetries,
    'failedRetries': failedRetries,
    'retryRate': retryRate,
    'successRate': successRate,
    'retriesByAttempt': retriesByAttempt,
    'retriesByStatusCode': retriesByStatusCode,
  };

  void reset() {
    totalRequests = 0;
    retriedRequests = 0;
    successfulRetries = 0;
    failedRetries = 0;
    retriesByAttempt.clear();
    retriesByStatusCode.clear();
  }

  @override
  String toString() {
    return 'RetryStats('
        'total: $totalRequests, '
        'retried: $retriedRequests (${(retryRate * 100).toStringAsFixed(1)}%), '
        'success: $successfulRetries (${(successRate * 100).toStringAsFixed(1)}%)'
        ')';
  }
}
