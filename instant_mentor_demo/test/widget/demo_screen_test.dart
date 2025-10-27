import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/main_simple.dart' as app;

void main() {
  testWidgets('DemoScreen navigation and widgets', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: app.MyApp()));

    // Verify initial tab label
    expect(find.text('Day 27: Offline Support'), findsOneWidget);

    // Tap on the BottomNavigationBar item 'Push Notifications' (index 2)
    await tester.tap(find.byIcon(Icons.notifications));
    await tester.pumpAndSettle();

    // Verify the Push Notifications screen content
    expect(find.text('Day 29: Push Notifications'), findsOneWidget);

    // Switch to Database Optimization (index 3)
    await tester.tap(find.byIcon(Icons.speed));
    await tester.pumpAndSettle();
    expect(find.text('Day 30: Database Optimization'), findsOneWidget);
  });
}
