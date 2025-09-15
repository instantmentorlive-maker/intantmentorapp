import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized feature flags sourced from environment variables.
///
/// All values default to safe/off if not provided.
class FeatureFlags {
  static bool get enableWebSocket => _asBool(dotenv.env['ENABLE_WEBSOCKET']);
  static bool get enableMfa => _asBool(dotenv.env['ENABLE_MFA']);
  static bool get enableBiometric => _asBool(dotenv.env['ENABLE_BIOMETRIC']);
  static bool get enableStripe => _asBool(dotenv.env['ENABLE_STRIPE']);
  static bool get stripeTestMode =>
      _asBool(dotenv.env['STRIPE_TEST_MODE'], defaultValue: true);

  static String get stripePublishableKey =>
      dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';

  static bool _asBool(String? v, {bool defaultValue = false}) {
    if (v == null) return defaultValue;
    switch (v.trim().toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
      case 'y':
      case 'on':
        return true;
      case '0':
      case 'false':
      case 'no':
      case 'n':
      case 'off':
        return false;
      default:
        return defaultValue;
    }
  }
}
