import 'dart:async';
import 'package:flutter/foundation.dart';

/// Memory management helper to track and prevent memory leaks
class MemoryManager {
  static final MemoryManager _instance = MemoryManager._internal();
  factory MemoryManager() => _instance;
  MemoryManager._internal();

  final Map<String, Set<StreamSubscription>> _subscriptions = {};
  final Map<String, Set<Timer>> _timers = {};
  final Map<String, Set<VoidCallback>> _disposers = {};

  /// Register a stream subscription for a specific feature
  void addSubscription(String feature, StreamSubscription subscription) {
    _subscriptions.putIfAbsent(feature, () => <StreamSubscription>{});
    _subscriptions[feature]!.add(subscription);

    if (kDebugMode) {
      print(
          '[MemoryManager] Added subscription for $feature. Total: ${_subscriptions[feature]!.length}');
    }
  }

  /// Register a timer for a specific feature
  void addTimer(String feature, Timer timer) {
    _timers.putIfAbsent(feature, () => <Timer>{});
    _timers[feature]!.add(timer);

    if (kDebugMode) {
      print(
          '[MemoryManager] Added timer for $feature. Total: ${_timers[feature]!.length}');
    }
  }

  /// Register a disposer function for a specific feature
  void addDisposer(String feature, VoidCallback disposer) {
    _disposers.putIfAbsent(feature, () => <VoidCallback>{});
    _disposers[feature]!.add(disposer);

    if (kDebugMode) {
      print(
          '[MemoryManager] Added disposer for $feature. Total: ${_disposers[feature]!.length}');
    }
  }

  /// Cancel all subscriptions for a specific feature
  Future<void> disposeFeature(String feature) async {
    // Cancel subscriptions
    if (_subscriptions.containsKey(feature)) {
      for (final subscription in _subscriptions[feature]!) {
        await subscription.cancel();
      }
      _subscriptions.remove(feature);
    }

    // Cancel timers
    if (_timers.containsKey(feature)) {
      for (final timer in _timers[feature]!) {
        timer.cancel();
      }
      _timers.remove(feature);
    }

    // Call disposers
    if (_disposers.containsKey(feature)) {
      for (final disposer in _disposers[feature]!) {
        try {
          disposer.call();
        } catch (e) {
          if (kDebugMode) {
            print('[MemoryManager] Error calling disposer for $feature: $e');
          }
        }
      }
      _disposers.remove(feature);
    }

    if (kDebugMode) {
      print('[MemoryManager] Disposed all resources for $feature');
    }
  }

  /// Cancel all subscriptions and timers
  Future<void> disposeAll() async {
    final features = {
      ..._subscriptions.keys,
      ..._timers.keys,
      ..._disposers.keys
    };

    for (final feature in features) {
      await disposeFeature(feature);
    }

    if (kDebugMode) {
      print('[MemoryManager] Disposed all resources');
    }
  }

  /// Get memory usage statistics
  Map<String, dynamic> getMemoryStats() {
    return {
      'subscriptions':
          _subscriptions.map((key, value) => MapEntry(key, value.length)),
      'timers': _timers.map((key, value) => MapEntry(key, value.length)),
      'disposers': _disposers.map((key, value) => MapEntry(key, value.length)),
      'totalSubscriptions':
          _subscriptions.values.fold<int>(0, (sum, set) => sum + set.length),
      'totalTimers':
          _timers.values.fold<int>(0, (sum, set) => sum + set.length),
      'totalDisposers':
          _disposers.values.fold<int>(0, (sum, set) => sum + set.length),
    };
  }

  /// Log current memory usage (debug mode only)
  void logMemoryStats() {
    if (kDebugMode) {
      final stats = getMemoryStats();
      print('[MemoryManager] Memory Stats: $stats');
    }
  }
}

/// Extension to make subscription tracking easier
extension StreamSubscriptionMemory on StreamSubscription {
  /// Track this subscription for automatic disposal
  StreamSubscription track(String feature) {
    MemoryManager().addSubscription(feature, this);
    return this;
  }
}

/// Extension to make timer tracking easier
extension TimerMemory on Timer {
  /// Track this timer for automatic disposal
  Timer track(String feature) {
    MemoryManager().addTimer(feature, this);
    return this;
  }
}

/// Mixin to automatically manage memory for widgets
mixin MemoryManaged {
  String get memoryFeature;

  void addSubscription(StreamSubscription subscription) {
    MemoryManager().addSubscription(memoryFeature, subscription);
  }

  void addTimer(Timer timer) {
    MemoryManager().addTimer(memoryFeature, timer);
  }

  void addDisposer(VoidCallback disposer) {
    MemoryManager().addDisposer(memoryFeature, disposer);
  }

  Future<void> disposeMemory() async {
    await MemoryManager().disposeFeature(memoryFeature);
  }
}
