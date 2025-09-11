import 'dart:collection';
import 'package:dio/dio.dart';
import '../utils/logger.dart';

/// HTTP request performance metrics
class RequestMetrics {
  final String id;
  final String method;
  final String url;
  final DateTime startTime;
  final DateTime? endTime;
  final int? statusCode;
  final int? responseSize;
  final Duration? totalDuration;
  final Duration? connectionTime;
  final Duration? dnsTime;
  final Duration? sslTime;
  final Duration? serverProcessingTime;
  final bool fromCache;
  final int retryCount;
  final String? errorType;
  final Map<String, dynamic> metadata;

  RequestMetrics({
    required this.id,
    required this.method,
    required this.url,
    required this.startTime,
    this.endTime,
    this.statusCode,
    this.responseSize,
    this.totalDuration,
    this.connectionTime,
    this.dnsTime,
    this.sslTime,
    this.serverProcessingTime,
    this.fromCache = false,
    this.retryCount = 0,
    this.errorType,
    this.metadata = const {},
  });

  bool get isCompleted => endTime != null;
  bool get isSuccess => statusCode != null && statusCode! >= 200 && statusCode! < 400;
  bool get isError => statusCode != null && statusCode! >= 400;

  RequestMetrics copyWith({
    DateTime? endTime,
    int? statusCode,
    int? responseSize,
    Duration? totalDuration,
    Duration? connectionTime,
    Duration? dnsTime,
    Duration? sslTime,
    Duration? serverProcessingTime,
    bool? fromCache,
    int? retryCount,
    String? errorType,
    Map<String, dynamic>? metadata,
  }) {
    return RequestMetrics(
      id: id,
      method: method,
      url: url,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      statusCode: statusCode ?? this.statusCode,
      responseSize: responseSize ?? this.responseSize,
      totalDuration: totalDuration ?? this.totalDuration,
      connectionTime: connectionTime ?? this.connectionTime,
      dnsTime: dnsTime ?? this.dnsTime,
      sslTime: sslTime ?? this.sslTime,
      serverProcessingTime: serverProcessingTime ?? this.serverProcessingTime,
      fromCache: fromCache ?? this.fromCache,
      retryCount: retryCount ?? this.retryCount,
      errorType: errorType ?? this.errorType,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'method': method,
    'url': url,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'statusCode': statusCode,
    'responseSize': responseSize,
    'totalDuration': totalDuration?.inMilliseconds,
    'connectionTime': connectionTime?.inMilliseconds,
    'dnsTime': dnsTime?.inMilliseconds,
    'sslTime': sslTime?.inMilliseconds,
    'serverProcessingTime': serverProcessingTime?.inMilliseconds,
    'fromCache': fromCache,
    'retryCount': retryCount,
    'errorType': errorType,
    'isSuccess': isSuccess,
    'isError': isError,
    'metadata': metadata,
  };
}

/// Performance statistics for HTTP operations
class PerformanceStats {
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final int cachedRequests;
  final Duration averageResponseTime;
  final Duration p50ResponseTime;
  final Duration p95ResponseTime;
  final Duration p99ResponseTime;
  final double successRate;
  final double cacheHitRate;
  final int averageResponseSize;
  final Map<String, int> statusCodeDistribution;
  final Map<String, int> errorTypeDistribution;
  final Map<String, Duration> endpointPerformance;

  PerformanceStats({
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.cachedRequests,
    required this.averageResponseTime,
    required this.p50ResponseTime,
    required this.p95ResponseTime,
    required this.p99ResponseTime,
    required this.successRate,
    required this.cacheHitRate,
    required this.averageResponseSize,
    required this.statusCodeDistribution,
    required this.errorTypeDistribution,
    required this.endpointPerformance,
  });

  Map<String, dynamic> toJson() => {
    'totalRequests': totalRequests,
    'successfulRequests': successfulRequests,
    'failedRequests': failedRequests,
    'cachedRequests': cachedRequests,
    'averageResponseTime': averageResponseTime.inMilliseconds,
    'p50ResponseTime': p50ResponseTime.inMilliseconds,
    'p95ResponseTime': p95ResponseTime.inMilliseconds,
    'p99ResponseTime': p99ResponseTime.inMilliseconds,
    'successRate': successRate,
    'cacheHitRate': cacheHitRate,
    'averageResponseSize': averageResponseSize,
    'statusCodeDistribution': statusCodeDistribution,
    'errorTypeDistribution': errorTypeDistribution,
    'endpointPerformance': endpointPerformance.map((k, v) => MapEntry(k, v.inMilliseconds)),
  };
}

/// HTTP performance monitoring system
class HttpPerformanceMonitor {
  static const int _maxMetricsCount = 1000;
  static const Duration _metricsRetentionTime = Duration(hours: 24);

  static final Queue<RequestMetrics> _metrics = Queue<RequestMetrics>();
  static final Map<String, RequestMetrics> _activeRequests = {};
  static bool _isEnabled = true;

  /// Enable/disable performance monitoring
  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      _metrics.clear();
      _activeRequests.clear();
    }
    Logger.info('HTTP performance monitoring ${enabled ? "enabled" : "disabled"}');
  }

  /// Start tracking a request
  static void startRequest(RequestOptions options) {
    if (!_isEnabled) return;

    final id = _generateRequestId(options);
    final metrics = RequestMetrics(
      id: id,
      method: options.method.toUpperCase(),
      url: '${options.baseUrl}${options.path}',
      startTime: DateTime.now(),
      metadata: Map<String, dynamic>.from(options.extra),
    );

    _activeRequests[id] = metrics;
    Logger.debug('Started tracking request: $id');
  }

  /// Complete tracking a request with response
  static void completeRequest(RequestOptions options, Response response) {
    if (!_isEnabled) return;

    final id = _generateRequestId(options);
    final activeMetrics = _activeRequests.remove(id);
    
    if (activeMetrics != null) {
      final endTime = DateTime.now();
      final totalDuration = endTime.difference(activeMetrics.startTime);
      
      final completedMetrics = activeMetrics.copyWith(
        endTime: endTime,
        statusCode: response.statusCode,
        totalDuration: totalDuration,
        responseSize: _calculateResponseSize(response),
        fromCache: response.statusMessage?.contains('Cache') == true,
      );

      _addMetrics(completedMetrics);
      Logger.debug('Completed tracking request: $id - ${totalDuration.inMilliseconds}ms');
    }
  }

  /// Complete tracking a request with error
  static void completeRequestWithError(RequestOptions options, DioException error) {
    if (!_isEnabled) return;

    final id = _generateRequestId(options);
    final activeMetrics = _activeRequests.remove(id);
    
    if (activeMetrics != null) {
      final endTime = DateTime.now();
      final totalDuration = endTime.difference(activeMetrics.startTime);
      
      final completedMetrics = activeMetrics.copyWith(
        endTime: endTime,
        statusCode: error.response?.statusCode,
        totalDuration: totalDuration,
        responseSize: _calculateResponseSize(error.response),
        errorType: error.type.toString(),
        retryCount: options.extra['retry_attempt'] as int? ?? 0,
      );

      _addMetrics(completedMetrics);
      Logger.debug('Completed tracking request with error: $id - ${error.type}');
    }
  }

  /// Add metrics to collection
  static void _addMetrics(RequestMetrics metrics) {
    _metrics.add(metrics);
    
    // Maintain size limit
    while (_metrics.length > _maxMetricsCount) {
      _metrics.removeFirst();
    }
    
    // Remove old metrics
    _cleanupOldMetrics();
  }

  /// Clean up old metrics beyond retention time
  static void _cleanupOldMetrics() {
    final cutoff = DateTime.now().subtract(_metricsRetentionTime);
    _metrics.removeWhere((metrics) => metrics.startTime.isBefore(cutoff));
  }

  /// Generate unique request ID
  static String _generateRequestId(RequestOptions options) {
    return '${options.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Calculate response size in bytes
  static int _calculateResponseSize(Response? response) {
    if (response?.data == null) return 0;
    
    try {
      if (response!.data is String) {
        return (response.data as String).length;
      } else if (response.data is List<int>) {
        return (response.data as List<int>).length;
      } else {
        return response.data.toString().length;
      }
    } catch (e) {
      return 0;
    }
  }

  /// Get current performance statistics
  static PerformanceStats getStats() {
    if (_metrics.isEmpty) {
      return PerformanceStats(
        totalRequests: 0,
        successfulRequests: 0,
        failedRequests: 0,
        cachedRequests: 0,
        averageResponseTime: Duration.zero,
        p50ResponseTime: Duration.zero,
        p95ResponseTime: Duration.zero,
        p99ResponseTime: Duration.zero,
        successRate: 0.0,
        cacheHitRate: 0.0,
        averageResponseSize: 0,
        statusCodeDistribution: {},
        errorTypeDistribution: {},
        endpointPerformance: {},
      );
    }

    final completedMetrics = _metrics.where((m) => m.isCompleted).toList();
    final totalRequests = completedMetrics.length;
    final successfulRequests = completedMetrics.where((m) => m.isSuccess).length;
    final failedRequests = completedMetrics.where((m) => m.isError).length;
    final cachedRequests = completedMetrics.where((m) => m.fromCache).length;

    // Response times
    final responseTimes = completedMetrics
        .where((m) => m.totalDuration != null)
        .map((m) => m.totalDuration!)
        .toList();
    responseTimes.sort((a, b) => a.compareTo(b));

    final averageResponseTime = responseTimes.isNotEmpty
        ? Duration(milliseconds: 
            responseTimes.map((d) => d.inMilliseconds).reduce((a, b) => a + b) ~/ 
            responseTimes.length)
        : Duration.zero;

    final p50ResponseTime = responseTimes.isNotEmpty
        ? responseTimes[(responseTimes.length * 0.5).floor()]
        : Duration.zero;
    
    final p95ResponseTime = responseTimes.isNotEmpty
        ? responseTimes[(responseTimes.length * 0.95).floor().clamp(0, responseTimes.length - 1)]
        : Duration.zero;
    
    final p99ResponseTime = responseTimes.isNotEmpty
        ? responseTimes[(responseTimes.length * 0.99).floor().clamp(0, responseTimes.length - 1)]
        : Duration.zero;

    // Status code distribution
    final statusCodeDistribution = <String, int>{};
    for (final metrics in completedMetrics) {
      if (metrics.statusCode != null) {
        final code = metrics.statusCode.toString();
        statusCodeDistribution[code] = (statusCodeDistribution[code] ?? 0) + 1;
      }
    }

    // Error type distribution
    final errorTypeDistribution = <String, int>{};
    for (final metrics in completedMetrics.where((m) => m.errorType != null)) {
      final errorType = metrics.errorType!;
      errorTypeDistribution[errorType] = (errorTypeDistribution[errorType] ?? 0) + 1;
    }

    // Endpoint performance
    final endpointPerformance = <String, List<Duration>>{};
    for (final metrics in completedMetrics.where((m) => m.totalDuration != null)) {
      final endpoint = '${metrics.method} ${Uri.parse(metrics.url).path}';
      endpointPerformance.putIfAbsent(endpoint, () => []).add(metrics.totalDuration!);
    }

    final endpointAverages = <String, Duration>{};
    for (final entry in endpointPerformance.entries) {
      final avg = entry.value.map((d) => d.inMilliseconds).reduce((a, b) => a + b) ~/ 
                  entry.value.length;
      endpointAverages[entry.key] = Duration(milliseconds: avg);
    }

    // Response sizes
    final responseSizes = completedMetrics
        .where((m) => m.responseSize != null && m.responseSize! > 0)
        .map((m) => m.responseSize!)
        .toList();
    final averageResponseSize = responseSizes.isNotEmpty
        ? responseSizes.reduce((a, b) => a + b) ~/ responseSizes.length
        : 0;

    return PerformanceStats(
      totalRequests: totalRequests,
      successfulRequests: successfulRequests,
      failedRequests: failedRequests,
      cachedRequests: cachedRequests,
      averageResponseTime: averageResponseTime,
      p50ResponseTime: p50ResponseTime,
      p95ResponseTime: p95ResponseTime,
      p99ResponseTime: p99ResponseTime,
      successRate: totalRequests > 0 ? (successfulRequests / totalRequests) : 0.0,
      cacheHitRate: totalRequests > 0 ? (cachedRequests / totalRequests) : 0.0,
      averageResponseSize: averageResponseSize,
      statusCodeDistribution: statusCodeDistribution,
      errorTypeDistribution: errorTypeDistribution,
      endpointPerformance: endpointAverages,
    );
  }

  /// Get detailed metrics for analysis
  static List<RequestMetrics> getDetailedMetrics({
    Duration? since,
    String? method,
    String? endpoint,
    bool? onlyErrors,
  }) {
    var filtered = _metrics.where((m) => m.isCompleted);

    if (since != null) {
      final cutoff = DateTime.now().subtract(since);
      filtered = filtered.where((m) => m.startTime.isAfter(cutoff));
    }

    if (method != null) {
      filtered = filtered.where((m) => m.method.toUpperCase() == method.toUpperCase());
    }

    if (endpoint != null) {
      filtered = filtered.where((m) => m.url.contains(endpoint));
    }

    if (onlyErrors == true) {
      filtered = filtered.where((m) => m.isError || m.errorType != null);
    }

    return filtered.toList();
  }

  /// Reset all metrics
  static void reset() {
    _metrics.clear();
    _activeRequests.clear();
    Logger.info('HTTP performance metrics reset');
  }

  /// Get current active request count
  static int get activeRequestCount => _activeRequests.length;

  /// Get total metrics count
  static int get totalMetricsCount => _metrics.length;

  /// Check if monitoring is enabled
  static bool get isEnabled => _isEnabled;
}

/// Performance monitoring interceptor
class HttpPerformanceInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    HttpPerformanceMonitor.startRequest(options);
    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    HttpPerformanceMonitor.completeRequest(response.requestOptions, response);
    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    HttpPerformanceMonitor.completeRequestWithError(err.requestOptions, err);
    handler.next(err);
  }
}
