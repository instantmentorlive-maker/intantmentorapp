// Shared test helpers for widget/unit tests
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Call this from your test files or a global setUpAll to prepare the test env.
void configureTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Ensure SharedPreferences uses an in-memory mock
  SharedPreferences.setMockInitialValues({});

  // Register fallback values for mocktail if any are needed by mocks
  // Example: registerFallbackValue(FakeX());
}

/// Simple convenience to delay for async persistence flushes during tests.
Future<void> flushAsync() async =>
    await Future.delayed(const Duration(milliseconds: 100));
