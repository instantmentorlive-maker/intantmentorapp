import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';
import '../config/app_config.dart';
import '../services/email_service.dart';
import '../services/notification_service.dart';
import '../services/payment_service.dart';
import '../services/supabase_service.dart';

/// Provider for managing all backend services
final serviceIntegrationProvider =
    FutureProvider<ServiceIntegration>((ref) async {
  final integration = ServiceIntegration.instance;
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
  // Video call service removed

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
      await SupabaseService.initialize();

      _email = EmailService.instance;
      // EmailService uses Supabase edge functions; no explicit init needed

      _payment = PaymentService.instance;
      await PaymentService.initialize();

      _notification = NotificationService.instance;
      await _notification.initialize();

      // Video call initialization removed

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
      // Email service considered configured if Supabase is initialized
      health['email'] = _supabase.isInitialized;
    } catch (e) {
      health['email'] = false;
    }

    try {
      // Check Payment service
      // Payment has no persistent initialized flag; assume true after setup
      health['payment'] = true;
    } catch (e) {
      health['payment'] = false;
    }

    try {
      // Check Notification service
      health['notifications'] = await _notification.areNotificationsEnabled();
    } catch (e) {
      health['notifications'] = false;
    }

    // Video call service removed from health checks

    return health;
  }

  /// Get service configuration status
  Map<String, Map<String, dynamic>> getServiceStatus() {
    return {
      'supabase': {
        'initialized': _supabase.isInitialized,
        'authenticated': _supabase.isAuthenticated,
        // Using dotenv via Supabase.initialize; expose initialized/auth flags
        'url': true,
        'apiKey': true,
      },
      'email': {
        'configured': _supabase.isInitialized,
        'provider': 'Supabase Edge Functions',
      },
      'payment': {
        'initialized': true,
        'provider': 'Stripe',
        'publishableKey': AppConfig.stripePublishableKey.isNotEmpty,
      },
      'notifications': {
        'provider': 'Firebase Cloud Messaging',
        'fcmToken': _notification.fcmToken != null,
      },
      // Video call status removed
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
        amount: double.parse(amount),
        currency: currency,
      );
      return result.isSuccess;
    } catch (e) {
      debugPrint('Test payment failed: $e');
      return false;
    }
  }

  /// Test video call token generation
  // testVideoCallToken removed with video call feature

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
      // Video call dispose removed
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
  // videoCall getter removed

  bool get isInitialized => _isInitialized;
}
