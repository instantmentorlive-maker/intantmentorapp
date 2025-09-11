import '../error/app_error.dart';

/// Base result class for repository operations
sealed class Result<T> {
  const Result();
}

/// Success result containing data
class Success<T> extends Result<T> {
  final T data;
  
  const Success(this.data);
}

/// Failure result containing error
class Failure<T> extends Result<T> {
  final AppError error;
  
  const Failure(this.error);
}

/// Extension methods for Result handling
extension ResultExtension<T> on Result<T> {
  /// Check if result is success
  bool get isSuccess => this is Success<T>;
  
  /// Check if result is failure
  bool get isFailure => this is Failure<T>;
  
  /// Get data if success, null otherwise
  T? get data => isSuccess ? (this as Success<T>).data : null;
  
  /// Get error if failure, null otherwise
  AppError? get error => isFailure ? (this as Failure<T>).error : null;
  
  /// Execute function if success
  Result<U> map<U>(U Function(T data) mapper) {
    return switch (this) {
      Success<T>(data: final data) => Success(mapper(data)),
      Failure<T>(error: final error) => Failure(error),
    };
  }
  
  /// Execute async function if success
  Future<Result<U>> mapAsync<U>(Future<U> Function(T data) mapper) async {
    return switch (this) {
      Success<T>(data: final data) => Success(await mapper(data)),
      Failure<T>(error: final error) => Failure(error),
    };
  }
  
  /// Execute function on failure
  Result<T> onError(void Function(AppError error) onError) {
    if (isFailure) {
      onError((this as Failure<T>).error);
    }
    return this;
  }
  
  /// Execute function on success
  Result<T> onSuccess(void Function(T data) onSuccess) {
    if (isSuccess) {
      onSuccess((this as Success<T>).data);
    }
    return this;
  }
}

/// Utility methods for creating Results
class ResultUtils {
  /// Create success result
  static Result<T> success<T>(T data) => Success(data);
  
  /// Create failure result
  static Result<T> failure<T>(AppError error) => Failure(error);
  
  /// Wrap function execution in Result
  static Result<T> tryCall<T>(T Function() operation) {
    try {
      return Success(operation());
    } catch (e, stackTrace) {
      return Failure(ErrorHandler.handleError(e, stackTrace));
    }
  }
  
  /// Wrap async function execution in Result
  static Future<Result<T>> tryCallAsync<T>(Future<T> Function() operation) async {
    try {
      final result = await operation();
      return Success(result);
    } catch (e, stackTrace) {
      return Failure(ErrorHandler.handleError(e, stackTrace));
    }
  }
}
