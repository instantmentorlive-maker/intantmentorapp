import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/core/providers/auth_provider.dart';
import 'package:instant_mentor_demo/features/auth/login/login_screen.dart';
// mocktail not needed for FakeAuthNotifier-based tests

// A tiny fake AuthNotifier that extends StateNotifier so it works with
// Riverpod's StateNotifierProvider in tests. We implement only the methods
// used by the LoginScreen tests.
class FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  FakeAuthNotifier(AuthState state) : super(state);

  @override
  Future<void> signIn(
      {required String email, required String password}) async {}

  @override
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Provide no-op implementations for other AuthNotifier methods referenced
  // by the app but not used in these tests.
  @override
  Future<void> signUp(
      {required String email,
      required String password,
      required String fullName,
      Map<String, dynamic>? additionalData}) async {}

  @override
  Future<void> signOut({bool forced = false}) async {}

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<void> setNewPassword(String newPassword) async {}

  @override
  Future<void> sendEmailOTP(String email,
      {bool shouldCreateUser = true}) async {}

  @override
  Future<void> verifyEmailOTP(
      {required String email, required String otp}) async {}

  @override
  Future<void> resendEmailOTP(String email) async {}

  @override
  Future<void> sendPhoneOTP(String phoneNumber) async {}

  @override
  Future<void> verifyPhoneOTP(
      {required String phone, required String otp}) async {}

  @override
  Future<void> resendPhoneOTP(String phoneNumber) async {}

  @override
  Future<void> updateProfile(Map<String, dynamic> profileData) async {}

  @override
  void clearNewMentorSignupFlag() {}

  @override
  void clearNewStudentSignupFlag() {}
}

void main() {
  group('LoginScreen', () {
    late FakeAuthNotifier fakeAuthNotifier;

    setUp(() {
      // default to no-error state
      fakeAuthNotifier = FakeAuthNotifier(const AuthState());
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
            // Provide the mock AuthNotifier instance as the StateNotifier for the provider
            authProvider.overrideWithProvider(
                StateNotifierProvider<AuthNotifier, AuthState>(
              (ref) => fakeAuthNotifier,
            )),
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
            authProvider.overrideWithProvider(
                StateNotifierProvider<AuthNotifier, AuthState>(
              (ref) => fakeAuthNotifier,
            )),
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
            authProvider.overrideWithProvider(
                StateNotifierProvider<AuthNotifier, AuthState>(
              (ref) => fakeAuthNotifier,
            )),
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
