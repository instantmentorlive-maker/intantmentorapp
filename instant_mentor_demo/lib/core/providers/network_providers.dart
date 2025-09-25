import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/enhanced_network_client.dart';
import '../network/http_cache.dart';
import '../network/http_performance.dart';
import '../network/offline_manager.dart';
import '../utils/logger.dart';

/// Provider for the enhanced HTTP client
final enhancedHttpClientProvider = Provider<Dio>((ref) {
  return EnhancedNetworkClient.instance;
});

/// Provider for HTTP performance statistics
final httpPerformanceStatsProvider = Provider<PerformanceStats>((ref) {
  return HttpPerformanceMonitor.getStats();
});

/// Provider for HTTP cache statistics
final httpCacheStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return HttpCache.getStats();
});

/// Provider for offline manager statistics
final offlineStatsProvider = Provider<Map<String, dynamic>>((ref) {
  return OfflineManager.getStats();
});

/// Provider for comprehensive network statistics
final networkStatsProvider = Provider<Map<String, dynamic>>((ref) {
  return EnhancedNetworkClient.getPerformanceStats();
});

/// Provider for network connectivity status
final networkConnectivityProvider = StateNotifierProvider<
    NetworkConnectivityNotifier, NetworkConnectivityState>((ref) {
  return NetworkConnectivityNotifier();
});

/// Network connectivity state
class NetworkConnectivityState {
  final bool isOnline;
  final DateTime lastChecked;
  final int queuedRequestsCount;

  NetworkConnectivityState({
    required this.isOnline,
    required this.lastChecked,
    required this.queuedRequestsCount,
  });

  NetworkConnectivityState copyWith({
    bool? isOnline,
    DateTime? lastChecked,
    int? queuedRequestsCount,
  }) {
    return NetworkConnectivityState(
      isOnline: isOnline ?? this.isOnline,
      lastChecked: lastChecked ?? this.lastChecked,
      queuedRequestsCount: queuedRequestsCount ?? this.queuedRequestsCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkConnectivityState &&
          runtimeType == other.runtimeType &&
          isOnline == other.isOnline &&
          queuedRequestsCount == other.queuedRequestsCount;

  @override
  int get hashCode => isOnline.hashCode ^ queuedRequestsCount.hashCode;
}

/// Network connectivity state notifier
class NetworkConnectivityNotifier
    extends StateNotifier<NetworkConnectivityState> {
  NetworkConnectivityNotifier()
      : super(NetworkConnectivityState(
          isOnline: true,
          lastChecked: DateTime.now(),
          queuedRequestsCount: 0,
        )) {
    _startPeriodicCheck();
  }

  /// Start periodic connectivity checking
  void _startPeriodicCheck() {
    // Check connectivity every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (mounted) {
        await checkConnectivity();
      } else {
        timer.cancel();
      }
    });
  }

  /// Check current connectivity status
  Future<void> checkConnectivity() async {
    try {
      final isOnline = await EnhancedNetworkClient.hasConnection();
      final queuedCount = OfflineManager.queueSize;

      state = state.copyWith(
        isOnline: isOnline,
        lastChecked: DateTime.now(),
        queuedRequestsCount: queuedCount,
      );

      Logger.debug(
          'Connectivity check: ${isOnline ? "online" : "offline"}, queued: $queuedCount');
    } catch (e) {
      Logger.error('Failed to check connectivity: $e');
    }
  }

  /// Force process offline queue
  Future<void> processOfflineQueue() async {
    try {
      await OfflineManager.forceProcessQueue();
      await checkConnectivity(); // Refresh state
      Logger.info('Offline queue processing completed');
    } catch (e) {
      Logger.error('Failed to process offline queue: $e');
    }
  }

  /// Clear offline queue
  Future<void> clearOfflineQueue() async {
    try {
      await OfflineManager.clearQueue();
      await checkConnectivity(); // Refresh state
      Logger.info('Offline queue cleared');
    } catch (e) {
      Logger.error('Failed to clear offline queue: $e');
    }
  }
}

/// Provider for network performance monitoring
final networkPerformanceProvider =
    StateNotifierProvider<NetworkPerformanceNotifier, NetworkPerformanceState>(
        (ref) {
  return NetworkPerformanceNotifier();
});

/// Network performance state
class NetworkPerformanceState {
  final bool isMonitoring;
  final PerformanceStats stats;
  final DateTime lastUpdated;

  NetworkPerformanceState({
    required this.isMonitoring,
    required this.stats,
    required this.lastUpdated,
  });

  NetworkPerformanceState copyWith({
    bool? isMonitoring,
    PerformanceStats? stats,
    DateTime? lastUpdated,
  }) {
    return NetworkPerformanceState(
      isMonitoring: isMonitoring ?? this.isMonitoring,
      stats: stats ?? this.stats,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Network performance state notifier
class NetworkPerformanceNotifier
    extends StateNotifier<NetworkPerformanceState> {
  NetworkPerformanceNotifier()
      : super(NetworkPerformanceState(
          isMonitoring: HttpPerformanceMonitor.isEnabled,
          stats: HttpPerformanceMonitor.getStats(),
          lastUpdated: DateTime.now(),
        )) {
    _startPeriodicUpdate();
  }

  /// Start periodic performance stats update
  void _startPeriodicUpdate() {
    // Update stats every 10 seconds
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        updateStats();
      } else {
        timer.cancel();
      }
    });
  }

  /// Update performance statistics
  void updateStats() {
    try {
      final newStats = HttpPerformanceMonitor.getStats();
      state = state.copyWith(
        stats: newStats,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      Logger.error('Failed to update performance stats: $e');
    }
  }

  /// Enable performance monitoring
  void enableMonitoring() {
    HttpPerformanceMonitor.setEnabled(true);
    state = state.copyWith(isMonitoring: true);
    Logger.info('Network performance monitoring enabled');
  }

  /// Disable performance monitoring
  void disableMonitoring() {
    HttpPerformanceMonitor.setEnabled(false);
    state = state.copyWith(isMonitoring: false);
    Logger.info('Network performance monitoring disabled');
  }

  /// Reset performance metrics
  void resetMetrics() {
    HttpPerformanceMonitor.reset();
    updateStats();
    Logger.info('Network performance metrics reset');
  }
}

/// HTTP cache management provider
final httpCacheProvider =
    StateNotifierProvider<HttpCacheNotifier, HttpCacheState>((ref) {
  return HttpCacheNotifier();
});

/// HTTP cache state
class HttpCacheState {
  final bool isEnabled;
  final Map<String, dynamic> stats;
  final DateTime lastUpdated;

  HttpCacheState({
    required this.isEnabled,
    required this.stats,
    required this.lastUpdated,
  });

  HttpCacheState copyWith({
    bool? isEnabled,
    Map<String, dynamic>? stats,
    DateTime? lastUpdated,
  }) {
    return HttpCacheState(
      isEnabled: isEnabled ?? this.isEnabled,
      stats: stats ?? this.stats,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// HTTP cache state notifier
class HttpCacheNotifier extends StateNotifier<HttpCacheState> {
  HttpCacheNotifier()
      : super(HttpCacheState(
          isEnabled: true,
          stats: {},
          lastUpdated: DateTime.now(),
        )) {
    _updateStats();
  }

  /// Update cache statistics
  Future<void> _updateStats() async {
    try {
      final stats = await HttpCache.getStats();
      state = state.copyWith(
        stats: stats,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      Logger.error('Failed to update cache stats: $e');
    }
  }

  /// Clear HTTP cache
  Future<void> clearCache() async {
    try {
      await HttpCache.clear();
      await _updateStats();
      Logger.info('HTTP cache cleared');
    } catch (e) {
      Logger.error('Failed to clear cache: $e');
    }
  }

  /// Refresh cache statistics
  Future<void> refreshStats() async {
    await _updateStats();
  }
}
