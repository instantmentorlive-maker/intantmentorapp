import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import the live session screen
import 'package:instant_mentor_demo/features/shared/live_session/live_session_screen.dart';
// Note: A full mock of PaymentService would require refactoring for DI.
// This test focuses on UI path up to payment confirmation sheet appearance.

void main() {
  group('Instant Call Payment Flow', () {
    testWidgets('shows payment confirmation sheet for instant call flow',
        (tester) async {
      // We mount the LiveSessionScreen without a sessionId to force instant flow.
      await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: LiveSessionScreen())));

      // Find the Instant Call button
      final instantCallBtn =
          find.widgetWithText(ElevatedButton, 'Instant Call');
      expect(instantCallBtn, findsOneWidget);

      // Tap the button
      await tester.tap(instantCallBtn);
      await tester.pumpAndSettle();

      // Expect the bottom sheet confirmation
      expect(find.text('Confirm Instant Call Payment'), findsOneWidget);

      // Presence of the Pay & Start button indicates we reached payment step.
      expect(
          find.widgetWithText(ElevatedButton, 'Pay & Start'), findsOneWidget);
    });
  });
}
