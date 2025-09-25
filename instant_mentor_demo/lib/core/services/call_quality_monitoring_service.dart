import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

// Stub: CallQualityMonitoringService removed
class CallQualityMonitoringService {
  CallQualityMonitoringService();
  Stream<dynamic> get qualityStream => const Stream.empty();
  Stream<dynamic> get alertStream => const Stream.empty();
  void startMonitoring() {}
  void stopMonitoring() {}
  void dispose() {}
}

  /// Start comprehensive quality monitoring
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    debugPrint('$_tag: Starting call quality monitoring...');

    _isMonitoring = true;

    // Start network connectivity monitoring
    await _startNetworkMonitoring();

    // Start periodic quality checks
    _monitoringTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _performQualityCheck(),
    );

    // Start adaptive streaming monitoring
    _adaptationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _performAdaptationCheck(),
    );

    // Listen to video service quality updates
    _videoService.qualityStream.listen(_handleQualityUpdate);

    debugPrint('$_tag: ✅ Quality monitoring started');
  }

  /// Stop quality monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    debugPrint('$_tag: Stopping call quality monitoring...');

    _isMonitoring = false;

    _monitoringTimer?.cancel();
    _adaptationTimer?.cancel();
    await _connectivitySubscription?.cancel();

    _monitoringTimer = null;
    _adaptationTimer = null;
    _connectivitySubscription = null;

    debugPrint('$_tag: ✅ Quality monitoring stopped');
  }

  /// Get current call quality statistics
  CallQualityStats getCurrentQuality() {
    if (_qualityHistory.isEmpty) {
      return CallQualityStats.empty();
    }

    final recent = _qualityHistory.take(10).toList();
    final avgLatency =
        recent.map((d) => d.latency).reduce((a, b) => a + b) / recent.length;

    final avgPacketLoss =
        recent.map((d) => d.packetLoss).reduce((a, b) => a + b) / recent.length;

    final mostCommonNetworkQuality =
        _getMostFrequentQuality(recent.map((d) => d.networkQuality).toList());

    return CallQualityStats(
      averageLatency: avgLatency.round(),
      averagePacketLoss: avgPacketLoss,
      networkQuality: mostCommonNetworkQuality,
      connectionType: _currentConnectionType.toString(),
      currentVideoProfile: _currentVideoProfile,
      qualityScore: _calculateQualityScore(avgLatency.round(), avgPacketLoss),
      adaptationCount: _getAdaptationCount(),
    );
  }

  /// Get quality history for analytics
  List<CallQualityData> getQualityHistory({int? limit}) {
    if (limit != null) {
      return _qualityHistory.take(limit).toList();
    }
    return List.from(_qualityHistory);
  }

  /// Manually trigger video profile adaptation
  Future<void> adaptVideoProfile(String profileName) async {
    if (!_videoProfiles.containsKey(profileName)) {
      debugPrint('$_tag: ❌ Unknown video profile: $profileName');
      return;
    }

    final profile = _videoProfiles[profileName]!;

    try {
      debugPrint('$_tag: Adapting to video profile: ${profile.name}');

      // Apply video profile would go here
      // This is a placeholder for the actual Agora configuration

      _currentVideoProfile = profileName;

      _adaptationController.add(AdaptationEvent(
        type: AdaptationEventType.videoProfileChanged,
        message: 'Video quality adapted to ${profile.name}',
        data: {
          'profileName': profileName,
          'resolution': '${profile.width}x${profile.height}',
          'frameRate': profile.frameRate,
          'bitrate': profile.bitrate,
        },
      ));

      debugPrint('$_tag: ✅ Video profile adapted to ${profile.name}');
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to adapt video profile: $e');
    }
  }

  /// Start network connectivity monitoring
  Future<void> _startNetworkMonitoring() async {
    try {
      // Get initial connectivity status
      _currentConnectionType = await _connectivity.checkConnectivity();
      debugPrint('$_tag: Initial connection type: $_currentConnectionType');

      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (ConnectivityResult result) {
          _handleConnectivityChange(result);
        },
        onError: (error) {
          debugPrint('$_tag: ❌ Connectivity monitoring error: $error');
        },
      );
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to start network monitoring: $e');
    }
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(ConnectivityResult result) {
    debugPrint(
        '$_tag: Connectivity changed: $_currentConnectionType → $result');

    final previousType = _currentConnectionType;
    _currentConnectionType = result;

    // Trigger adaptation based on new connection type
    _triggerConnectionBasedAdaptation(previousType, result);

    _alertController.add(QualityAlert(
      type: QualityAlertType.connectivityChanged,
      severity: AlertSeverity.info,
      message: 'Connection changed to ${result.toString()}',
      data: {
        'previousType': previousType.toString(),
        'currentType': result.toString(),
      },
    ));
  }

  /// Perform periodic quality checks
  void _performQualityCheck() {
    if (!_isMonitoring || _qualityHistory.isEmpty) return;

    final latestQuality = _qualityHistory.first;

    // Check for poor latency
    if (latestQuality.latency > _poorLatencyThreshold) {
      _alertController.add(QualityAlert(
        type: QualityAlertType.highLatency,
        severity: AlertSeverity.warning,
        message: 'High latency detected: ${latestQuality.latency}ms',
        data: {'latency': latestQuality.latency},
      ));
    }

    // Check for high packet loss
    if (latestQuality.packetLoss > _highPacketLossThreshold) {
      _alertController.add(QualityAlert(
        type: QualityAlertType.highPacketLoss,
        severity: AlertSeverity.warning,
        message:
            'High packet loss: ${(latestQuality.packetLoss * 100).toStringAsFixed(1)}%',
        data: {'packetLoss': latestQuality.packetLoss},
      ));
    }

    // Check for poor network quality
    if (latestQuality.networkQuality == 'poor' ||
        latestQuality.networkQuality == 'bad') {
      _alertController.add(QualityAlert(
        type: QualityAlertType.poorNetworkQuality,
        severity: AlertSeverity.error,
        message: 'Poor network quality: ${latestQuality.networkQuality}',
        data: {'networkQuality': latestQuality.networkQuality},
      ));
    }
  }

  /// Perform adaptive streaming checks
  void _performAdaptationCheck() {
    if (!_isMonitoring || _qualityHistory.isEmpty) return;

    // Analyze recent quality data
    final recentData = _qualityHistory.take(5).toList();

    final avgLatency =
        recentData.map((d) => d.latency).reduce((a, b) => a + b) /
            recentData.length;

    final avgPacketLoss =
        recentData.map((d) => d.packetLoss).reduce((a, b) => a + b) /
            recentData.length;

    final poorQualityCount = recentData
        .where((d) => d.networkQuality == 'poor' || d.networkQuality == 'bad')
        .length;

    // Determine if adaptation is needed
    String targetProfile = _currentVideoProfile;

    if (poorQualityCount >= 3 ||
        avgLatency > _poorLatencyThreshold ||
        avgPacketLoss > _highPacketLossThreshold) {
      // Degrade quality
      if (_currentVideoProfile == 'high') {
        targetProfile = 'medium';
      } else if (_currentVideoProfile == 'medium') {
        targetProfile = 'low';
      }
    } else if (poorQualityCount == 0 &&
        avgLatency < 100 &&
        avgPacketLoss < 0.01) {
      // Improve quality
      if (_currentVideoProfile == 'low') {
        targetProfile = 'medium';
      } else if (_currentVideoProfile == 'medium') {
        targetProfile = 'high';
      }
    }

    if (targetProfile != _currentVideoProfile) {
      adaptVideoProfile(targetProfile);
    }
  }

  /// Handle quality updates from video service
  void _handleQualityUpdate(CallQualityData qualityData) {
    _qualityHistory.insert(0, qualityData);

    // Maintain history size limit
    if (_qualityHistory.length > _maxHistoryLength) {
      _qualityHistory.removeRange(_maxHistoryLength, _qualityHistory.length);
    }
  }

  /// Trigger adaptation based on connection type change
  void _triggerConnectionBasedAdaptation(
      ConnectivityResult previous, ConnectivityResult current) {
    String targetProfile = _currentVideoProfile;

    switch (current) {
      case ConnectivityResult.wifi:
        targetProfile = 'high';
        break;
      case ConnectivityResult.mobile:
        targetProfile = 'medium';
        break;
      case ConnectivityResult.ethernet:
        targetProfile = 'high';
        break;
      case ConnectivityResult.none:
        // Handle disconnection
        _alertController.add(QualityAlert(
          type: QualityAlertType.connectionLost,
          severity: AlertSeverity.error,
          message: 'Network connection lost',
        ));
        return;
      default:
        targetProfile = 'low';
    }

    if (targetProfile != _currentVideoProfile) {
      adaptVideoProfile(targetProfile);
    }
  }

  /// Calculate overall quality score (0-100)
  int _calculateQualityScore(int latency, double packetLoss) {
    int score = 100;

    // Latency penalty
    if (latency > 50) score -= min(40, (latency - 50) ~/ 5);

    // Packet loss penalty
    score -= (packetLoss * 1000).round();

    return max(0, min(100, score));
  }

  /// Get most frequent quality value
  String _getMostFrequentQuality(List<String> qualities) {
    if (qualities.isEmpty) return 'unknown';

    final Map<String, int> counts = {};
    for (final quality in qualities) {
      counts[quality] = (counts[quality] ?? 0) + 1;
    }

    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Get adaptation count from recent history
  int _getAdaptationCount() {
    // Placeholder for tracking adaptation events
    return 0;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopMonitoring();

    await _alertController.close();
    await _adaptationController.close();

    debugPrint('$_tag: ✅ Call quality monitoring disposed');
  }
}

/// Video profile configuration
class VideoProfile {
  final int width;
  final int height;
  final int frameRate;
  final int bitrate;
  final String name;

  const VideoProfile({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.bitrate,
    required this.name,
  });
}

/// Quality alert types
enum QualityAlertType {
  highLatency,
  highPacketLoss,
  poorNetworkQuality,
  connectivityChanged,
  connectionLost,
  bandwidthLimited,
}

/// Alert severity levels
enum AlertSeverity { info, warning, error }

/// Quality alert data
class QualityAlert {
  final QualityAlertType type;
  final AlertSeverity severity;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  QualityAlert({
    required this.type,
    required this.severity,
    required this.message,
    this.data,
  }) : timestamp = DateTime.now();
}

/// Adaptation event types
enum AdaptationEventType {
  videoProfileChanged,
  bitrateAdjusted,
  frameRateAdjusted,
  resolutionChanged,
}

/// Adaptation event data
class AdaptationEvent {
  final AdaptationEventType type;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  AdaptationEvent({
    required this.type,
    required this.message,
    this.data,
  }) : timestamp = DateTime.now();
}

/// Call quality statistics summary
class CallQualityStats {
  final int averageLatency;
  final double averagePacketLoss;
  final String networkQuality;
  final String connectionType;
  final String currentVideoProfile;
  final int qualityScore;
  final int adaptationCount;

  const CallQualityStats({
    required this.averageLatency,
    required this.averagePacketLoss,
    required this.networkQuality,
    required this.connectionType,
    required this.currentVideoProfile,
    required this.qualityScore,
    required this.adaptationCount,
  });

  static CallQualityStats empty() => const CallQualityStats(
        averageLatency: 0,
        averagePacketLoss: 0.0,
        networkQuality: 'unknown',
        connectionType: 'none',
        currentVideoProfile: 'medium',
        qualityScore: 0,
        adaptationCount: 0,
      );

  Map<String, dynamic> toJson() => {
        'averageLatency': averageLatency,
        'averagePacketLoss': averagePacketLoss,
        'networkQuality': networkQuality,
        'connectionType': connectionType,
        'currentVideoProfile': currentVideoProfile,
        'qualityScore': qualityScore,
        'adaptationCount': adaptationCount,
      };
}
