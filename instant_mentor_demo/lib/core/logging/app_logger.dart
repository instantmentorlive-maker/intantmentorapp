import 'package:flutter/foundation.dart';

/// Application logger utility class
class AppLogger {
  static const String _tag = 'InstantMentor';

  /// Log debug messages
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint(' $_tag: $message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
    }
  }

  /// Log info messages
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ $_tag: $message');
    }
  }

  /// Log warning messages
  static void warning(String message, [dynamic error]) {
    if (kDebugMode) {
      debugPrint(' $_tag: $message');
      if (error != null) {
        debugPrint('Warning: $error');
      }
    }
  }

  /// Log error messages
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint(' $_tag: $message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
    }
  }

  /// Log network requests
  static void network(String method, String url,
      {int? statusCode, dynamic data}) {
    if (kDebugMode) {
      debugPrint(' $_tag: $method $url');
      if (statusCode != null) {
        debugPrint('Status: $statusCode');
      }
      if (data != null) {
        debugPrint('Data: $data');
      }
    }
  }

  /// Log user interactions
  static void userAction(String action, {Map<String, dynamic>? params}) {
    if (kDebugMode) {
      debugPrint(' $_tag: User Action - $action');
      if (params != null && params.isNotEmpty) {
        debugPrint('Params: $params');
      }
    }
  }

  /// Log performance metrics
  static void performance(String operation, Duration duration,
      {Map<String, dynamic>? metrics}) {
    if (kDebugMode) {
      debugPrint(
          ' $_tag: Performance - $operation took ${duration.inMilliseconds}ms');
      if (metrics != null && metrics.isNotEmpty) {
        debugPrint('Metrics: $metrics');
      }
    }
  }
}
