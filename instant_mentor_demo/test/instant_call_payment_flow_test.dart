import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'setup.dart';
import 'test_helpers.dart';
import 'package:instant_mentor_demo/features/payments/payment_checkout_sheet.dart';
// Note: A full mock of PaymentService would require refactoring for DI.
// These tests focus on UI path up to payment confirmation sheet and callback.

void main() {
  group('Instant Call Payment Flow', () {
    setUpAll(() async {
      configureTestEnvironment();
      await configureTestHarness();
    });

    testWidgets('shows payment confirmation sheet for instant call flow',
        (tester) async {
      const testMentorName = 'Dr. Sarah Smith';
      const testHourlyRate = 55.0;
      const testMinutes = 30;
      const testAmount = 27.5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentCheckoutSheet(
              mentorName: testMentorName,
              hourlyRate: testHourlyRate,
              minutes: testMinutes,
              amount: testAmount,
              onConfirm: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Instant Call Payment'), findsOneWidget);
      // Simpler assertion: ensure the button label text is present.
      expect(find.text('Pay & Start Call'), findsOneWidget);
    });
  });
}
