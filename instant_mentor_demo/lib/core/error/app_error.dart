import 'package:flutter/foundation.dart';

/// Base class for all application errors
abstract class AppError {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppError({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'AppError(message: $message, code: $code)';
  }
}

/// Network related errors
class NetworkError extends AppError {
  const NetworkError({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory NetworkError.noConnection() {
    return const NetworkError(
      message: 'No internet connection. Please check your network settings.',
      code: 'NO_CONNECTION',
    );
  }

  factory NetworkError.timeout() {
    return const NetworkError(
      message: 'Request timed out. Please try again.',
      code: 'TIMEOUT',
    );
  }

  factory NetworkError.serverError([String? details]) {
    return NetworkError(
      message: details ?? 'Server error occurred. Please try again later.',
      code: 'SERVER_ERROR',
    );
  }
}

/// Authentication related errors
class AuthError extends AppError {
  const AuthError({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory AuthError.invalidCredentials() {
    return const AuthError(
      message: 'Invalid email or password. Please try again.',
      code: 'INVALID_CREDENTIALS',
    );
  }

  factory AuthError.accountNotFound() {
    return const AuthError(
      message: 'Account not found. Please check your email or sign up.',
      code: 'ACCOUNT_NOT_FOUND',
    );
  }

  factory AuthError.emailAlreadyExists() {
    return const AuthError(
      message: 'An account with this email already exists.',
      code: 'EMAIL_EXISTS',
    );
  }

  factory AuthError.weakPassword() {
    return const AuthError(
      message: 'Password is too weak. Please choose a stronger password.',
      code: 'WEAK_PASSWORD',
    );
  }

  factory AuthError.sessionExpired() {
    return const AuthError(
      message: 'Your session has expired. Please log in again.',
      code: 'SESSION_EXPIRED',
    );
  }
}

/// Validation related errors
class ValidationError extends AppError {
  final String field;

  const ValidationError({
    required this.field,
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory ValidationError.required(String field) {
    return ValidationError(
      field: field,
      message: '$field is required.',
      code: 'REQUIRED',
    );
  }

  factory ValidationError.invalidFormat(String field, String format) {
    return ValidationError(
      field: field,
      message: 'Please enter a valid $format for $field.',
      code: 'INVALID_FORMAT',
    );
  }

  factory ValidationError.tooShort(String field, int minLength) {
    return ValidationError(
      field: field,
      message: '$field must be at least $minLength characters long.',
      code: 'TOO_SHORT',
    );
  }

  factory ValidationError.tooLong(String field, int maxLength) {
    return ValidationError(
      field: field,
      message: '$field must be no longer than $maxLength characters.',
      code: 'TOO_LONG',
    );
  }
}

/// General application errors
class AppGeneralError extends AppError {
  const AppGeneralError({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory AppGeneralError.unknown([dynamic error]) {
    return AppGeneralError(
      message: 'An unexpected error occurred. Please try again.',
      code: 'UNKNOWN',
      originalError: error,
    );
  }

  factory AppGeneralError.notFound(String resource) {
    return AppGeneralError(
      message: '$resource not found.',
      code: 'NOT_FOUND',
    );
  }

  factory AppGeneralError.permissionDenied() {
    return const AppGeneralError(
      message: 'You do not have permission to perform this action.',
      code: 'PERMISSION_DENIED',
    );
  }
}

/// Utility class for error handling
class ErrorHandler {
  static AppError handleError(dynamic error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('ErrorHandler: $error');
      if (stackTrace != null) {
        print('StackTrace: $stackTrace');
      }
    }

    if (error is AppError) {
      return error;
    }

    // Handle common Flutter/Dart errors
    if (error is TypeError) {
      return AppGeneralError(
        message: 'A technical error occurred. Please try again.',
        code: 'TYPE_ERROR',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return ValidationError(
        field: 'input',
        message: 'Invalid format. Please check your input.',
        code: 'FORMAT_ERROR',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Default case
    return AppGeneralError.unknown(error);
  }

  static String getDisplayMessage(AppError error) {
    return error.message;
  }
}
