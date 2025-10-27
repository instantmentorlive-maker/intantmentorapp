// Test setup helper: seeds dotenv, configures SharedPreferences, and provides
// a convenient ProviderScope override for the Supabase service.

import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../test_helpers/dotenv_test_setup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/core/providers/auth_provider.dart'
    as auth_provider_show; // for supabaseServiceProvider symbol
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_supabase_service.dart';

/// Call before running widget tests to ensure env and SharedPreferences are available.
Future<void> configureTestHarness({Map<String, String>? env}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  // Provide minimal dotenv values used by AppConfig / SupabaseService
  // Use centralized dotenv loader/seeder to keep test setup consistent.
  await ensureTestDotenvLoaded();

  // Additional seeds specific to this helper (e.g., Stripe demo key)
  dotenv.env['STRIPE_PUBLISHABLE_KEY'] = env?['STRIPE_PUBLISHABLE_KEY'] ??
      dotenv.env['STRIPE_PUBLISHABLE_KEY'] ??
      'pk_test_demo_key_for_development';
}

/// Return a ProviderScope configured with the fake SupabaseService override.
ProviderScope widgetTestProviderScope({required Widget child}) {
  final fake = FakeSupabaseService();
  return ProviderScope(
    overrides: [
      // We cast to dynamic to avoid needing the production provider to be
      // refactored immediately; tests should eventually move to an interface.
      auth_provider_show.supabaseServiceProvider
          .overrideWithValue(fake as dynamic),
    ],
    child: child,
  );
}
