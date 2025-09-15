import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Custom provider observer for debugging state changes
class DebugProviderObserver extends ProviderObserver {
  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    if (kDebugMode) {
      print(
          '🟢 [Provider] Added: ${provider.name ?? provider.runtimeType} = $value');
    }
    super.didAddProvider(provider, value, container);
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (kDebugMode) {
      print('🔄 [Provider] Updated: ${provider.name ?? provider.runtimeType}');
      print('   Previous: $previousValue');
      print('   New: $newValue');
    }
    super.didUpdateProvider(provider, previousValue, newValue, container);
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    if (kDebugMode) {
      print('🔴 [Provider] Disposed: ${provider.name ?? provider.runtimeType}');
    }
    super.didDisposeProvider(provider, container);
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    if (kDebugMode) {
      print('❌ [Provider] Error: ${provider.name ?? provider.runtimeType}');
      print('   Error: $error');
      print('   Stack: $stackTrace');
    }
    super.providerDidFail(provider, error, stackTrace, container);
  }
}

/// Production-safe provider observer that only logs critical events
class ProductionProviderObserver extends ProviderObserver {
  final void Function(String message, {Object? error, StackTrace? stackTrace})?
      onLog;

  ProductionProviderObserver({this.onLog});

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    // Only log errors in production
    onLog?.call(
      'Provider error: ${provider.name ?? provider.runtimeType}',
      error: error,
      stackTrace: stackTrace,
    );
    super.providerDidFail(provider, error, stackTrace, container);
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    // Track disposed providers for memory leak detection
    if (kDebugMode) {
      onLog
          ?.call('Provider disposed: ${provider.name ?? provider.runtimeType}');
    }
    super.didDisposeProvider(provider, container);
  }
}

/// Memory leak detection observer
class MemoryLeakObserver extends ProviderObserver {
  final Map<String, int> _providerCounts = {};
  final Map<String, DateTime> _providerCreated = {};

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    final key = provider.name ?? provider.runtimeType.toString();
    _providerCounts[key] = (_providerCounts[key] ?? 0) + 1;
    _providerCreated[key] = DateTime.now();

    // Warn if too many instances of same provider
    if (_providerCounts[key]! > 10) {
      if (kDebugMode) {
        print(
            '⚠️ [MemoryLeak] Many instances of $key: ${_providerCounts[key]}');
      }
    }

    super.didAddProvider(provider, value, container);
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    final key = provider.name ?? provider.runtimeType.toString();
    _providerCounts[key] = (_providerCounts[key] ?? 1) - 1;

    if (_providerCounts[key]! <= 0) {
      _providerCounts.remove(key);
      _providerCreated.remove(key);
    }

    super.didDisposeProvider(provider, container);
  }

  /// Get current provider statistics
  Map<String, dynamic> getStats() {
    return {
      'activePoviders': Map.from(_providerCounts),
      'totalActive':
          _providerCounts.values.fold<int>(0, (sum, count) => sum + count),
    };
  }

  /// Log memory statistics
  void logStats() {
    if (kDebugMode) {
      final stats = getStats();
      print('📊 [MemoryStats] ${stats['totalActive']} active providers');

      // Show long-lived providers
      final now = DateTime.now();
      for (final entry in _providerCreated.entries) {
        final duration = now.difference(entry.value);
        if (duration.inMinutes > 5) {
          print('   Long-lived: ${entry.key} (${duration.inMinutes}min)');
        }
      }
    }
  }
}
