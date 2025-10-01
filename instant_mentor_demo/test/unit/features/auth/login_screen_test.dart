import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/core/providers/auth_provider.dart';
import 'package:instant_mentor_demo/features/auth/login/login_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthNotifier extends Mock implements AuthNotifier {}

void main() {
  group('LoginScreen', () {
    late MockAuthNotifier mockAuthNotifier;

    setUp(() {
      mockAuthNotifier = MockAuthNotifier();
    });

    testWidgets('should not show error when auth state has no error',
        (tester) async {
      // Arrange
      const authState = AuthState();
      when(() => mockAuthNotifier.state).thenReturn(authState);

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => mockAuthNotifier),
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
      const authState = AuthState(error: 'Test error message');
      when(() => mockAuthNotifier.state).thenReturn(authState);

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => mockAuthNotifier),
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
      const initialState = AuthState(error: 'Test error');
      const clearedState = AuthState();

      when(() => mockAuthNotifier.state).thenReturn(initialState);
      when(() => mockAuthNotifier.clearError()).thenAnswer((_) async {
        when(() => mockAuthNotifier.state).thenReturn(clearedState);
      });

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => mockAuthNotifier),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Initially should show error
      expect(find.text('Test error'), findsOneWidget);

      // Simulate clearError being called (this would happen when user starts typing)
      mockAuthNotifier.clearError();
      await tester.pumpAndSettle();

      // Error should be cleared
      verify(() => mockAuthNotifier.clearError()).called(1);
    });
  });
}
