/// Centralized feature flags & runtime/build-time configuration.
/// Priority order (where applicable): --dart-define > dotenv > default.
/// Examples:
/// flutter run -d chrome --dart-define=REALTIME_ENABLED=true --dart-define=DEMO_MODE=true
/// flutter build web --release --dart-define=REALTIME_ENABLED=false --dart-define=DEMO_MODE=true
class FeatureFlags {
  // ------------ Compile-time (dart-define) flags ------------
  static const bool realtimeEnabled = bool.fromEnvironment(
    'REALTIME_ENABLED',
  );

  static const bool demoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: true,
  );

  static const String realtimeServerUrl = String.fromEnvironment(
    'REALTIME_SERVER_URL',
  );

  // Logging verbosity (none,error,warn,info,debug). Default: info
  static const String logLevel = String.fromEnvironment(
    'LOG_LEVEL',
    defaultValue: 'info',
  );

  // Development helper: automatically accept outgoing calls in real mode
  // (do not enable in production). Usage:
  // --dart-define=AUTO_ACCEPT_CALLS=true
  static const bool autoAcceptCalls = bool.fromEnvironment(
    'AUTO_ACCEPT_CALLS',
  );

  // ------------ Optional (dotenv) fallbacks ------------
  // If later we load dotenv, we can provide helper getters without requiring the package now.
  // (Keeping code lightweight: we do not import flutter_dotenv unless added to pubspec.)
  // Add implementation later if needed.
}
