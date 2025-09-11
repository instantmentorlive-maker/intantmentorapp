import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import '../config/app_config.dart';
import '../services/supabase_service.dart';
import '../services/email_service.dart';
import '../services/payment_service.dart';
import '../services/notification_service.dart';
import '../services/video_call_service.dart';
import '../../firebase_options.dart';

/// Provider for managing all backend services
final serviceIntegrationProvider =
    FutureProvider<ServiceIntegration>((ref) async {
  final integration = ServiceIntegration();
  await integration.initialize();
  return integration;
});

/// Service integration manager
class ServiceIntegration {
  static ServiceIntegration? _instance;
  static ServiceIntegration get instance =>
      _instance ??= ServiceIntegration._();

  ServiceIntegration._();

  bool _isInitialized = false;

  // Service instances
  late final SupabaseService _supabase;
  late final EmailService _email;
  late final PaymentService _payment;
  late final NotificationService _notification;
  late final VideoCallService _videoCall;

  /// Initialize all services
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing service integration...');

      // Initialize app configuration
      await AppConfig.initialize();

      // Initialize Firebase
      await _initializeFirebase();

      // Initialize services in order
      _supabase = SupabaseService.instance;
      await _supabase.initialize();

      _email = EmailService.instance;
      await _email.initialize();

      _payment = PaymentService.instance;
      await _payment.initialize();

      _notification = NotificationService.instance;
      await _notification.initialize();

      _videoCall = VideoCallService.instance;
      await _videoCall.initialize();

      _isInitialized = true;
      debugPrint('Service integration initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize service integration: $e');
      rethrow;
    }
  }

  /// Initialize Firebase for push notifications
  Future<void> _initializeFirebase() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Firebase.initializeApp(options: FirebaseConfig.android);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Firebase.initializeApp(options: FirebaseConfig.ios);
      } else if (kIsWeb) {
        await Firebase.initializeApp(options: FirebaseConfig.web);
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        await Firebase.initializeApp(options: FirebaseConfig.windows);
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        await Firebase.initializeApp(options: FirebaseConfig.macos);
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        await Firebase.initializeApp(options: FirebaseConfig.linux);
      }

      debugPrint('Firebase initialized for ${defaultTargetPlatform.name}');
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
      // Continue without Firebase for now
    }
  }

  /// Check service health
  Future<Map<String, bool>> checkServiceHealth() async {
    final health = <String, bool>{};

    try {
      // Check Supabase
      health['supabase'] = await _supabase.healthCheck();
    } catch (e) {
      health['supabase'] = false;
    }

    try {
      // Check Email service
      health['email'] = _email.isConfigured;
    } catch (e) {
      health['email'] = false;
    }

    try {
      // Check Payment service
      health['payment'] = _payment.isInitialized;
    } catch (e) {
      health['payment'] = false;
    }

    try {
      // Check Notification service
      health['notifications'] = await _notification.areNotificationsEnabled();
    } catch (e) {
      health['notifications'] = false;
    }

    try {
      // Check Video call service
      health['videoCall'] = _videoCall.isInitialized;
    } catch (e) {
      health['videoCall'] = false;
    }

    return health;
  }

  /// Get service configuration status
  Map<String, Map<String, dynamic>> getServiceStatus() {
    return {
      'supabase': {
        'initialized': _supabase.isInitialized,
        'authenticated': _supabase.isAuthenticated,
        'url': _supabase.supabaseUrl.isNotEmpty,
        'apiKey': _supabase.supabaseKey.isNotEmpty,
      },
      'email': {
        'configured': _email.isConfigured,
        'provider': 'Supabase Edge Functions',
      },
      'payment': {
        'initialized': _payment.isInitialized,
        'provider': 'Stripe',
        'publishableKey': AppConfig.stripePublishableKey.isNotEmpty,
      },
      'notifications': {
        'provider': 'Firebase Cloud Messaging',
        'fcmToken': _notification.fcmToken != null,
      },
      'videoCall': {
        'initialized': _videoCall.isInitialized,
        'provider': 'Agora',
        'appId': AppConfig.agoraAppId.isNotEmpty,
      },
    };
  }

  /// Send comprehensive test notification
  Future<bool> sendTestNotification(String userId) async {
    return await _notification.sendNotification(
      userId: userId,
      title: 'Service Test',
      message: 'All InstantMentor services are working correctly!',
      type: 'test',
      data: {'timestamp': DateTime.now().toIso8601String()},
    );
  }

  /// Process test payment
  Future<bool> processTestPayment({
    required String amount,
    required String currency,
    required String description,
  }) async {
    try {
      final result = await _payment.processSessionPayment(
        sessionId: 'test_session',
        amount: int.parse(amount),
        currency: currency,
        customerEmail: 'test@example.com',
        description: description,
      );
      return result != null;
    } catch (e) {
      debugPrint('Test payment failed: $e');
      return false;
    }
  }

  /// Test video call token generation
  Future<bool> testVideoCallToken({
    required String channelId,
    required int uid,
  }) async {
    try {
      final token = await _videoCall._generateToken(channelId, uid);
      return token != null && token.isNotEmpty;
    } catch (e) {
      debugPrint('Video call token test failed: $e');
      return false;
    }
  }

  /// Send test email
  Future<bool> sendTestEmail({
    required String to,
    required String subject,
    required String message,
  }) async {
    return await _email.sendEmail(
      to: to,
      subject: subject,
      htmlContent: '''
        <h1>Test Email</h1>
        <p>$message</p>
        <p>This is a test email from InstantMentor services.</p>
        <p>Timestamp: ${DateTime.now()}</p>
      ''',
    );
  }

  /// Dispose all services
  Future<void> dispose() async {
    try {
      await _videoCall.dispose();
      // Other services don't need explicit disposal
      _isInitialized = false;
      debugPrint('Service integration disposed');
    } catch (e) {
      debugPrint('Error disposing service integration: $e');
    }
  }

  // Service getters
  SupabaseService get supabase => _supabase;
  EmailService get email => _email;
  PaymentService get payment => _payment;
  NotificationService get notification => _notification;
  VideoCallService get videoCall => _videoCall;

  bool get isInitialized => _isInitialized;
}
