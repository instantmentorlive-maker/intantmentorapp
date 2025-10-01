import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/core/providers/auth_provider.dart';
import 'package:instant_mentor_demo/core/providers/chat_providers.dart';
import 'package:instant_mentor_demo/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'packag      await tester.pumpWidget(

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication + Chat Happy Path Integration Tests', () {
    testWidgets('Complete auth + chat flow', (WidgetTester tester) async {
      // Override providers for testing
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Mock auth provider for testing
            // authProvider.overrideWith((ref) => MockAuthNotifier()),
          ],
        ),
      );

      // Wait for app to load
      await tester.pumpAndSettle();

      // Step 1: Login flow
      await _testLoginFlow(tester);

      // Step 2: Navigate to chat
      await _testNavigateToChat(tester);

      // Step 3: Send a message
      await _testSendMessage(tester);

      // Step 4: Verify message appears
      await _testVerifyMessage(tester);
    });

    testWidgets('Authentication error handling', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockAuthNotifierWithErrors()),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Test login with invalid credentials
      await _testInvalidLogin(tester);

      // Verify error message appears
      expect(find.textContaining('Authentication failed'), findsOneWidget);
    });

    testWidgets('Chat offline handling', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // authProvider.overrideWith((ref) => MockAuthNotifier()),
            // Mock offline chat provider
            // chatServiceProvider.overrideWith((ref) => MockOfflineChatService()),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Login first
      await _testLoginFlow(tester);

      // Navigate to chat
      await _testNavigateToChat(tester);

      // Try to send message while offline
      await _testSendMessageOffline(tester);

      // Verify offline indicator or retry mechanism
      expect(find.textContaining('Offline'), findsOneWidget);
    });
  });

  group('Video Call Integration Tests', () {
    testWidgets('Basic call join/leave flow', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // authProvider.overrideWith((ref) => MockAuthNotifier()),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Login first
      await _testLoginFlow(tester);

      // Navigate to video call
      await _testNavigateToVideoCall(tester);

      // Join call
      await _testJoinCall(tester);

      // Verify call UI elements
      await _testVerifyCallUI(tester);

      // Leave call
      await _testLeaveCall(tester);

      // Verify back to previous screen
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Call permissions handling', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Test permission request flow
      await _testCallPermissions(tester);
    });
  });
}

// Helper functions for test scenarios
Future<void> _testLoginFlow(WidgetTester tester) async {
  // Look for login button or email field
  final loginField = find.byType(TextField).first;
  if (loginField.evaluate().isNotEmpty) {
    await tester.enterText(loginField, 'test@example.com');
    await tester.pumpAndSettle();

    // Find password field
    final passwordField = find.byType(TextField).last;
    await tester.enterText(passwordField, 'password123');
    await tester.pumpAndSettle();

    // Tap login button
    final loginButton = find.widgetWithText(ElevatedButton, 'Login').first;
    await tester.tap(loginButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _testNavigateToChat(WidgetTester tester) async {
  // Look for chat tab or button
  final chatTab = find.text('Chat');
  if (chatTab.evaluate().isNotEmpty) {
    await tester.tap(chatTab);
    await tester.pumpAndSettle();
  }
}

Future<void> _testSendMessage(WidgetTester tester) async {
  // Find message input field
  final messageField = find.byType(TextField).last;
  await tester.enterText(messageField, 'Hello, this is a test message!');
  await tester.pumpAndSettle();

  // Find send button
  final sendButton = find.byIcon(Icons.send);
  if (sendButton.evaluate().isNotEmpty) {
    await tester.tap(sendButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _testVerifyMessage(WidgetTester tester) async {
  // Verify the message appears in the chat
  expect(find.textContaining('Hello, this is a test message!'), findsOneWidget);
}

Future<void> _testInvalidLogin(WidgetTester tester) async {
  final loginField = find.byType(TextField).first;
  await tester.enterText(loginField, 'invalid@example.com');
  await tester.pumpAndSettle();

  final passwordField = find.byType(TextField).last;
  await tester.enterText(passwordField, 'wrongpassword');
  await tester.pumpAndSettle();

  final loginButton = find.widgetWithText(ElevatedButton, 'Login');
  await tester.tap(loginButton);
  await tester.pumpAndSettle();
}

Future<void> _testSendMessageOffline(WidgetTester tester) async {
  final messageField = find.byType(TextField).last;
  await tester.enterText(messageField, 'Offline message test');
  await tester.pumpAndSettle();

  final sendButton = find.byIcon(Icons.send);
  await tester.tap(sendButton);
  await tester.pumpAndSettle();
}

Future<void> _testNavigateToVideoCall(WidgetTester tester) async {
  final videoButton = find.byIcon(Icons.videocam);
  if (videoButton.evaluate().isNotEmpty) {
    await tester.tap(videoButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _testJoinCall(WidgetTester tester) async {
  final joinButton = find.textContaining('Join');
  if (joinButton.evaluate().isNotEmpty) {
    await tester.tap(joinButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _testVerifyCallUI(WidgetTester tester) async {
  // Verify call controls are present
  expect(find.byIcon(Icons.mic), findsOneWidget);
  expect(find.byIcon(Icons.videocam), findsOneWidget);
  expect(find.byIcon(Icons.call_end), findsOneWidget);
}

Future<void> _testLeaveCall(WidgetTester tester) async {
  final endCallButton = find.byIcon(Icons.call_end);
  await tester.tap(endCallButton);
  await tester.pumpAndSettle();
}

Future<void> _testCallPermissions(WidgetTester tester) async {
  // This would test the permission request flow
  // In a real test, you'd mock the permission plugin
}

// Mock classes for testing
class MockAuthNotifier extends StateNotifier<AuthState> {
  MockAuthNotifier() : super(const AuthState());

  void mockLogin(String email, String password) {
    state = AuthState(
      isAuthenticated: true,
      user: MockUser(email: email),
    );
  }
}

class MockAuthNotifierWithErrors extends StateNotifier<AuthState> {
  MockAuthNotifierWithErrors() : super(const AuthState());

  void mockLogin(String email, String password) {
    state = const AuthState(
      error: 'Authentication failed',
    );
  }
}

class MockOfflineChatService {
  Future<void> sendMessage(String message) async {
    throw Exception('No internet connection');
  }
}

class MockUser {
  final String email;
  MockUser({required this.email});
}

class AuthState {
  final bool isAuthenticated;
  final MockUser? user;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.error,
  });
}
