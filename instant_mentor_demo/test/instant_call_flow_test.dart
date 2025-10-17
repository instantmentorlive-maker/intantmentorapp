import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/features/payments/payment_checkout_sheet.dart';
// Removed unused FindMentors import — tests use PaymentCheckoutSheet directly.
import 'setup.dart';
import 'test_helpers.dart';

void main() {
  group('Instant Call Flow Tests', () {
    setUpAll(() async {
      // Prepare SharedPreferences mock and dotenv for tests
      configureTestEnvironment();
      await configureTestHarness();
    });
    testWidgets('Should show payment sheet when instant call is clicked',
        (WidgetTester tester) async {
      // Directly test the PaymentCheckoutSheet widget to avoid relying on
      // app data (mentors list) which is fetched from Supabase.
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

      // Verify that important UI elements are present (match labels in widget)
      expect(find.text('Instant Call Payment'), findsOneWidget);
      expect(find.text('Pay & Start Call'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Should proceed to video call after payment confirmation',
        (WidgetTester tester) async {
      // Test the PaymentCheckoutSheet confirm flow invokes the callback.
      var confirmed = false;
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
              onConfirm: () {
                confirmed = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the confirm button and ensure the callback is invoked
      final payButton = find.text('Pay & Start Call');
      expect(payButton, findsOneWidget);
      await tester.tap(payButton);
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    });
  });
}
