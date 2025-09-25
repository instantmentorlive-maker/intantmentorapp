import 'package:dio/dio.dart';

import '../error/app_error.dart';
import '../utils/logger.dart';
import '../utils/result.dart';

/// Network error mapper that converts Dio errors to our Result<T> system
class NetworkErrorHandler {
  /// Convert a Dio error to our standardized Result<T> failure
  static Result<T> handleError<T>(dynamic error) {
    if (error is DioException) {
      return _handleDioError<T>(error);
    } else {
      Logger.error('Unexpected error: $error');
      return Failure(
        AppGeneralError.unknown(error),
      );
    }
  }

  /// Handle specific Dio error types
  static Result<T> _handleDioError<T>(DioException error) {
    Logger.error('DioException: ${error.type} - ${error.message}');

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return Failure(NetworkError.timeout());

      case DioExceptionType.sendTimeout:
        return Failure(NetworkError.timeout());

      case DioExceptionType.receiveTimeout:
        return Failure(NetworkError.timeout());

      case DioExceptionType.badResponse:
        return _handleResponseError<T>(error);

      case DioExceptionType.cancel:
        return const Failure(
          NetworkError(message: 'Request was cancelled.', code: 'CANCELLED'),
        );

      case DioExceptionType.connectionError:
        return Failure(NetworkError.noConnection());

      case DioExceptionType.badCertificate:
        return const Failure(
          NetworkError(
            message:
                'SSL certificate error. Please check your connection security.',
            code: 'SSL_ERROR',
          ),
        );

      case DioExceptionType.unknown:
        return Failure(NetworkError.serverError(error.message));
    }
  }

  /// Handle HTTP response errors based on status codes
  static Result<T> _handleResponseError<T>(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode ?? 0;
    final data = response?.data;

    // Try to extract error message from response
    String errorMessage = 'An error occurred';
    if (data is Map<String, dynamic>) {
      errorMessage =
          data['message'] ?? data['error'] ?? data['detail'] ?? errorMessage;
    }

    Logger.error('HTTP Error $statusCode: $errorMessage');

    switch (statusCode) {
      case 400:
        return Failure(
          ValidationError(
            field: 'request',
            message: errorMessage,
            code: 'BAD_REQUEST',
          ),
        );

      case 401:
        return Failure(AuthError.sessionExpired());

      case 403:
        return Failure(AppGeneralError.permissionDenied());

      case 404:
        return Failure(AppGeneralError.notFound('resource'));

      case 409:
        return Failure(
          ValidationError(
            field: 'data',
            message: errorMessage,
            code: 'CONFLICT',
          ),
        );

      case 422:
        return Failure(
          ValidationError(
            field: 'input',
            message: errorMessage,
            code: 'VALIDATION_ERROR',
          ),
        );

      case 429:
        return const Failure(
          NetworkError(
            message: 'Too many requests. Please wait before trying again.',
            code: 'RATE_LIMITED',
          ),
        );

      case 500:
        return Failure(NetworkError.serverError(
            'Internal server error. Please try again later.'));

      case 502:
        return Failure(NetworkError.serverError(
            'Bad gateway. The server is temporarily unavailable.'));

      case 503:
        return Failure(NetworkError.serverError(
            'Service unavailable. Please try again later.'));

      case 504:
        return Failure(NetworkError.serverError(
            'Gateway timeout. The server is taking too long to respond.'));

      default:
        return Failure(NetworkError.serverError(
            'Server error ($statusCode): $errorMessage'));
    }
  }

  /// Extract validation errors from response
  static Map<String, List<String>> extractValidationErrors(
      dynamic responseData) {
    final errors = <String, List<String>>{};

    if (responseData is Map<String, dynamic>) {
      // Laravel-style validation errors
      if (responseData['errors'] is Map<String, dynamic>) {
        final errorsData = responseData['errors'] as Map<String, dynamic>;
        errorsData.forEach((field, messages) {
          if (messages is List) {
            errors[field] = messages.cast<String>();
          } else if (messages is String) {
            errors[field] = [messages];
          }
        });
      }
      // Direct field errors
      else {
        responseData.forEach((field, messages) {
          if (messages is List) {
            errors[field] = messages.cast<String>();
          } else if (messages is String) {
            errors[field] = [messages];
          }
        });
      }
    }

    return errors;
  }

  /// Check if error is recoverable (can retry)
  static bool isRecoverable(AppError error) {
    if (error is NetworkError) return true;
    if (error is AuthError && error.code == 'SESSION_EXPIRED') return false;
    if (error is ValidationError) return false;
    if (error is AppGeneralError && error.code == 'PERMISSION_DENIED') {
      return false;
    }
    return false;
  }

  /// Get retry delay in seconds based on error type
  static int getRetryDelay(AppError error) {
    if (error is NetworkError && error.code == 'RATE_LIMITED') return 60;
    if (error is NetworkError) return 5;
    return 0;
  }
}
