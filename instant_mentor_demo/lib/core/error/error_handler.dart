import 'package:flutter/foundation.dart';
import 'app_error.dart';

/// Global error handler for the application
class ErrorHandler {
  /// Handles any error and converts it to an appropriate AppError
  static AppError handleError(Object error, StackTrace? stackTrace) {
    debugPrint('ErrorHandler: Handling error: $error');
    if (kDebugMode && stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }

    // If it's already an AppError, return it
    if (error is AppError) {
      return error;
    }

    // Convert common Flutter/Dart exceptions to AppError
    if (error is FormatException) {
      return ValidationError.invalidFormat('Data', 'valid format');
    }

    if (error is ArgumentError) {
      return ValidationError.invalidFormat(
          error.name ?? 'Input', 'valid value');
    }

    if (error is StateError) {
      return AppError.unknown('Invalid state: ${error.message}');
    }

    // For network-related errors (when using http package)
    final errorMessage = error.toString().toLowerCase();
    if (errorMessage.contains('socketexception') ||
        errorMessage.contains('handshakeexception') ||
        errorMessage.contains('timeout')) {
      return NetworkError.noConnection();
    }

    if (errorMessage.contains('http') && errorMessage.contains('500')) {
      return NetworkError.serverError();
    }

    if (errorMessage.contains('http') && errorMessage.contains('404')) {
      return NetworkError.notFound();
    }

    // Default to unknown error
    return AppError.unknown(error.toString());
  }

  /// Handles errors specifically for authentication operations
  static AppError handleAuthError(Object error, StackTrace? stackTrace) {
    final baseError = handleError(error, stackTrace);

    // Convert generic errors to auth-specific errors where appropriate
    if (baseError is NetworkError) {
      return baseError; // Keep network errors as is
    }

    if (baseError is ValidationError) {
      return baseError; // Keep validation errors as is
    }

    // Convert unknown errors to auth errors
    if (baseError.type == AppErrorType.unknown) {
      return AuthError.operationFailed(baseError.message);
    }

    return baseError;
  }

  /// Logs error for debugging purposes
  static void logError(AppError error, {StackTrace? stackTrace}) {
    debugPrint('AppError [${error.type.name}]: ${error.message}');
    if (error.details != null) {
      debugPrint('Details: ${error.details}');
    }
    if (kDebugMode && stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Gets a user-friendly message for the error
  static String getUserMessage(AppError error) {
    switch (error.type) {
      case AppErrorType.network:
        if (error is NetworkError) {
          switch (error.networkErrorType) {
            case NetworkErrorType.noConnection:
              return 'Please check your internet connection and try again.';
            case NetworkErrorType.timeout:
              return 'The request timed out. Please try again.';
            case NetworkErrorType.serverError:
              return 'Server is temporarily unavailable. Please try again later.';
            case NetworkErrorType.notFound:
              return 'The requested resource was not found.';
            case NetworkErrorType.unauthorized:
              return 'Your session has expired. Please sign in again.';
            case NetworkErrorType.forbidden:
              return 'You don\'t have permission to perform this action.';
          }
        }
        return 'Network error occurred. Please try again.';

      case AppErrorType.auth:
        if (error is AuthError) {
          switch (error.authErrorType) {
            case AuthErrorType.invalidCredentials:
              return 'Invalid email or password. Please try again.';
            case AuthErrorType.accountNotFound:
              return 'No account found with this email address.';
            case AuthErrorType.emailAlreadyExists:
              return 'An account with this email already exists.';
            case AuthErrorType.weakPassword:
              return 'Password must be at least 6 characters long.';
            case AuthErrorType.sessionExpired:
              return 'Your session has expired. Please sign in again.';
            case AuthErrorType.operationFailed:
              return error.message;
          }
        }
        return 'Authentication error occurred.';

      case AppErrorType.validation:
        return error.message; // Validation messages are already user-friendly

      case AppErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}
