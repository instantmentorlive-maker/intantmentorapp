import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error/app_error.dart';
import '../../../core/providers/error_provider.dart';

/// Global error handler widget that shows errors using SnackBar
class ErrorHandlerWidget extends ConsumerWidget {
  final Widget child;

  const ErrorHandlerWidget({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to error state
    ref.listen(errorProvider, (previous, next) {
      if (next.currentError != null && 
          (previous?.currentError == null || 
           previous!.currentError != next.currentError)) {
        _showErrorSnackBar(context, ref, next.currentError!);
      }
    });

    return child;
  }

  void _showErrorSnackBar(BuildContext context, WidgetRef ref, AppError error) {
    final messenger = ScaffoldMessenger.of(context);
    
    // Clear any existing snackbars
    messenger.clearSnackBars();

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            _getErrorIcon(error),
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ErrorHandler.getDisplayMessage(error),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                if (error.code != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Error Code: ${error.code}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      backgroundColor: _getErrorColor(error),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      action: SnackBarAction(
        label: 'Dismiss',
        textColor: Colors.white,
        onPressed: () {
          ref.read(errorProvider.notifier).clearError();
        },
      ),
      duration: _getErrorDuration(error),
    );

    messenger.showSnackBar(snackBar).closed.then((_) {
      // Auto-clear error after snackbar is closed
      ref.read(errorProvider.notifier).clearError();
    });
  }

  IconData _getErrorIcon(AppError error) {
    if (error is NetworkError) {
      return Icons.wifi_off;
    } else if (error is AuthError) {
      return Icons.lock_outline;
    } else if (error is ValidationError) {
      return Icons.warning_outlined;
    } else {
      return Icons.error_outline;
    }
  }

  Color _getErrorColor(AppError error) {
    if (error is NetworkError) {
      return Colors.orange;
    } else if (error is AuthError) {
      return Colors.red.shade700;
    } else if (error is ValidationError) {
      return Colors.amber.shade700;
    } else {
      return Colors.red;
    }
  }

  Duration _getErrorDuration(AppError error) {
    if (error is ValidationError) {
      return const Duration(seconds: 3);
    } else if (error is NetworkError) {
      return const Duration(seconds: 5);
    } else {
      return const Duration(seconds: 4);
    }
  }
}

/// Utility methods for showing errors from anywhere in the app
class ErrorUtils {
  /// Show a simple error message
  static void showError(WidgetRef ref, String message, [String? code]) {
    final error = AppGeneralError(message: message, code: code);
    ref.read(errorProvider.notifier).showError(error);
  }

  /// Show a network error
  static void showNetworkError(WidgetRef ref, [String? message]) {
    final error = message != null 
        ? NetworkError(message: message)
        : NetworkError.noConnection();
    ref.read(errorProvider.notifier).showError(error);
  }

  /// Show an auth error
  static void showAuthError(WidgetRef ref, String message, [String? code]) {
    final error = AuthError(message: message, code: code);
    ref.read(errorProvider.notifier).showError(error);
  }

  /// Show a validation error
  static void showValidationError(WidgetRef ref, String field, String message, [String? code]) {
    final error = ValidationError(field: field, message: message, code: code);
    ref.read(errorProvider.notifier).showError(error);
  }

  /// Handle any error and show appropriate message
  static void handleAndShowError(WidgetRef ref, dynamic error, [StackTrace? stackTrace]) {
    ref.read(errorProvider.notifier).handleError(error, stackTrace);
  }

  /// Clear current error
  static void clearError(WidgetRef ref) {
    ref.read(errorProvider.notifier).clearError();
  }
}
