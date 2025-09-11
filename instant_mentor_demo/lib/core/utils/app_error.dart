/// Enumeration of different error types in the application
enum AppErrorType {
  network,      // Network connectivity or HTTP errors
  auth,         // Authentication and authorization errors
  validation,   // Input validation errors
  server,       // Server-side errors (5xx)
  notFound,     // Resource not found (404)
  conflict,     // Data conflict errors (409)
  rateLimited,  // Too many requests (429)
  unknown,      // Unknown or unexpected errors
}

/// Standardized error class for the application
class AppError {
  final AppErrorType type;
  final String message;
  final String? code;
  final Map<String, dynamic>? details;
  final Exception? originalException;
  
  const AppError({
    required this.type,
    required this.message,
    this.code,
    this.details,
    this.originalException,
  });
  
  /// Create a network-related error
  factory AppError.network(String message, {String? code, Exception? originalException}) {
    return AppError(
      type: AppErrorType.network,
      message: message,
      code: code,
      originalException: originalException,
    );
  }
  
  /// Create an authentication error
  factory AppError.auth(String message, {String? code, Exception? originalException}) {
    return AppError(
      type: AppErrorType.auth,
      message: message,
      code: code,
      originalException: originalException,
    );
  }
  
  /// Create a validation error
  factory AppError.validation(String message, {String? code, Map<String, dynamic>? details}) {
    return AppError(
      type: AppErrorType.validation,
      message: message,
      code: code,
      details: details,
    );
  }
  
  /// Create a server error
  factory AppError.server(String message, {String? code, Exception? originalException}) {
    return AppError(
      type: AppErrorType.server,
      message: message,
      code: code,
      originalException: originalException,
    );
  }
  
  /// Create a not found error
  factory AppError.notFound(String message, {String? code}) {
    return AppError(
      type: AppErrorType.notFound,
      message: message,
      code: code,
    );
  }
  
  /// Create a conflict error
  factory AppError.conflict(String message, {String? code, Map<String, dynamic>? details}) {
    return AppError(
      type: AppErrorType.conflict,
      message: message,
      code: code,
      details: details,
    );
  }
  
  /// Create a rate limited error
  factory AppError.rateLimited(String message, {String? code}) {
    return AppError(
      type: AppErrorType.rateLimited,
      message: message,
      code: code,
    );
  }
  
  /// Create an unknown error
  factory AppError.unknown(String message, {Exception? originalException}) {
    return AppError(
      type: AppErrorType.unknown,
      message: message,
      originalException: originalException,
    );
  }
  
  /// Get a user-friendly error message
  String get userMessage {
    switch (type) {
      case AppErrorType.network:
        return 'Please check your internet connection and try again.';
      case AppErrorType.auth:
        return 'Authentication failed. Please log in again.';
      case AppErrorType.validation:
        return message; // Validation messages are usually user-friendly
      case AppErrorType.server:
        return 'Something went wrong on our end. Please try again later.';
      case AppErrorType.notFound:
        return 'The requested information could not be found.';
      case AppErrorType.conflict:
        return message; // Conflict messages usually need to be specific
      case AppErrorType.rateLimited:
        return 'Too many requests. Please wait a moment and try again.';
      case AppErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }
  
  /// Check if this error type can be retried
  bool get isRetryable {
    switch (type) {
      case AppErrorType.network:
      case AppErrorType.server:
      case AppErrorType.rateLimited:
        return true;
      case AppErrorType.auth:
      case AppErrorType.validation:
      case AppErrorType.notFound:
      case AppErrorType.conflict:
      case AppErrorType.unknown:
        return false;
    }
  }
  
  /// Get recommended retry delay in seconds
  int get retryDelaySeconds {
    switch (type) {
      case AppErrorType.rateLimited:
        return 60; // 1 minute for rate limiting
      case AppErrorType.network:
      case AppErrorType.server:
        return 5; // 5 seconds for network/server errors
      default:
        return 0;
    }
  }
  
  @override
  String toString() {
    return 'AppError(type: $type, message: $message, code: $code)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppError &&
        other.type == type &&
        other.message == message &&
        other.code == code;
  }
  
  @override
  int get hashCode {
    return type.hashCode ^ message.hashCode ^ code.hashCode;
  }
}
