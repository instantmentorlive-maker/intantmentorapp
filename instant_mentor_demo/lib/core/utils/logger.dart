import 'dart:developer' as developer;
import '../config/app_config.dart';

/// Centralized logging utility
class Logger {
  static const String _name = 'InstantMentor';
  
  /// Log debug information (only in debug mode)
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (AppConfig.instance.debugMode) {
      developer.log(
        message,
        name: _name,
        level: 500, // Debug level
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Log informational messages
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _name,
      level: 800, // Info level
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  /// Log warning messages
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _name,
      level: 900, // Warning level
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  /// Log error messages
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _name,
      level: 1000, // Error level
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  /// Log fatal errors
  static void fatal(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _name,
      level: 1200, // Fatal level
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  /// Log network requests (only in debug mode)
  static void network(String method, String url, {int? statusCode, String? error}) {
    if (AppConfig.instance.enableNetworkLogs) {
      final status = statusCode != null ? ' ($statusCode)' : '';
      final errorMsg = error != null ? ' - Error: $error' : '';
      debug('Network: $method $url$status$errorMsg');
    }
  }
  
  /// Log authentication events
  static void auth(String message, [Object? error]) {
    info('Auth: $message', error);
  }
  
  /// Log user actions for analytics
  static void userAction(String action, {Map<String, dynamic>? parameters}) {
    if (parameters != null) {
      info('User Action: $action - Parameters: $parameters');
    } else {
      info('User Action: $action');
    }
  }
}
