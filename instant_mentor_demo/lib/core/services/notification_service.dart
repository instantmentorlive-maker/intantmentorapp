import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'supabase_service.dart';

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();

  NotificationService._();

  final SupabaseService _supabase = SupabaseService.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;

  /// Initialize notification service
  Future<void> initialize() async {
    await _initializeLocalNotifications();
    await _initializeFirebaseMessaging();
    await _requestPermissions();
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Initialize Firebase Cloud Messaging
  Future<void> _initializeFirebaseMessaging() async {
    try {
      // Get FCM token
      _fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM Token: $_fcmToken');

      // Save token to user profile
      if (_fcmToken != null && _supabase.isAuthenticated) {
        await _saveFcmToken(_fcmToken!);
      }

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _fcmToken = token;
        if (_supabase.isAuthenticated) {
          _saveFcmToken(token);
        }
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // Handle app opened from terminated state
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }
    } catch (e) {
      debugPrint('Firebase messaging initialization error: $e');
    }
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    try {
      // Request notification permission for iOS
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();

      // Request notification permission for Android
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }

      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      debugPrint('Permission request error: $e');
      return false;
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.messageId}');

    // Show local notification
    _showLocalNotification(
      title: message.notification?.title ?? 'InstantMentor',
      body: message.notification?.body ?? '',
      data: message.data,
    );
  }

  /// Handle background/terminated app messages
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('Background message: ${message.messageId}');

    // Handle navigation based on notification data
    final actionUrl = message.data['actionUrl'];

    if (actionUrl != null) {
      // Navigate to specific screen
      // This would typically use your app's navigation service
      debugPrint('Navigate to: $actionUrl');
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'instant_mentor_channel',
      'InstantMentor Notifications',
      channelDescription: 'Notifications for InstantMentor app',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: data?.toString(),
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');

    // Handle navigation based on payload
    // Implement your navigation logic here
  }

  /// Save FCM token to user profile
  Future<void> _saveFcmToken(String token) async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;

      await _supabase.updateData(
        table: 'user_profiles',
        data: {'fcm_token': token},
        column: 'id',
        value: userId,
      );
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  /// Send notification to user
  Future<bool> sendNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'info',
    Map<String, dynamic>? data,
    String? actionUrl,
  }) async {
    try {
      // Get user's FCM tokens
      final userTokens = await _getUserFcmTokens(userId);

      final response = await _supabase.client.functions.invoke(
        'send-notification',
        body: {
          'userId': userId,
          'title': title,
          'message': message,
          'type': type,
          'data': data,
          'actionUrl': actionUrl,
          'fcmTokens': userTokens,
        },
      );

      return response.data?['success'] == true;
    } catch (e) {
      debugPrint('Failed to send notification: $e');
      return false;
    }
  }

  /// Get user's FCM tokens
  Future<List<String>> _getUserFcmTokens(String userId) async {
    try {
      final response = await _supabase.fetchData(
        table: 'user_profiles',
        filters: {'id': userId},
      );

      if (response.isNotEmpty) {
        final fcmToken = response.first['fcm_token'];
        return fcmToken != null ? [fcmToken] : [];
      }

      return [];
    } catch (e) {
      debugPrint('Failed to get FCM tokens: $e');
      return [];
    }
  }

  /// Send session reminder notifications
  Future<void> sendSessionReminder({
    required String sessionId,
    required String mentorId,
    required String studentId,
    required DateTime sessionTime,
    required String subject,
  }) async {
    final timeUntilSession = sessionTime.difference(DateTime.now());
    final hoursUntil = timeUntilSession.inHours;

    if (hoursUntil <= 0) return; // Session already started or passed

    String reminderText;
    if (hoursUntil >= 24) {
      reminderText = 'Your session is tomorrow at ${_formatTime(sessionTime)}';
    } else if (hoursUntil >= 1) {
      reminderText =
          'Your session starts in $hoursUntil hour${hoursUntil > 1 ? 's' : ''}';
    } else {
      final minutesUntil = timeUntilSession.inMinutes;
      reminderText =
          'Your session starts in $minutesUntil minute${minutesUntil > 1 ? 's' : ''}';
    }

    // Send to both mentor and student
    await Future.wait([
      sendNotification(
        userId: mentorId,
        title: 'Session Reminder',
        message: '$reminderText - $subject',
        type: 'session',
        data: {'sessionId': sessionId, 'type': 'reminder'},
        actionUrl: '/session/$sessionId',
      ),
      sendNotification(
        userId: studentId,
        title: 'Session Reminder',
        message: '$reminderText - $subject',
        type: 'session',
        data: {'sessionId': sessionId, 'type': 'reminder'},
        actionUrl: '/session/$sessionId',
      ),
    ]);
  }

  /// Send session status notifications
  Future<void> sendSessionStatusNotification({
    required String sessionId,
    required String recipientId,
    required String status,
    required String subject,
  }) async {
    String title;
    String message;

    switch (status) {
      case 'confirmed':
        title = 'Session Confirmed';
        message = 'Your $subject session has been confirmed';
        break;
      case 'cancelled':
        title = 'Session Cancelled';
        message = 'Your $subject session has been cancelled';
        break;
      case 'completed':
        title = 'Session Completed';
        message =
            'Your $subject session has been completed. Please leave a review!';
        break;
      default:
        title = 'Session Update';
        message = 'Your $subject session status has been updated';
    }

    await sendNotification(
      userId: recipientId,
      title: title,
      message: message,
      type: 'session',
      data: {'sessionId': sessionId, 'status': status},
      actionUrl: '/session/$sessionId',
    );
  }

  /// Format time for display
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Get FCM token
  String? get fcmToken => _fcmToken;

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}
