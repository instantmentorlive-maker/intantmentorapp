import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration loaded from environment variables
class AppConfig {
  static late final AppConfig _instance;

  // Private constructor
  AppConfig._();

  /// Initialize configuration from environment
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    _instance = AppConfig._();
  }

  /// Get the singleton instance
  static AppConfig get instance => _instance;

  // API Configuration
  String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://api.instantmentor.com';
  String get apiVersion => dotenv.env['API_VERSION'] ?? 'v1';
  String get fullApiUrl => '$apiBaseUrl/$apiVersion';

  // Environment
  String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  bool get isProduction => environment == 'production';
  bool get isDevelopment => environment == 'development';
  bool get isStaging => environment == 'staging';
  bool get debugMode => dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';

  // Authentication
  String get jwtSecretKey => dotenv.env['JWT_SECRET_KEY'] ?? '';
  int get authTokenExpiry =>
      int.tryParse(dotenv.env['AUTH_TOKEN_EXPIRY'] ?? '') ?? 86400;
  int get refreshTokenExpiry =>
      int.tryParse(dotenv.env['REFRESH_TOKEN_EXPIRY'] ?? '') ?? 604800;

  // Feature Flags
  bool get enableBiometricAuth =>
      dotenv.env['ENABLE_BIOMETRIC_AUTH']?.toLowerCase() == 'true';
  bool get enableSocialLogin =>
      dotenv.env['ENABLE_SOCIAL_LOGIN']?.toLowerCase() == 'true';
  bool get enableOfflineMode =>
      dotenv.env['ENABLE_OFFLINE_MODE']?.toLowerCase() == 'true';

  // Network Configuration
  int get connectTimeout =>
      int.tryParse(dotenv.env['CONNECT_TIMEOUT'] ?? '') ?? 30000;
  int get receiveTimeout =>
      int.tryParse(dotenv.env['RECEIVE_TIMEOUT'] ?? '') ?? 30000;
  int get sendTimeout =>
      int.tryParse(dotenv.env['SEND_TIMEOUT'] ?? '') ?? 30000;

  // Logging
  String get logLevel => dotenv.env['LOG_LEVEL'] ?? 'info';
  bool get enableNetworkLogs =>
      dotenv.env['ENABLE_NETWORK_LOGS']?.toLowerCase() == 'true';

  // Video Calling
  static const String agoraAppId =
      String.fromEnvironment('AGORA_APP_ID', defaultValue: '');

  // Payment
  static const String stripePublishableKey =
      String.fromEnvironment('STRIPE_PUBLISHABLE_KEY', defaultValue: '');
  static const String stripeSecretKey =
      String.fromEnvironment('STRIPE_SECRET_KEY', defaultValue: '');

  // Notifications
  static const String fcmServerKey =
      String.fromEnvironment('FCM_SERVER_KEY', defaultValue: '');
  static const String fcmSenderId =
      String.fromEnvironment('FCM_SENDER_ID', defaultValue: '');

  // API Keys
  static const String openaiApiKey =
      String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
  static const String googleMapsApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');

  // Instance getters for environment variables
  String get agoraCertificate => dotenv.env['AGORA_CERTIFICATE'] ?? '';
  String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  // API Endpoints
  String get authEndpoint => '$fullApiUrl/auth';
  String get usersEndpoint => '$fullApiUrl/users';
  String get mentorsEndpoint => '$fullApiUrl/mentors';
  String get studentsEndpoint => '$fullApiUrl/students';
  String get sessionsEndpoint => '$fullApiUrl/sessions';

    // WebRTC ICE servers
    List<Map<String, dynamic>> get webrtcIceServers {
        final stun = dotenv.env['STUN_URL'] ?? 'stun:stun.l.google.com:19302';
        final turnUrl = dotenv.env['TURN_URL'];
        final turnUser = dotenv.env['TURN_USERNAME'];
        final turnPass = dotenv.env['TURN_PASSWORD'];

        final servers = <Map<String, dynamic>>[
            {
                'urls': [stun],
            },
        ];

        if (turnUrl != null && turnUrl.isNotEmpty) {
            servers.add({
                'urls': [turnUrl],
                if (turnUser != null) 'username': turnUser,
                if (turnPass != null) 'credential': turnPass,
            });
        }
        return servers;
    }
}
