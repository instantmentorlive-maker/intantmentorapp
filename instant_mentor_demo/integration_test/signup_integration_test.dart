import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:instant_mentor_demo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Signup Integration Test', () {
    testWidgets('should allow user to signup successfully', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to signup screen
      final signupButton = find.text('Sign Up');
      expect(signupButton, findsOneWidget);
      await tester.tap(signupButton);
      await tester.pumpAndSettle();

      // Verify we're on the signup screen
      expect(find.text('Create Account'), findsOneWidget);

      // Fill out the signup form
      final nameField = find.byType(TextField).at(0);
      final emailField = find.byType(TextField).at(1);
      final passwordField = find.byType(TextField).at(2);

      await tester.enterText(nameField, 'Test User');
      await tester.enterText(emailField, 'test@student.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();

      // Select student role (should be default)
      final studentRadio = find.byKey(const Key('student_radio'));
      await tester.tap(studentRadio);
      await tester.pumpAndSettle();

      // Tap the create account button
      final createAccountButton = find.text('Create Account');
      expect(createAccountButton, findsOneWidget);
      await tester.tap(createAccountButton);
      await tester.pumpAndSettle();

      // Wait for signup to complete
      await tester.pump(const Duration(seconds: 2));

      // Check if we see success message or navigation
      // Since email confirmation is required, we should see a confirmation message
      final successMessage = find.textContaining('Please check your email');
      final emailConfirmationMessage = find.textContaining('confirmation');

      if (successMessage.evaluate().isNotEmpty ||
          emailConfirmationMessage.evaluate().isNotEmpty) {
        // Success - email confirmation required
        expect(true, true); // Test passes
      } else {
        // Check if we navigated to home screen (immediate authentication)
        final homeScreenIndicator = find.text('Home');
        if (homeScreenIndicator.evaluate().isNotEmpty) {
          expect(true, true); // Test passes
        } else {
          fail(
              'Signup did not complete successfully - no success message or navigation found');
        }
      }
    });

    testWidgets('should show validation errors for invalid form data',
        (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to signup screen
      final signupButton = find.text('Sign Up');
      expect(signupButton, findsOneWidget);
      await tester.tap(signupButton);
      await tester.pumpAndSettle();

      // Try to submit empty form
      final createAccountButton = find.text('Create Account');
      await tester.tap(createAccountButton);
      await tester.pumpAndSettle();

      // Should show validation errors
      expect(find.textContaining('required'), findsWidgets);
    });
  });
}
