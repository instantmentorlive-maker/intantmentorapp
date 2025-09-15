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
      return AppGeneralError.unknown('Invalid state: ${error.message}');
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
      return AppGeneralError.notFound('Requested resource');
    }

    // Default to unknown error
    return AppGeneralError.unknown(error.toString());
  }

  /// Handles errors specifically for authentication operations
  static AppError handleAuthError(Object error, StackTrace? stackTrace) {
    final baseError = handleError(error, stackTrace);

    // Preserve specific error types
    if (baseError is NetworkError ||
        baseError is ValidationError ||
        baseError is AuthError) {
      return baseError;
    }

    // Wrap anything else in a generic auth error context
    return AuthError(
      message: baseError.message,
      code: baseError.code ?? 'AUTH_OPERATION_FAILED',
      originalError: baseError,
      stackTrace: stackTrace,
    );
  }

  /// Logs error for debugging purposes
  static void logError(AppError error, {StackTrace? stackTrace}) {
    debugPrint(
        'AppError [${error.runtimeType}]: ${error.message} (${error.code ?? 'NO_CODE'})');
    if (kDebugMode && stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Gets a user-friendly message for the error
  static String getUserMessage(AppError error) {
    // Our AppError classes already carry user-friendly messages.
    // Return them directly, with a few common fallbacks based on code.
    if (error is NetworkError ||
        error is ValidationError ||
        error is AuthError) {
      return error.message;
    }
    return error.message.isNotEmpty
        ? error.message
        : 'An unexpected error occurred. Please try again.';
  }
}
