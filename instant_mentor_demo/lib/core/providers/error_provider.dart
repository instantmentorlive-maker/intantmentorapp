import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../error/app_error.dart';

/// Global error state
class ErrorState {
  final AppError? currentError;
  final List<AppError> errorHistory;

  const ErrorState({
    this.currentError,
    this.errorHistory = const [],
  });

  ErrorState copyWith({
    AppError? currentError,
    List<AppError>? errorHistory,
  }) {
    return ErrorState(
      currentError: currentError,
      errorHistory: errorHistory ?? this.errorHistory,
    );
  }
}

/// Global error notifier
class ErrorNotifier extends StateNotifier<ErrorState> {
  ErrorNotifier() : super(const ErrorState());

  /// Show an error
  void showError(AppError error) {
    if (kDebugMode) {
      print('ErrorNotifier: Showing error: ${error.message}');
    }

    final newHistory = [...state.errorHistory, error];
    
    // Keep only last 10 errors in history
    if (newHistory.length > 10) {
      newHistory.removeAt(0);
    }

    state = state.copyWith(
      currentError: error,
      errorHistory: newHistory,
    );
  }

  /// Clear current error
  void clearError() {
    if (kDebugMode) {
      print('ErrorNotifier: Clearing current error');
    }
    
    state = state.copyWith(currentError: null);
  }

  /// Clear all errors
  void clearAllErrors() {
    if (kDebugMode) {
      print('ErrorNotifier: Clearing all errors');
    }
    
    state = const ErrorState();
  }

  /// Handle and show error
  void handleError(dynamic error, [StackTrace? stackTrace]) {
    final appError = ErrorHandler.handleError(error, stackTrace);
    showError(appError);
  }
}

/// Provider for global error state
final errorProvider = StateNotifierProvider<ErrorNotifier, ErrorState>((ref) {
  return ErrorNotifier();
});
