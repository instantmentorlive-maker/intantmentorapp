# Test helpers — instant_mentor_demo/test/test_helpers

This file documents the shared test helpers used across unit and widget tests in this package and provides a full example.

Key helpers

- ensureTestDotenvLoaded()
  - Purpose: Ensure `flutter_dotenv` is loaded when running tests in the Dart VM and seed minimal env values required by app code (for example SUPABASE keys).
  - Usage: Call in test `setUp()` before building widgets or invoking code that reads `dotenv.env`.

- FakeAuthNotifier
  - Purpose: A lightweight `StateNotifier<AuthState>` used to avoid initializing Supabase in unit/widget tests. It provides the same public surface used by the UI (for example `clearError()`), but doesn't call network or platform code.
  - Usage: Create with `final fake = FakeAuthNotifier(const AuthState());` and pass to `providerOverridesForUnitTests(fake)`.

- providerOverridesForUnitTests(FakeAuthNotifier fake)
  - Purpose: Returns a `List<Override>` that overrides `authProvider` with the provided `FakeAuthNotifier` and any other common overrides we need in pure VM tests.
  - Usage: See the example below.

widgetTestProviderScope() vs providerOverridesForUnitTests(...)
- `providerOverridesForUnitTests(fake)` is the recommended pattern for unit/widget tests that only need to replace the `authProvider` with a fake notifier (no Supabase client required). It keeps tests lightweight and fast in the Dart VM.
- `widgetTestProviderScope(child: ...)` (implemented in `test/helpers/setup_test_helper.dart` as `widgetTestProviderScope`) is intended for widget tests that need a fake Supabase service implementation (for example, when a widget directly calls the Supabase service). It overrides `supabaseServiceProvider` with a `FakeSupabaseService` and also seeds `SharedPreferences`. Use this when the widget under test expects a Supabase-backed service instance.

Full example — using `providerOverridesForUnitTests`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/features/auth/login/login_screen.dart';
import '../../test_helpers/dotenv_test_setup.dart';

void main() {
  group('LoginScreen', () {
    late FakeAuthNotifier fakeAuthNotifier;

    setUp(() async {
      fakeAuthNotifier = FakeAuthNotifier(const AuthState());
      await ensureTestDotenvLoaded();
    });

    testWidgets('shows error when auth state has error', (tester) async {
      fakeAuthNotifier = FakeAuthNotifier(const AuthState(error: 'oops'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [...providerOverridesForUnitTests(fakeAuthNotifier)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      expect(find.text('oops'), findsOneWidget);
    });
  });
}
```

Full example — when to use `widgetTestProviderScope`

If your widget makes calls into the Supabase-backed service (for example, calls methods on `supabaseServiceProvider`) then use the higher-level provider scope helper that provides a `FakeSupabaseService` and sets up `SharedPreferences` mocks:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:instant_mentor_demo/test/helpers/setup_test_helper.dart';

void main() {
  testWidgets('widget that depends on Supabase service', (tester) async {
    await configureTestHarness(); // seeds dotenv + SharedPreferences

    await tester.pumpWidget(
      widgetTestProviderScope(child: const MyWidgetUnderTest()),
    );

    // assertions...
  });
}
```

Notes
- Do NOT call `SupabaseService.initialize()` or `Supabase.initialize()` from tests that run in the Dart VM — those initialization paths use platform plugins and will throw `MissingPluginException`.
- For true platform-integration behavior, write integration tests that run on device/emulator.

Where to look
- `test/test_helpers/dotenv_test_setup.dart` — implementation of the functions above.
- `test/helpers/setup_test_helper.dart` — higher-level helper and `widgetTestProviderScope` that overrides `supabaseServiceProvider`.

