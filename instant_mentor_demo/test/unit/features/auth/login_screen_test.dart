import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/core/providers/auth_provider.dart';
import 'package:instant_mentor_demo/core/services/session_management_service.dart';
import '../../../test_helpers/dotenv_test_setup.dart';
import 'package:instant_mentor_demo/features/auth/login/login_screen.dart';
// mocktail not needed for FakeAuthNotifier-based tests

// Use shared FakeAuthNotifier and dotenv test setup from test_helpers

void main() {
  group('LoginScreen', () {
    late FakeAuthNotifier fakeAuthNotifier;

    setUp(() async {
      // default to no-error state
      fakeAuthNotifier = FakeAuthNotifier(const AuthState());

      // Centralized test dotenv + minimal seeding
      await ensureTestDotenvLoaded();
      // Do NOT call SupabaseService.initialize() in unit tests: it tries to
      // use platform plugins (e.g., shared_preferences) which are not
      // available in unit test environment and cause MissingPluginException.
    });

    testWidgets('should not show error when auth state has no error',
        (tester) async {
      // Arrange
      // Use a fake notifier with an empty/default state
      fakeAuthNotifier = FakeAuthNotifier(const AuthState());

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Use shared provider overrides for unit tests
            ...providerOverridesForUnitTests(fakeAuthNotifier),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Assert
      expect(find.byType(Container),
          findsNothing); // No error container should be visible
      expect(
          find.text(
              'Invalid email or password. Please check your credentials and try again.'),
          findsNothing);
    });

    testWidgets('should show error when auth state has error', (tester) async {
      // Arrange
      // Provide a notifier pre-populated with an error
      fakeAuthNotifier =
          FakeAuthNotifier(const AuthState(error: 'Test error message'));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...providerOverridesForUnitTests(fakeAuthNotifier),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Assert
      expect(find.text('Test error message'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('should clear error when clearError is called', (tester) async {
      // Arrange
      // Start with an initial state that contains an error
      fakeAuthNotifier = FakeAuthNotifier(const AuthState(error: 'Test error'));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...providerOverridesForUnitTests(fakeAuthNotifier),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Initially should show error
      expect(find.text('Test error'), findsOneWidget);

      // Simulate clearError being called (this would happen when user starts typing)
      fakeAuthNotifier.clearError();
      await tester.pumpAndSettle();

      // Verify the UI no longer shows the error text
      expect(find.text('Test error'), findsNothing);
    });
  });
}
