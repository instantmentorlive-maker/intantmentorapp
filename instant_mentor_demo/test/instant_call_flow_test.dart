import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/features/payments/payment_checkout_sheet.dart';
import 'package:instant_mentor_demo/features/student/find_mentors/find_mentors_screen.dart';

void main() {
  group('Instant Call Flow Tests', () {
    testWidgets('Should show payment sheet when instant call is clicked',
        (WidgetTester tester) async {
      // Build the FindMentorsScreen wrapped in a ProviderScope and MaterialApp
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: FindMentorsScreen(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Look for an instant call button - it should be available for online mentors
      final instantCallButtons = find.text('Instant Call');

      // Verify that instant call buttons exist
      expect(instantCallButtons, findsAtLeast(1));

      // Tap the first instant call button
      await tester.tap(instantCallButtons.first);
      await tester.pumpAndSettle();

      // Verify that the payment checkout sheet appears
      expect(find.text('Confirm Instant Call Payment'), findsOneWidget);
      expect(find.text('Pay & Start'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Should proceed to video call after payment confirmation',
        (WidgetTester tester) async {
      // Build the FindMentorsScreen wrapped in a ProviderScope and MaterialApp
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const FindMentorsScreen(),
            // Mock navigation routes
            routes: {
              '/live-session': (context) => const Scaffold(
                    body: Center(child: Text('Live Session Started')),
                  ),
            },
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Find and tap an instant call button
      final instantCallButtons = find.text('Instant Call');
      expect(instantCallButtons, findsWidgets);

      await tester.tap(instantCallButtons.first);
      await tester.pumpAndSettle();

      // Verify payment sheet appears
      expect(find.text('Confirm Instant Call Payment'), findsOneWidget);

      // Tap the "Pay & Start" button
      await tester.tap(find.text('Pay & Start'));
      await tester.pumpAndSettle();

      // Verify processing dialog appears
      expect(find.text('Processing payment...'), findsOneWidget);

      // Wait for payment processing to complete
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify navigation to live session screen
      expect(find.text('Live Session Started'), findsOneWidget);
    });

    testWidgets('Should show payment details correctly',
        (WidgetTester tester) async {
      // Test the PaymentCheckoutSheet widget directly
      const testMentorName = 'Dr. Sarah Smith';
      const testHourlyRate = 55.0;
      const testMinutes = 30;
      const testAmount = 27.5; // (55/60) * 30

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

      // Verify payment details are displayed correctly
      expect(find.text('Mentor: $testMentorName'), findsOneWidget);
      expect(
          find.text('₹${testHourlyRate.toStringAsFixed(2)}'), findsOneWidget);
      expect(find.text(testMinutes.toString()), findsOneWidget);
      expect(find.text('₹${testAmount.toStringAsFixed(2)}'), findsWidgets);
    });
  });
}
