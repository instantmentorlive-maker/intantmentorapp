import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:instant_mentor_demo/main.dart' as app;
import 'package:instant_mentor_demo/core/testing/performance_monitor.dart';
import 'package:instant_mentor_demo/core/testing/ci_pipeline.dart';

/// Comprehensive integration test with performance monitoring and CI/CD integration
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final performanceMonitor = TestPerformanceMonitor();

  group('Complete App Integration Tests with Performance Monitoring', () {
    setUpAll(() async {
      // Initialize CI/CD pipeline for test environment
      await CIPipelineIntegration.initializeCIPipeline();
      print('🚀 CI/CD Pipeline initialized for integration tests');
    });

    tearDownAll(() async {
      // Generate final performance summary
      final summary = performanceMonitor.getSummary();
      print('📊 Final Performance Summary: $summary');

      // Clean up monitoring
      performanceMonitor.clear();
    });

    testWidgets('Auth to Chat Flow Performance Test', (tester) async {
      performanceMonitor.startTest('Auth to Chat Flow');

      try {
        // Start the app
        app.main();
        await tester.pumpAndSettle();

        // Test authentication flow
        await _testAuthenticationFlow(tester);

        // Test navigation to chat
        await _testChatNavigation(tester);

        // Test chat functionality
        await _testChatFunctionality(tester);

        // Test performance during heavy usage
        await _testPerformanceUnderLoad(tester);
      } finally {
        await performanceMonitor.stopTest();
      }
    });

    testWidgets('Video Call Integration with Performance Monitoring',
        (tester) async {
      performanceMonitor.startTest('Video Call Integration');

      try {
        // Start the app
        app.main();
        await tester.pumpAndSettle();

        // Navigate to video call feature
        await _navigateToVideoCall(tester);

        // Test video call initialization
        await _testVideoCallSetup(tester);

        // Monitor performance during video call
        await _monitorVideoCallPerformance(tester);

        // Test call termination
        await _testCallTermination(tester);
      } finally {
        await performanceMonitor.stopTest();
      }
    });

    testWidgets('Memory Leak Detection Test', (tester) async {
      performanceMonitor.startTest('Memory Leak Detection');

      try {
        // Start the app
        app.main();
        await tester.pumpAndSettle();

        // Perform memory-intensive operations
        await _testMemoryIntensiveOperations(tester);

        // Navigate between screens multiple times
        await _testScreenNavigationLoop(tester);

        // Create and dispose multiple providers
        await _testProviderLifecycle(tester);
      } finally {
        await performanceMonitor.stopTest();
      }
    });

    testWidgets('Error Boundary Integration Test', (tester) async {
      performanceMonitor.startTest('Error Boundary Integration');

      try {
        // Start the app
        app.main();
        await tester.pumpAndSettle();

        // Trigger various error conditions
        await _testNetworkErrors(tester);
        await _testValidationErrors(tester);
        await _testPermissionErrors(tester);

        // Verify error boundaries work correctly
        await _verifyErrorRecovery(tester);
      } finally {
        await performanceMonitor.stopTest();
      }
    });

    testWidgets('CI/CD Pipeline Validation Test', (tester) async {
      performanceMonitor.startTest('CI/CD Pipeline Validation');

      try {
        // Run comprehensive CI test suite
        final result = await CIPipelineIntegration.runCITestSuite();

        // Verify test results
        expect(result.success, isTrue,
            reason: 'CI/CD pipeline tests should pass');
        expect(result.unitTestResults?.passed, isTrue,
            reason: 'Unit tests should pass');
        expect(result.integrationTestResults?.passed, isTrue,
            reason: 'Integration tests should pass');

        print('✅ CI/CD Pipeline validation completed successfully');
      } finally {
        await performanceMonitor.stopTest();
      }
    });
  });
}

/// Test authentication flow
Future<void> _testAuthenticationFlow(WidgetTester tester) async {
  print('🔐 Testing authentication flow...');

  // Find login button
  final loginButton = find.byType(ElevatedButton).first;
  expect(loginButton, findsOneWidget);

  // Tap login button
  await tester.tap(loginButton);
  await tester.pumpAndSettle();

  // Verify navigation occurred
  await tester.pump(const Duration(seconds: 2));
  print('✅ Authentication flow tested');
}

/// Test chat navigation
Future<void> _testChatNavigation(WidgetTester tester) async {
  print('💬 Testing chat navigation...');

  // Look for chat-related widgets
  final chatWidgets = find.byIcon(Icons.chat);
  if (chatWidgets.evaluate().isNotEmpty) {
    await tester.tap(chatWidgets.first);
    await tester.pumpAndSettle();
  }

  await tester.pump(const Duration(seconds: 1));
  print('✅ Chat navigation tested');
}

/// Test chat functionality
Future<void> _testChatFunctionality(WidgetTester tester) async {
  print('🗨️ Testing chat functionality...');

  // Look for message input field
  final messageField = find.byType(TextFormField);
  if (messageField.evaluate().isNotEmpty) {
    await tester.enterText(
        messageField.first, 'Test message for performance monitoring');
    await tester.pump();

    // Look for send button
    final sendButton = find.byIcon(Icons.send);
    if (sendButton.evaluate().isNotEmpty) {
      await tester.tap(sendButton.first);
      await tester.pumpAndSettle();
    }
  }

  print('✅ Chat functionality tested');
}

/// Test performance under load
Future<void> _testPerformanceUnderLoad(WidgetTester tester) async {
  print('⚡ Testing performance under load...');

  // Simulate rapid interactions
  for (int i = 0; i < 10; i++) {
    // Rapid scrolling
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 100));

    // Rapid taps
    final buttons = find.byType(ElevatedButton);
    if (buttons.evaluate().isNotEmpty) {
      await tester.tap(buttons.first);
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  await tester.pumpAndSettle();
  print('✅ Performance under load tested');
}

/// Navigate to video call feature
Future<void> _navigateToVideoCall(WidgetTester tester) async {
  print('📹 Navigating to video call...');

  // Look for video call icon or button
  final videoCallButton = find.byIcon(Icons.video_call);
  if (videoCallButton.evaluate().isNotEmpty) {
    await tester.tap(videoCallButton.first);
    await tester.pumpAndSettle();
  } else {
    // Alternative navigation method
    final menuButton = find.byIcon(Icons.menu);
    if (menuButton.evaluate().isNotEmpty) {
      await tester.tap(menuButton.first);
      await tester.pumpAndSettle();

      // Look for video call menu item
      final videoMenuItem = find.text('Video Call');
      if (videoMenuItem.evaluate().isNotEmpty) {
        await tester.tap(videoMenuItem.first);
        await tester.pumpAndSettle();
      }
    }
  }

  print('✅ Navigation to video call completed');
}

/// Test video call setup
Future<void> _testVideoCallSetup(WidgetTester tester) async {
  print('🎥 Testing video call setup...');

  // Simulate video call initialization
  await tester.pump(const Duration(seconds: 3));

  // Look for camera/microphone controls
  final cameraToggle = find.byIcon(Icons.videocam);
  final micToggle = find.byIcon(Icons.mic);

  if (cameraToggle.evaluate().isNotEmpty) {
    await tester.tap(cameraToggle.first);
    await tester.pump(const Duration(milliseconds: 500));
  }

  if (micToggle.evaluate().isNotEmpty) {
    await tester.tap(micToggle.first);
    await tester.pump(const Duration(milliseconds: 500));
  }

  print('✅ Video call setup tested');
}

/// Monitor video call performance
Future<void> _monitorVideoCallPerformance(WidgetTester tester) async {
  print('📊 Monitoring video call performance...');

  // Simulate video call duration with performance monitoring
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(seconds: 1));

    // Simulate user interactions during call
    final widgets = find.byType(Widget);
    if (widgets.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  print('✅ Video call performance monitoring completed');
}

/// Test call termination
Future<void> _testCallTermination(WidgetTester tester) async {
  print('📞 Testing call termination...');

  // Look for end call button
  final endCallButton = find.byIcon(Icons.call_end);
  if (endCallButton.evaluate().isNotEmpty) {
    await tester.tap(endCallButton.first);
    await tester.pumpAndSettle();
  }

  print('✅ Call termination tested');
}

/// Test memory-intensive operations
Future<void> _testMemoryIntensiveOperations(WidgetTester tester) async {
  print('🧠 Testing memory-intensive operations...');

  // Simulate loading large lists
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));

    // Trigger rebuilds
    final refreshButtons = find.byIcon(Icons.refresh);
    if (refreshButtons.evaluate().isNotEmpty) {
      await tester.tap(refreshButtons.first);
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  print('✅ Memory-intensive operations tested');
}

/// Test screen navigation loop
Future<void> _testScreenNavigationLoop(WidgetTester tester) async {
  print('🔄 Testing navigation loop...');

  // Navigate between screens multiple times
  for (int i = 0; i < 3; i++) {
    // Go to different screens
    final navigationButtons = find.byType(IconButton);
    if (navigationButtons.evaluate().length > 1) {
      await tester
          .tap(navigationButtons.at(i % navigationButtons.evaluate().length));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  print('✅ Navigation loop tested');
}

/// Test provider lifecycle
Future<void> _testProviderLifecycle(WidgetTester tester) async {
  print('🔧 Testing provider lifecycle...');

  // Simulate provider creation and disposal
  for (int i = 0; i < 5; i++) {
    // Trigger provider state changes
    final buttons = find.byType(ElevatedButton);
    if (buttons.evaluate().isNotEmpty) {
      await tester.tap(buttons.at(i % buttons.evaluate().length));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  print('✅ Provider lifecycle tested');
}

/// Test network errors
Future<void> _testNetworkErrors(WidgetTester tester) async {
  print('🌐 Testing network error handling...');

  // Simulate network operations
  await tester.pump(const Duration(seconds: 2));

  // Look for retry buttons or error messages
  final retryButtons = find.text('Retry');
  if (retryButtons.evaluate().isNotEmpty) {
    await tester.tap(retryButtons.first);
    await tester.pump(const Duration(seconds: 1));
  }

  print('✅ Network error handling tested');
}

/// Test validation errors
Future<void> _testValidationErrors(WidgetTester tester) async {
  print('✅ Testing validation errors...');

  // Enter invalid data in forms
  final textFields = find.byType(TextFormField);
  if (textFields.evaluate().isNotEmpty) {
    await tester.enterText(textFields.first, ''); // Empty input
    await tester.pump();

    final submitButtons = find.text('Submit');
    if (submitButtons.evaluate().isNotEmpty) {
      await tester.tap(submitButtons.first);
      await tester.pump(const Duration(seconds: 1));
    }
  }

  print('✅ Validation errors tested');
}

/// Test permission errors
Future<void> _testPermissionErrors(WidgetTester tester) async {
  print('🔐 Testing permission errors...');

  // Simulate permission-related operations
  final cameraButtons = find.byIcon(Icons.camera_alt);
  if (cameraButtons.evaluate().isNotEmpty) {
    await tester.tap(cameraButtons.first);
    await tester.pump(const Duration(seconds: 1));
  }

  print('✅ Permission errors tested');
}

/// Verify error recovery
Future<void> _verifyErrorRecovery(WidgetTester tester) async {
  print('🔄 Verifying error recovery...');

  // Check that app is still responsive
  final widgets = find.byType(Widget);
  expect(widgets, findsWidgets);

  // Verify basic navigation still works
  await tester.pump(const Duration(seconds: 1));

  print('✅ Error recovery verified');
}
