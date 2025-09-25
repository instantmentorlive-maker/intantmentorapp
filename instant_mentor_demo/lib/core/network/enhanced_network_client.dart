import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';
import 'connection_pool.dart';
import 'http_cache.dart';
import 'http_cache_interceptor.dart';
import 'http_performance.dart';
import 'http_retry.dart';
import 'offline_manager.dart';

/// Enhanced HTTP client with performance optimizations
class EnhancedNetworkClient {
  static late Dio _dio;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static bool _isInitialized = false;

  /// Performance optimization configuration
  static final PerformanceConfig _config = PerformanceConfig();

  /// Initialize the enhanced network client
  static Future<void> initialize({
    PerformanceConfig? config,
  }) async {
    if (_isInitialized) {
      Logger.warning('Enhanced network client already initialized');
      return;
    }

    if (config != null) {
      _config.updateFrom(config);
    }

    try {
      // Initialize components
      await HttpCache.initialize();
      await OfflineManager.initialize();
      // dart:io HttpClient is not supported on Flutter Web; skip connection pooling there
      if (!kIsWeb) {
        ConnectionPoolManager.initialize(
          maxConnections: _config.maxConnections,
          maxConnectionsPerHost: _config.maxConnectionsPerHost,
          connectionTimeout: _config.connectionTimeout,
          idleTimeout: _config.idleTimeout,
        );
      }

      // Create Dio instance
      _dio = Dio();
      _setupOptions();
      _setupInterceptors();

      _isInitialized = true;
      Logger.info(
          'Enhanced network client initialized with optimizations: ${_config.getEnabledFeatures()}');
    } catch (e) {
      Logger.error('Failed to initialize enhanced network client: $e');
      rethrow;
    }
  }

  /// Get the configured Dio instance
  static Dio get instance {
    if (!_isInitialized) {
      throw StateError(
          'Enhanced network client not initialized. Call initialize() first.');
    }
    return _dio;
  }

  /// Setup Dio options with performance optimizations
  static void _setupOptions() {
    final appConfig = AppConfig.instance;

    _dio.options = BaseOptions(
      baseUrl: appConfig.fullApiUrl,
      connectTimeout: _config.connectionTimeout,
      receiveTimeout: _config.receiveTimeout,
      sendTimeout: _config.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'InstantMentor-Enhanced/1.0.0',
        'Accept-Encoding': 'gzip, deflate',
        if (_config.enableKeepAlive) 'Connection': 'keep-alive',
      },
      validateStatus: (status) => status != null && status < 500,
      followRedirects: true,
      maxRedirects: 3,
    );

    // Configure connection pooling
    if (_config.enableConnectionPooling && !kIsWeb) {
      final adapter = ConnectionPoolManager.createDioAdapter();
      if (adapter != null) {
        _dio.httpClientAdapter = adapter;
      }
    }
  }

  /// Setup all performance interceptors
  static void _setupInterceptors() {
    final appConfig = AppConfig.instance;

    // Performance monitoring (first to capture all metrics)
    if (_config.enablePerformanceMonitoring) {
      _dio.interceptors.add(HttpPerformanceInterceptor());
    }

    // HTTP caching
    if (_config.enableCaching) {
      _dio.interceptors.add(HttpCacheInterceptor(
        defaultCacheDuration: _config.defaultCacheDuration,
        cacheableMethods: _config.cacheableMethods,
      ));
    }

    // Request retry with exponential backoff
    if (_config.enableRetry) {
      _dio.interceptors.add(HttpRetryInterceptor(
        config: _config.retryConfig,
      ));
    }

    // Offline request queuing
    if (_config.enableOfflineSupport) {
      _dio.interceptors.add(OfflineInterceptor(
        defaultPriority: _config.defaultOfflinePriority,
        queueableMethods: _config.offlineQueueableMethods,
      ));
    }

    // Authentication and token management
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add authentication token if available
          final token = await _secureStorage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Add request timestamp for performance tracking
          options.extra['request_start_time'] =
              DateTime.now().millisecondsSinceEpoch;

          Logger.debug('HTTP Request: ${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          // Log response timing
          final startTime =
              response.requestOptions.extra['request_start_time'] as int?;
          if (startTime != null) {
            final duration = DateTime.now().millisecondsSinceEpoch - startTime;
            Logger.debug(
                'HTTP Response: ${response.statusCode} ${response.requestOptions.path} (${duration}ms)');
          }

          handler.next(response);
        },
        onError: (error, handler) async {
          Logger.error('HTTP Error: ${error.message}');

          // Handle token refresh on 401
          if (error.response?.statusCode == 401) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Retry the original request
              final options = error.requestOptions;
              final token = await _secureStorage.read(key: 'auth_token');
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }

              try {
                final response = await _dio.fetch(options);
                handler.resolve(response);
                return;
              } catch (e) {
                Logger.error('Token refresh retry failed: $e');
              }
            }
          }

          handler.next(error);
        },
      ),
    );

    // Pretty logging for development (last to see final request/response)
    if (appConfig.enableNetworkLogs && appConfig.isDevelopment) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
        ),
      );
    }
  }

  /// Attempt to refresh the authentication token
  static Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken == null) {
        Logger.warning('No refresh token available');
        return false;
      }

      Logger.info('Attempting token refresh');

      final response = await Dio().post(
        '${AppConfig.instance.authEndpoint}/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _secureStorage.write(
            key: 'auth_token', value: data['access_token']);
        await _secureStorage.write(
            key: 'refresh_token', value: data['refresh_token']);

        Logger.info('Token refresh successful');
        return true;
      }
    } catch (e) {
      Logger.error('Token refresh failed: $e');
    }

    // Clear invalid tokens
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'refresh_token');
    return false;
  }

  /// Clear all authentication data
  static Future<void> clearAuthData() async {
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'refresh_token');
    Logger.info('Authentication data cleared');
  }

  /// Check network connectivity
  static Future<bool> hasConnection() async {
    // On web, rely on the browser network stack; attempting DNS lookup via dart:io is unsupported
    if (kIsWeb) {
      // Best-effort: consider the app online; actual request errors will surface via Dio
      return true;
    }
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// Get comprehensive performance statistics
  static Map<String, dynamic> getPerformanceStats() {
    return {
      'http': HttpPerformanceMonitor.getStats().toJson(),
      'cache': HttpCache.getStats(),
      'connectionPool': ConnectionPoolManager.getStats().toJson(),
      'offline': OfflineManager.getStats(),
      'config': _config.toJson(),
    };
  }

  /// Clear all caches and reset performance metrics
  static Future<void> clearCaches() async {
    await HttpCache.clear();
    HttpPerformanceMonitor.reset();
    Logger.info('All caches and metrics cleared');
  }

  /// Update configuration at runtime
  static Future<void> updateConfiguration(PerformanceConfig config) async {
    _config.updateFrom(config);
    Logger.info('Network client configuration updated');

    // Note: This doesn't reinitialize interceptors.
    // For major changes, consider calling dispose() and initialize()
  }

  /// Dispose and cleanup resources
  static Future<void> dispose() async {
    if (_isInitialized) {
      await HttpCache.clear();
      await OfflineManager.clearQueue();
      if (!kIsWeb) {
        ConnectionPoolManager.dispose();
      }
      HttpPerformanceMonitor.reset();
      _isInitialized = false;
      Logger.info('Enhanced network client disposed');
    }
  }

  /// Create a specialized client for specific use cases
  static Dio createSpecializedClient({
    String? baseUrl,
    Map<String, dynamic>? headers,
    Duration? timeout,
    bool enableCache = true,
    bool enableRetry = true,
    RetryConfig? retryConfig,
  }) {
    final dio = Dio();
    final appConfig = AppConfig.instance;

    dio.options = BaseOptions(
      baseUrl: baseUrl ?? appConfig.fullApiUrl,
      connectTimeout: timeout ?? _config.connectionTimeout,
      receiveTimeout: timeout ?? _config.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?headers,
      },
    );

    // Add selective optimizations
    if (enableCache) {
      dio.interceptors.add(HttpCacheInterceptor());
    }

    if (enableRetry) {
      dio.interceptors.add(HttpRetryInterceptor(
        config: retryConfig ?? _config.retryConfig,
      ));
    }

    return dio;
  }
}

/// Performance optimization configuration
class PerformanceConfig {
  // Connection settings
  int maxConnections = 6;
  int maxConnectionsPerHost = 4;
  Duration connectionTimeout = const Duration(seconds: 10);
  Duration receiveTimeout = const Duration(seconds: 30);
  Duration sendTimeout = const Duration(seconds: 30);
  Duration idleTimeout = const Duration(seconds: 60);
  bool enableKeepAlive = true;

  // Feature flags
  bool enableCaching = true;
  bool enableRetry = true;
  bool enableOfflineSupport = true;
  bool enableConnectionPooling = true;
  bool enablePerformanceMonitoring = true;

  // Cache configuration
  Duration defaultCacheDuration = const Duration(minutes: 5);
  List<String> cacheableMethods = ['GET', 'HEAD'];

  // Retry configuration
  RetryConfig retryConfig = const RetryConfig();

  // Offline configuration
  int defaultOfflinePriority = 0;
  List<String> offlineQueueableMethods = ['POST', 'PUT', 'PATCH', 'DELETE'];

  /// Update configuration from another config
  void updateFrom(PerformanceConfig other) {
    maxConnections = other.maxConnections;
    maxConnectionsPerHost = other.maxConnectionsPerHost;
    connectionTimeout = other.connectionTimeout;
    receiveTimeout = other.receiveTimeout;
    sendTimeout = other.sendTimeout;
    idleTimeout = other.idleTimeout;
    enableKeepAlive = other.enableKeepAlive;
    enableCaching = other.enableCaching;
    enableRetry = other.enableRetry;
    enableOfflineSupport = other.enableOfflineSupport;
    enableConnectionPooling = other.enableConnectionPooling;
    enablePerformanceMonitoring = other.enablePerformanceMonitoring;
    defaultCacheDuration = other.defaultCacheDuration;
    cacheableMethods = List.from(other.cacheableMethods);
    retryConfig = other.retryConfig;
    defaultOfflinePriority = other.defaultOfflinePriority;
    offlineQueueableMethods = List.from(other.offlineQueueableMethods);
  }

  /// Get list of enabled features
  List<String> getEnabledFeatures() {
    final features = <String>[];
    if (enableCaching) features.add('Caching');
    if (enableRetry) features.add('Retry');
    if (enableOfflineSupport) features.add('Offline');
    if (enableConnectionPooling) features.add('Connection Pooling');
    if (enablePerformanceMonitoring) features.add('Performance Monitoring');
    return features;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'maxConnections': maxConnections,
        'maxConnectionsPerHost': maxConnectionsPerHost,
        'connectionTimeout': connectionTimeout.inMilliseconds,
        'receiveTimeout': receiveTimeout.inMilliseconds,
        'sendTimeout': sendTimeout.inMilliseconds,
        'idleTimeout': idleTimeout.inMilliseconds,
        'enableKeepAlive': enableKeepAlive,
        'enableCaching': enableCaching,
        'enableRetry': enableRetry,
        'enableOfflineSupport': enableOfflineSupport,
        'enableConnectionPooling': enableConnectionPooling,
        'enablePerformanceMonitoring': enablePerformanceMonitoring,
        'defaultCacheDuration': defaultCacheDuration.inMinutes,
        'cacheableMethods': cacheableMethods,
        'retryConfig': retryConfig.toString(),
        'defaultOfflinePriority': defaultOfflinePriority,
        'offlineQueueableMethods': offlineQueueableMethods,
        'enabledFeatures': getEnabledFeatures(),
      };
}
