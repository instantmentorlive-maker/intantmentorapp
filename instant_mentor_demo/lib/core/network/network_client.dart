import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';
import 'enhanced_network_client.dart';

/// HTTP client factory and configuration (legacy wrapper)
///
/// This class now delegates to EnhancedNetworkClient for better performance
/// and additional features like caching, retry logic, and offline support.
class NetworkClient {
  static late Dio _dio;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static bool _useEnhancedClient = true;

  /// Initialize the HTTP client
  static Future<void> initialize({bool useEnhanced = true}) async {
    _useEnhancedClient = useEnhanced;

    if (_useEnhancedClient) {
      // Initialize enhanced client with performance optimizations
      await EnhancedNetworkClient.initialize();
      _dio = EnhancedNetworkClient.instance;
      Logger.info('Network client initialized with enhanced features');
    } else {
      // Fall back to basic client
      _dio = Dio();
      _setupInterceptors();
      _setupOptions();
      Logger.info('Network client initialized with basic features');
    }
  }

  /// Get the configured Dio instance
  static Dio get instance {
    if (_useEnhancedClient) {
      return EnhancedNetworkClient.instance;
    }
    return _dio;
  }

  /// Setup Dio options
  static void _setupOptions() {
    final config = AppConfig.instance;

    _dio.options = BaseOptions(
      baseUrl: config.fullApiUrl,
      connectTimeout: Duration(milliseconds: config.connectTimeout),
      receiveTimeout: Duration(milliseconds: config.receiveTimeout),
      sendTimeout: Duration(milliseconds: config.sendTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'InstantMentor-Mobile/1.0.0',
      },
      validateStatus: (status) => status != null && status < 500,
    );
  }

  /// Setup interceptors for logging, authentication, and error handling
  static void _setupInterceptors() {
    final config = AppConfig.instance;

    // Request interceptor for authentication
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add authentication token if available
          final token = await _secureStorage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          Logger.debug('HTTP Request: ${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          Logger.debug(
              'HTTP Response: ${response.statusCode} ${response.requestOptions.path}');
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
                Logger.error('Retry request failed: $e');
              }
            }
          }

          handler.next(error);
        },
      ),
    );

    // Pretty logging for development
    if (config.enableNetworkLogs && config.isDevelopment) {
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
    if (_useEnhancedClient) {
      return EnhancedNetworkClient.hasConnection();
    }
    // On web, avoid dart:io DNS lookup
    if (kIsWeb) {
      return true;
    }
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// Get performance statistics (only available with enhanced client)
  static Map<String, dynamic>? getPerformanceStats() {
    if (_useEnhancedClient) {
      return EnhancedNetworkClient.getPerformanceStats();
    }
    return null;
  }

  /// Clear all caches (only available with enhanced client)
  static Future<void> clearCaches() async {
    if (_useEnhancedClient) {
      await EnhancedNetworkClient.clearCaches();
    }
  }

  /// Create a new Dio instance for specific use cases
  static Dio createClient({
    String? baseUrl,
    Map<String, dynamic>? headers,
    int? connectTimeout,
    int? receiveTimeout,
  }) {
    final dio = Dio();
    final config = AppConfig.instance;

    dio.options = BaseOptions(
      baseUrl: baseUrl ?? config.fullApiUrl,
      connectTimeout:
          Duration(milliseconds: connectTimeout ?? config.connectTimeout),
      receiveTimeout:
          Duration(milliseconds: receiveTimeout ?? config.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?headers,
      },
    );

    return dio;
  }
}
