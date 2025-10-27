import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/main_simple.dart' as app;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and navigates between tabs', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: app.MyApp()));
    await tester.pumpAndSettle();

    // Verify home screen
    expect(find.text('Day 27: Offline Support'), findsOneWidget);

    // Navigate to Push Notifications
    await tester.tap(find.byIcon(Icons.notifications));
    await tester.pumpAndSettle();
    expect(find.text('Day 29: Push Notifications'), findsOneWidget);

    // Navigate to Database Optimization
    await tester.tap(find.byIcon(Icons.speed));
    await tester.pumpAndSettle();
    expect(find.text('Day 30: Database Optimization'), findsOneWidget);
  });
}
