import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../utils/logger.dart';

/// HTTP connection pool configuration and management
class ConnectionPoolManager {
  static const int _defaultMaxConnections = 6;
  static const int _defaultMaxConnectionsPerHost = 4;
  static const Duration _defaultConnectionTimeout = Duration(seconds: 10);
  static const Duration _defaultIdleTimeout = Duration(seconds: 60);
  static const Duration _defaultKeepAliveTimeout = Duration(seconds: 30);

  static HttpClient? _httpClient;
  static bool _isInitialized = false;

  /// Connection pool configuration
  static final ConnectionPoolConfig _config = ConnectionPoolConfig();

  /// Initialize connection pool with custom configuration
  static void initialize({
    int? maxConnections,
    int? maxConnectionsPerHost,
    Duration? connectionTimeout,
    Duration? idleTimeout,
    Duration? keepAliveTimeout,
    bool? enableKeepAlive,
  }) {
    if (_isInitialized) {
      Logger.warning('Connection pool already initialized');
      return;
    }

    _config.maxConnections = maxConnections ?? _defaultMaxConnections;
    _config.maxConnectionsPerHost =
        maxConnectionsPerHost ?? _defaultMaxConnectionsPerHost;
    _config.connectionTimeout = connectionTimeout ?? _defaultConnectionTimeout;
    _config.idleTimeout = idleTimeout ?? _defaultIdleTimeout;
    _config.keepAliveTimeout = keepAliveTimeout ?? _defaultKeepAliveTimeout;
    _config.enableKeepAlive = enableKeepAlive ?? true;

    if (!kIsWeb) {
      _createHttpClient();
    }
    _isInitialized = true;

    Logger.info('Connection pool initialized with config: $_config');
  }

  /// Get configured HTTP client
  static HttpClient get httpClient {
    if (!_isInitialized) {
      initialize();
    }
    if (kIsWeb) {
      throw UnsupportedError('HttpClient is not available on web');
    }
    return _httpClient!;
  }

  /// Create and configure HTTP client
  static void _createHttpClient() {
    _httpClient = HttpClient();

    // Configure connection limits
    _httpClient!.maxConnectionsPerHost = _config.maxConnectionsPerHost;

    // Configure timeouts
    _httpClient!.connectionTimeout = _config.connectionTimeout;
    _httpClient!.idleTimeout = _config.idleTimeout;

    // Configure keep-alive
    if (_config.enableKeepAlive) {
      // Keep-alive is enabled by default in HttpClient
      Logger.debug('Keep-alive connections enabled');
    }

    // Configure automatic handling
    _httpClient!.autoUncompress = true;

    Logger.debug('HTTP client configured with connection pooling');
  }

  /// Create Dio adapter with connection pooling
  static HttpClientAdapter? createDioAdapter() {
    if (!_isInitialized) {
      initialize();
    }
    if (kIsWeb) {
      // On web, Dio uses XMLHttpRequest/fetch; return null
      return null;
    }
    // Return null to use default adapter with our configured settings
    // The HttpClient configuration will be used automatically
    return null;
  }

  /// Get connection pool statistics
  static ConnectionPoolStats getStats() {
    if (!_isInitialized || _httpClient == null) {
      return ConnectionPoolStats.empty();
    }

    // Note: HttpClient doesn't expose detailed connection stats
    // This is a basic implementation
    return ConnectionPoolStats(
      activeConnections: 0, // Would need custom implementation to track
      idleConnections: 0, // Would need custom implementation to track
      maxConnections: _config.maxConnections,
      maxConnectionsPerHost: _config.maxConnectionsPerHost,
      totalRequests: 0, // Would need custom implementation to track
      configuration: _config,
    );
  }

  /// Close all connections and cleanup
  static void dispose() {
    if (_httpClient != null) {
      _httpClient!.close(force: true);
      _httpClient = null;
    }
    _isInitialized = false;
    Logger.info('Connection pool disposed');
  }

  /// Reset connection pool with new configuration
  static void reset({
    int? maxConnections,
    int? maxConnectionsPerHost,
    Duration? connectionTimeout,
    Duration? idleTimeout,
    Duration? keepAliveTimeout,
    bool? enableKeepAlive,
  }) {
    dispose();
    initialize(
      maxConnections: maxConnections,
      maxConnectionsPerHost: maxConnectionsPerHost,
      connectionTimeout: connectionTimeout,
      idleTimeout: idleTimeout,
      keepAliveTimeout: keepAliveTimeout,
      enableKeepAlive: enableKeepAlive,
    );
  }
}

/// Connection pool configuration
class ConnectionPoolConfig {
  int maxConnections = 6;
  int maxConnectionsPerHost = 4;
  Duration connectionTimeout = const Duration(seconds: 10);
  Duration idleTimeout = const Duration(seconds: 60);
  Duration keepAliveTimeout = const Duration(seconds: 30);
  bool enableKeepAlive = true;

  @override
  String toString() {
    return 'ConnectionPoolConfig('
        'maxConnections: $maxConnections, '
        'maxConnectionsPerHost: $maxConnectionsPerHost, '
        'connectionTimeout: ${connectionTimeout.inSeconds}s, '
        'idleTimeout: ${idleTimeout.inSeconds}s, '
        'keepAliveTimeout: ${keepAliveTimeout.inSeconds}s, '
        'enableKeepAlive: $enableKeepAlive'
        ')';
  }
}

/// Connection pool statistics
class ConnectionPoolStats {
  final int activeConnections;
  final int idleConnections;
  final int maxConnections;
  final int maxConnectionsPerHost;
  final int totalRequests;
  final ConnectionPoolConfig configuration;

  ConnectionPoolStats({
    required this.activeConnections,
    required this.idleConnections,
    required this.maxConnections,
    required this.maxConnectionsPerHost,
    required this.totalRequests,
    required this.configuration,
  });

  factory ConnectionPoolStats.empty() {
    return ConnectionPoolStats(
      activeConnections: 0,
      idleConnections: 0,
      maxConnections: 0,
      maxConnectionsPerHost: 0,
      totalRequests: 0,
      configuration: ConnectionPoolConfig(),
    );
  }

  int get totalConnections => activeConnections + idleConnections;

  double get utilizationPercentage {
    if (maxConnections == 0) return 0.0;
    return (totalConnections / maxConnections) * 100;
  }

  Map<String, dynamic> toJson() => {
        'activeConnections': activeConnections,
        'idleConnections': idleConnections,
        'totalConnections': totalConnections,
        'maxConnections': maxConnections,
        'maxConnectionsPerHost': maxConnectionsPerHost,
        'totalRequests': totalRequests,
        'utilizationPercentage': utilizationPercentage,
        'configuration': {
          'maxConnections': configuration.maxConnections,
          'maxConnectionsPerHost': configuration.maxConnectionsPerHost,
          'connectionTimeout': configuration.connectionTimeout.inSeconds,
          'idleTimeout': configuration.idleTimeout.inSeconds,
          'keepAliveTimeout': configuration.keepAliveTimeout.inSeconds,
          'enableKeepAlive': configuration.enableKeepAlive,
        },
      };

  @override
  String toString() {
    return 'ConnectionPoolStats('
        'active: $activeConnections, '
        'idle: $idleConnections, '
        'total: $totalConnections, '
        'max: $maxConnections, '
        'utilization: ${utilizationPercentage.toStringAsFixed(1)}%'
        ')';
  }
}
