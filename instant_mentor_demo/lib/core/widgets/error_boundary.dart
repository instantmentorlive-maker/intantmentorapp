import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Error boundary widget for chat features
class ChatErrorBoundary extends ConsumerWidget {
  final Widget child;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const ChatErrorBoundary({
    super.key,
    required this.child,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorBoundary(
      feature: 'Chat',
      errorMessage: errorMessage,
      onRetry: onRetry,
      child: child,
    );
  }
}

/// Error boundary widget for call features
class CallErrorBoundary extends ConsumerWidget {
  final Widget child;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const CallErrorBoundary({
    super.key,
    required this.child,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorBoundary(
      feature: 'Video Calling',
      errorMessage: errorMessage,
      onRetry: onRetry,
      child: child,
    );
  }
}

/// Error boundary widget for payment features
class PaymentErrorBoundary extends ConsumerWidget {
  final Widget child;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const PaymentErrorBoundary({
    super.key,
    required this.child,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorBoundary(
      feature: 'Payments',
      errorMessage: errorMessage,
      onRetry: onRetry,
      child: child,
    );
  }
}

/// Generic error boundary widget
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String feature;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const ErrorBoundary({
    super.key,
    required this.child,
    required this.feature,
    this.errorMessage,
    this.onRetry,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _hasError = widget.errorMessage != null;
    _errorMessage = widget.errorMessage;
  }

  @override
  void didUpdateWidget(ErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != oldWidget.errorMessage) {
      setState(() {
        _hasError = widget.errorMessage != null;
        _errorMessage = widget.errorMessage;
      });
    }
  }

  void _handleError(dynamic error, StackTrace stackTrace) {
    setState(() {
      _hasError = true;
      _errorMessage = error.toString();
    });

    // Log error for debugging
    debugPrint('${widget.feature} Error: $error');
    debugPrint('Stack trace: $stackTrace');
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _ErrorFallbackWidget(
        feature: widget.feature,
        errorMessage: _errorMessage,
        onRetry: _retry,
      );
    }

    // Wrap child in error handling
    return ErrorHandler(
      onError: _handleError,
      child: widget.child,
    );
  }
}

/// Error handler wrapper that catches errors
class ErrorHandler extends StatelessWidget {
  final Widget child;
  final Function(dynamic, StackTrace) onError;

  const ErrorHandler({
    super.key,
    required this.child,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (error, stackTrace) {
          onError(error, stackTrace);
          return const SizedBox.shrink();
        }
      },
    );
  }
}

/// Error fallback widget displayed when an error occurs
class _ErrorFallbackWidget extends StatelessWidget {
  final String feature;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const _ErrorFallbackWidget({
    required this.feature,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '$feature Error',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Something went wrong. Please try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
          ],
        ),
      ),
    );
  }
}
