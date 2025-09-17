import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../lib/examples/video_call_example.dart';
import '../lib/features/call/controllers/simple_call_controller.dart';
import '../lib/features/call/models/call_state.dart';
import '../lib/features/call/services/call_notification_service.dart';

/// Comprehensive end-to-end test for video calling system
/// This test validates the complete call flow from initiation to termination
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Video Calling End-to-End Tests', () {
    testWidgets('Complete video call flow - outgoing call',
        (WidgetTester tester) async {
      // Create a test app with providers
      final app = ProviderScope(
        child: MaterialApp(
          home: const VideoCallExample(),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.text('No active call'), findsOneWidget);
      expect(find.text('Start Video Call'), findsOneWidget);

      // Step 1: Start a video call
      await tester.tap(find.text('Start Video Call'));
      await tester.pumpAndSettle();

      // Wait for call initialization
      await tester.pump(const Duration(seconds: 1));

      // Verify call has started
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoCallExample)),
      );
      final callData = container.read(simpleCallControllerProvider);

      expect(callData, isNotNull);
      expect(callData!.state, equals(CallState.calling));
      expect(callData.isVideoCall, isTrue);

      // Step 2: Navigate to outgoing call screen
      expect(find.byType(OutgoingCallScreen), findsOneWidget);

      // Verify outgoing call UI elements
      expect(find.text('Calling...'), findsOneWidget);
      expect(find.byIcon(Icons.call_end), findsOneWidget);

      print('✅ Outgoing call initiated successfully');

      // Step 3: Simulate call being answered (in real scenario, this would come from signaling)
      final controller = container.read(simpleCallControllerProvider.notifier);
      // Note: In a real test, you would need to mock the signaling service
      // to simulate receiving an answer from the remote peer

      // Step 4: Test call controls
      await tester.tap(find.byIcon(Icons.call_end));
      await tester.pumpAndSettle();

      // Verify call ended
      final updatedCallData = container.read(simpleCallControllerProvider);
      expect(updatedCallData?.state, equals(CallState.ended));

      print('✅ Call ended successfully');
    });

    testWidgets('Audio call flow test', (WidgetTester tester) async {
      final app = ProviderScope(
        child: MaterialApp(
          home: const VideoCallExample(),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Start an audio call
      await tester.tap(find.text('Start Audio Call'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoCallExample)),
      );
      final callData = container.read(simpleCallControllerProvider);

      expect(callData, isNotNull);
      expect(callData!.isVideoCall, isFalse);

      print('✅ Audio call initiated successfully');
    });

    testWidgets('Call notification service test', (WidgetTester tester) async {
      final app = ProviderScope(
        child: MaterialApp(
          home: const VideoCallExample(),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoCallExample)),
      );

      // Test notification service initialization
      final notificationService =
          container.read(callNotificationServiceProvider);
      expect(notificationService, isNotNull);

      print('✅ Notification service initialized successfully');
    });

    testWidgets('Call screen navigation test', (WidgetTester tester) async {
      final app = ProviderScope(
        child: MaterialApp(
          home: const VideoCallExample(),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Test navigation to incoming call screen
      await tester.tap(find.text('View Incoming Call Screen'));
      await tester.pumpAndSettle();

      expect(find.byType(IncomingCallScreen), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      // Go back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Test navigation to outgoing call screen
      await tester.tap(find.text('View Outgoing Call Screen'));
      await tester.pumpAndSettle();

      expect(find.byType(OutgoingCallScreen), findsOneWidget);

      // Go back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Test navigation to active call screen
      await tester.tap(find.text('View Active Call Screen'));
      await tester.pumpAndSettle();

      expect(find.byType(ActiveCallScreen), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.videocam), findsOneWidget);

      print('✅ All call screens accessible and functional');
    });

    testWidgets('Call state transitions test', (WidgetTester tester) async {
      final app = ProviderScope(
        child: MaterialApp(
          home: const VideoCallExample(),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoCallExample)),
      );

      // Start a call and verify state transitions
      await tester.tap(find.text('Start Video Call'));
      await tester.pumpAndSettle();

      var callData = container.read(simpleCallControllerProvider);
      expect(callData!.state, equals(CallState.calling));

      // Test media controls (these should work even in demo mode)
      final controller = container.read(simpleCallControllerProvider.notifier);

      // Test toggle audio
      await controller.toggleAudio();
      await tester.pump();

      callData = container.read(simpleCallControllerProvider);
      // Note: In demo mode, this might not change the actual media state
      // but the method should execute without errors

      // Test toggle video
      await controller.toggleVideo();
      await tester.pump();

      // End the call
      await controller.endCall();
      await tester.pump();

      callData = container.read(simpleCallControllerProvider);
      expect(callData?.state, equals(CallState.ended));

      print('✅ Call state transitions working correctly');
    });

    testWidgets('Error handling test', (WidgetTester tester) async {
      final app = ProviderScope(
        child: MaterialApp(
          home: const VideoCallExample(),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoCallExample)),
      );

      final controller = container.read(simpleCallControllerProvider.notifier);

      // Test trying to accept a call when there's no incoming call
      try {
        await controller.acceptCall();
        // Should throw an exception
        fail('Expected CallException to be thrown');
      } catch (e) {
        expect(e.toString(), contains('No incoming call to accept'));
        print('✅ Error handling working correctly');
      }
    });

    testWidgets('WebRTC media streams test', (WidgetTester tester) async {
      final app = ProviderScope(
        child: MaterialApp(
          home: const VideoCallExample(),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoCallExample)),
      );

      final controller = container.read(simpleCallControllerProvider.notifier);

      // Test that the controller has media stream getters
      expect(controller.localStream, isNull); // Should be null initially
      expect(controller.remoteStream, isNull); // Should be null initially

      // Test stream controllers
      expect(controller.localStreamStream, isNotNull);
      expect(controller.remoteStreamStream, isNotNull);

      print('✅ WebRTC media stream interfaces working');
    });
  });

  group('Performance Tests', () {
    testWidgets('Call initiation performance', (WidgetTester tester) async {
      final app = ProviderScope(
        child: MaterialApp(
          home: const VideoCallExample(),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final stopwatch = Stopwatch()..start();

      // Start a call and measure time
      await tester.tap(find.text('Start Video Call'));
      await tester.pumpAndSettle();

      stopwatch.stop();

      // Call initiation should be reasonably fast (under 2 seconds)
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));

      print(
          '✅ Call initiation completed in ${stopwatch.elapsedMilliseconds}ms');
    });

    testWidgets('UI responsiveness test', (WidgetTester tester) async {
      final app = ProviderScope(
        child: MaterialApp(
          home: const VideoCallExample(),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Rapidly navigate between screens
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('View Incoming Call Screen'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
      }

      print('✅ UI remains responsive during rapid navigation');
    });
  });
}

/// Helper class for test utilities
class CallTestUtils {
  /// Create a mock call data for testing
  static CallData createMockCallData({
    bool isVideoCall = true,
    bool isIncoming = false,
    CallState state = CallState.ringing,
  }) {
    if (isIncoming) {
      return CallData.incoming(
        callerId: 'test-caller',
        callerName: 'Test Caller',
        calleeId: 'test-callee',
        calleeName: 'Test Callee',
      ).copyWith(state: state);
    } else {
      return CallData.outgoing(
        callerId: 'test-caller',
        callerName: 'Test Caller',
        calleeId: 'test-callee',
        calleeName: 'Test Callee',
      ).copyWith(state: state);
    }
  }

  /// Simulate a complete call flow
  static Future<void> simulateCallFlow(
    WidgetTester tester,
    SimpleCallController controller,
  ) async {
    // Start call
    await controller.startCall(
      currentUserId: 'user1',
      targetUserId: 'user2',
      targetUserName: 'Test User',
      currentUserName: 'Current User',
      isVideoCall: true,
    );

    await tester.pump();

    // Simulate answer (in real scenario, this would come from signaling)
    // await controller.acceptCall();
    // await tester.pump();

    // End call
    await controller.endCall();
    await tester.pump();
  }
}

/// Test configuration for different scenarios
class CallTestConfig {
  static const Duration callTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const int maxRetries = 3;
}
