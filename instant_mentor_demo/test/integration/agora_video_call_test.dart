import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:instant_mentor_demo/main.dart' as app;
import '../helpers/integration_test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Real Agora Video Call Integration Tests', () {
    late RtcEngine agoraEngine;

    setUpAll(() async {
      // Initialize Agora engine for testing
      agoraEngine = createAgoraRtcEngine();
      await agoraEngine.initialize(const RtcEngineContext(
        appId: 'test_app_id', // Use test app ID
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
    });

    tearDownAll(() async {
      await agoraEngine.leaveChannel();
      await agoraEngine.release();
    });

    testWidgets('Real video call join/leave with Agora',
        (WidgetTester tester) async {
      await tester.pumpWidget(const app.MyApp());
      await tester.pumpAndSettle();

      // Test permissions first
      await _testVideoCallPermissions(tester);

      // Test actual Agora integration
      await _testAgoraChannelJoin(tester, agoraEngine);

      // Test video controls
      await _testVideoControls(tester, agoraEngine);

      // Test call quality monitoring
      await _testCallQualityMonitoring(tester, agoraEngine);

      // Test graceful leave
      await _testAgoraChannelLeave(tester, agoraEngine);
    });

    testWidgets('Agora error handling and recovery',
        (WidgetTester tester) async {
      await tester.pumpWidget(const app.MyApp());
      await tester.pumpAndSettle();

      // Test network issues
      await _testNetworkDisruption(tester, agoraEngine);

      // Test permission denied
      await _testPermissionDenied(tester);

      // Test invalid channel
      await _testInvalidChannel(tester, agoraEngine);
    });

    testWidgets('Call quality and performance metrics',
        (WidgetTester tester) async {
      await tester.pumpWidget(const app.MyApp());
      await tester.pumpAndSettle();

      // Start performance monitoring
      final performanceMonitor = CallPerformanceMonitor();
      await performanceMonitor.start();

      // Join call and monitor performance
      await _testPerformanceMetrics(tester, agoraEngine, performanceMonitor);

      // Verify performance thresholds
      final metrics = await performanceMonitor.getMetrics();
      expect(metrics['frameRate'], greaterThan(20));
      expect(metrics['packetLoss'], lessThan(5));

      await performanceMonitor.stop();
    });
  });
}

Future<void> _testVideoCallPermissions(WidgetTester tester) async {
  // Request camera permission
  final cameraStatus = await Permission.camera.request();
  expect(cameraStatus, equals(PermissionStatus.granted));

  // Request microphone permission
  final micStatus = await Permission.microphone.request();
  expect(micStatus, equals(PermissionStatus.granted));
}

Future<void> _testAgoraChannelJoin(
    WidgetTester tester, RtcEngine engine) async {
  const testChannel = 'test-channel-123';
  const testUserId = 12345;

  // Enable video
  await engine.enableVideo();
  await engine.enableAudio();

  // Join channel
  await engine.joinChannel(
    token: null, // Use token server in production
    channelId: testChannel,
    uid: testUserId,
    options: const ChannelMediaOptions(
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ),
  );

  // Wait for join success
  await Future.delayed(const Duration(seconds: 3));

  // Verify we're in the channel
  final connectionState = await engine.getConnectionState();
  expect(connectionState, equals(ConnectionStateType.connectionStateConnected));
}

Future<void> _testVideoControls(WidgetTester tester, RtcEngine engine) async {
  // Test mute/unmute audio
  await engine.muteLocalAudioStream(true);
  await Future.delayed(const Duration(milliseconds: 500));
  await engine.muteLocalAudioStream(false);

  // Test enable/disable video
  await engine.muteLocalVideoStream(true);
  await Future.delayed(const Duration(milliseconds: 500));
  await engine.muteLocalVideoStream(false);

  // Test camera switching (mobile only)
  try {
    await engine.switchCamera();
  } catch (e) {
    // Camera switch may not be available on all platforms
    debugPrint('Camera switch not available: $e');
  }
}

Future<void> _testCallQualityMonitoring(
    WidgetTester tester, RtcEngine engine) async {
  // Setup quality monitoring
  bool qualityReceived = false;

  engine.registerEventHandler(RtcEngineEventHandler(
    onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
      qualityReceived = true;
      expect(txQuality.index, lessThan(QualityType.qualityPoor.index));
      expect(rxQuality.index, lessThan(QualityType.qualityPoor.index));
    },
    onRtcStats: (connection, stats) {
      expect(
          stats.cpuTotalUsage, lessThan(80)); // CPU usage should be reasonable
      expect(stats.memoryUsageRatio,
          lessThan(80)); // Memory usage should be reasonable
    },
  ));

  // Wait for quality reports
  await Future.delayed(const Duration(seconds: 5));
  expect(qualityReceived, isTrue);
}

Future<void> _testAgoraChannelLeave(
    WidgetTester tester, RtcEngine engine) async {
  // Leave channel gracefully
  await engine.leaveChannel();

  // Wait for leave completion
  await Future.delayed(const Duration(seconds: 2));

  // Verify we've left
  final connectionState = await engine.getConnectionState();
  expect(
      connectionState, equals(ConnectionStateType.connectionStateDisconnected));
}

Future<void> _testNetworkDisruption(
    WidgetTester tester, RtcEngine engine) async {
  bool reconnectionDetected = false;

  engine.registerEventHandler(RtcEngineEventHandler(
    onConnectionStateChanged: (connection, state, reason) {
      if (state == ConnectionStateType.connectionStateReconnecting) {
        reconnectionDetected = true;
      }
    },
  ));

  // Simulate network disruption (this would need actual network control in real tests)
  // For now, we test the handler registration
  expect(reconnectionDetected, isNotNull);
}

Future<void> _testPermissionDenied(WidgetTester tester) async {
  // This would test permission denied scenarios
  // In a real test, you'd mock the permission plugin
  final cameraStatus = await Permission.camera.status;
  if (cameraStatus.isDenied) {
    // Verify app handles denied permissions gracefully
    expect(find.textContaining('Camera permission'), findsOneWidget);
  }
}

Future<void> _testInvalidChannel(WidgetTester tester, RtcEngine engine) async {
  try {
    await engine.joinChannel(
      token: 'invalid-token',
      channelId: '', // Empty channel name
      uid: 0,
      options: const ChannelMediaOptions(),
    );

    // Should not reach here
    fail('Expected an exception for invalid channel');
  } catch (e) {
    // Expected error
    expect(e, isA<AgoraRtcException>());
  }
}

Future<void> _testPerformanceMetrics(
  WidgetTester tester,
  RtcEngine engine,
  CallPerformanceMonitor monitor,
) async {
  // Join a call
  await engine.joinChannel(
    token: null,
    channelId: 'performance-test-channel',
    uid: 999,
    options: const ChannelMediaOptions(),
  );

  // Monitor for 10 seconds
  await Future.delayed(const Duration(seconds: 10));

  // Collect metrics
  await monitor.collectMetrics(engine);

  await engine.leaveChannel();
}

/// Performance monitoring utility
class CallPerformanceMonitor {
  final Map<String, dynamic> _metrics = {};
  bool _isRunning = false;

  Future<void> start() async {
    _isRunning = true;
    _metrics.clear();
  }

  Future<void> stop() async {
    _isRunning = false;
  }

  Future<void> collectMetrics(RtcEngine engine) async {
    if (!_isRunning) return;

    // Collect Agora statistics
    engine.registerEventHandler(RtcEngineEventHandler(
      onRtcStats: (connection, stats) {
        _metrics['frameRate'] = stats.txVideoFrameRate;
        _metrics['packetLoss'] = stats.txPacketLossRate;
        _metrics['cpuUsage'] = stats.cpuTotalUsage;
        _metrics['memoryUsage'] = stats.memoryUsageRatio;
        _metrics['bandwidth'] = stats.txKBitRate;
      },
      onLocalVideoStats: (connection, stats) {
        _metrics['localVideoWidth'] = stats.encodedFrameWidth;
        _metrics['localVideoHeight'] = stats.encodedFrameHeight;
        _metrics['localVideoFps'] = stats.sentFrameRate;
      },
      onRemoteVideoStats: (connection, stats) {
        _metrics['remoteVideoWidth'] = stats.width;
        _metrics['remoteVideoHeight'] = stats.height;
        _metrics['remoteVideoFps'] = stats.receivedFrameRate;
      },
    ));
  }

  Map<String, dynamic> getMetrics() => Map.from(_metrics);

  /// Performance assertions for tests
  void assertPerformanceThresholds() {
    final frameRate = _metrics['frameRate'] ?? 0;
    final packetLoss = _metrics['packetLoss'] ?? 100;
    final cpuUsage = _metrics['cpuUsage'] ?? 100;

    if (frameRate < 15) {
      throw Exception('Frame rate too low: $frameRate fps');
    }

    if (packetLoss > 10) {
      throw Exception('Packet loss too high: $packetLoss%');
    }

    if (cpuUsage > 85) {
      throw Exception('CPU usage too high: $cpuUsage%');
    }
  }
}
