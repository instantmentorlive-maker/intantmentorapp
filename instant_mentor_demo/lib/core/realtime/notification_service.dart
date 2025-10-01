import 'dart:async';
import 'dart:developer' as developer;
import 'socketio_client.dart';

/// Notification types
enum NotificationType {
  message,
  mention,
  assignment,
  deadline,
  system,
  achievement,
  reminder,
  alert,
}

/// Notification priority levels
enum NotificationPriority {
  low,
  normal,
  high,
  critical,
}

/// Real-time notification model
class RealtimeNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationPriority priority;
  final String? userId;
  final String? groupId;
  final Map<String, dynamic>? data;
  final String? imageUrl;
  final String? actionUrl;
  final DateTime timestamp;
  final DateTime? expiresAt;
  final bool isRead;
  final bool isMuted;

  const RealtimeNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.priority = NotificationPriority.normal,
    this.userId,
    this.groupId,
    this.data,
    this.imageUrl,
    this.actionUrl,
    required this.timestamp,
    this.expiresAt,
    this.isRead = false,
    this.isMuted = false,
  });

  RealtimeNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    NotificationPriority? priority,
    String? userId,
    String? groupId,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? actionUrl,
    DateTime? timestamp,
    DateTime? expiresAt,
    bool? isRead,
    bool? isMuted,
  }) {
    return RealtimeNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      data: data ?? this.data,
      imageUrl: imageUrl ?? this.imageUrl,
      actionUrl: actionUrl ?? this.actionUrl,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      isRead: isRead ?? this.isRead,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'type': type.name,
      'priority': priority.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'isMuted': isMuted,
    };

    if (userId != null) {
      json['userId'] = userId;
    }

    if (groupId != null) {
      json['groupId'] = groupId;
    }

    if (data != null) {
      json['data'] = data;
    }

    if (imageUrl != null) {
      json['imageUrl'] = imageUrl;
    }

    if (actionUrl != null) {
      json['actionUrl'] = actionUrl;
    }

    if (expiresAt != null) {
      json['expiresAt'] = expiresAt!.toIso8601String();
    }

    return json;
  }

  factory RealtimeNotification.fromJson(Map<String, dynamic> json) {
    return RealtimeNotification(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      userId: json['userId'],
      groupId: json['groupId'],
      data: json['data'],
      imageUrl: json['imageUrl'],
      actionUrl: json['actionUrl'],
      timestamp: DateTime.parse(json['timestamp']),
      expiresAt:
          json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      isRead: json['isRead'] ?? false,
      isMuted: json['isMuted'] ?? false,
    );
  }
}

/// Notification preferences
class NotificationPreferences {
  final bool enablePush;
  final bool enableInApp;
  final bool enableEmail;
  final bool enableSms;
  final Map<NotificationType, bool> typePreferences;
  final Map<NotificationPriority, bool> priorityPreferences;
  final List<String> mutedUsers;
  final List<String> mutedGroups;
  final Duration quietHoursStart;
  final Duration quietHoursEnd;

  const NotificationPreferences({
    this.enablePush = true,
    this.enableInApp = true,
    this.enableEmail = false,
    this.enableSms = false,
    this.typePreferences = const {},
    this.priorityPreferences = const {},
    this.mutedUsers = const [],
    this.mutedGroups = const [],
    this.quietHoursStart = const Duration(hours: 22),
    this.quietHoursEnd = const Duration(hours: 8),
  });

  Map<String, dynamic> toJson() {
    return {
      'enablePush': enablePush,
      'enableInApp': enableInApp,
      'enableEmail': enableEmail,
      'enableSms': enableSms,
      'typePreferences': typePreferences.map((k, v) => MapEntry(k.name, v)),
      'priorityPreferences':
          priorityPreferences.map((k, v) => MapEntry(k.name, v)),
      'mutedUsers': mutedUsers,
      'mutedGroups': mutedGroups,
      'quietHoursStart': quietHoursStart.inMinutes,
      'quietHoursEnd': quietHoursEnd.inMinutes,
    };
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      enablePush: json['enablePush'] ?? true,
      enableInApp: json['enableInApp'] ?? true,
      enableEmail: json['enableEmail'] ?? false,
      enableSms: json['enableSms'] ?? false,
      typePreferences: Map.fromEntries(
        (json['typePreferences'] as Map<String, dynamic>? ?? {}).entries.map(
              (e) => MapEntry(
                NotificationType.values
                    .firstWhere((type) => type.name == e.key),
                e.value as bool,
              ),
            ),
      ),
      priorityPreferences: Map.fromEntries(
        (json['priorityPreferences'] as Map<String, dynamic>? ?? {})
            .entries
            .map(
              (e) => MapEntry(
                NotificationPriority.values
                    .firstWhere((priority) => priority.name == e.key),
                e.value as bool,
              ),
            ),
      ),
      mutedUsers: List<String>.from(json['mutedUsers'] ?? []),
      mutedGroups: List<String>.from(json['mutedGroups'] ?? []),
      quietHoursStart: Duration(minutes: json['quietHoursStart'] ?? 22 * 60),
      quietHoursEnd: Duration(minutes: json['quietHoursEnd'] ?? 8 * 60),
    );
  }
}

/// Real-time notification service
class RealtimeNotificationService {
  static RealtimeNotificationService? _instance;
  static RealtimeNotificationService get instance =>
      _instance ??= RealtimeNotificationService._();

  RealtimeNotificationService._();

  final SocketIOClient _socketClient = SocketIOClient.instance;
  String? _currentUserId;
  NotificationPreferences _preferences = const NotificationPreferences();

  // Notification streams
  final StreamController<RealtimeNotification> _notificationController =
      StreamController<RealtimeNotification>.broadcast();

  // Notification storage
  final List<RealtimeNotification> _notifications = [];
  final Map<String, RealtimeNotification> _notificationCache = {};

  // Statistics
  int _totalNotifications = 0;
  int _readNotifications = 0;
  int _mutedNotifications = 0;

  /// Get notification stream
  Stream<RealtimeNotification> get notifications =>
      _notificationController.stream;

  /// Get all notifications
  List<RealtimeNotification> get allNotifications => List.from(_notifications);

  /// Get unread notifications
  List<RealtimeNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  /// Get unread count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Get notification preferences
  NotificationPreferences get preferences => _preferences;

  /// Initialize notification service
  Future<bool> initialize({
    required String userId,
    NotificationPreferences? preferences,
  }) async {
    _currentUserId = userId;
    _preferences = preferences ?? const NotificationPreferences();

    // Setup event listeners
    _setupEventListeners();

    // Register for notifications
    _socketClient.emit('notifications:register', {
      'userId': userId,
      'preferences': _preferences.toJson(),
    });

    developer.log('Notification service initialized for user: $userId',
        name: 'RealtimeNotificationService');
    return true;
  }

  /// Send notification
  Future<void> sendNotification({
    required String title,
    required String body,
    required NotificationType type,
    NotificationPriority priority = NotificationPriority.normal,
    String? targetUserId,
    String? targetGroupId,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? actionUrl,
    DateTime? expiresAt,
  }) async {
    if (_currentUserId == null) {
      throw Exception('Notification service not initialized');
    }

    final notification = RealtimeNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      priority: priority,
      userId: targetUserId,
      groupId: targetGroupId,
      data: data,
      imageUrl: imageUrl,
      actionUrl: actionUrl,
      timestamp: DateTime.now(),
      expiresAt: expiresAt,
    );

    try {
      _socketClient.emit('notification:send', notification.toJson());
      developer.log('Notification sent: ${notification.id}',
          name: 'RealtimeNotificationService');
    } catch (e) {
      developer.log('Failed to send notification: $e',
          name: 'RealtimeNotificationService');
      rethrow;
    }
  }

  /// Mark notification as read
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index >= 0) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _notificationCache[notificationId] = _notifications[index];
      _readNotifications++;
    }

    _socketClient.emit('notification:read', {
      'notificationId': notificationId,
      'userId': _currentUserId,
    });
  }

  /// Mark all notifications as read
  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        _notificationCache[_notifications[i].id] = _notifications[i];
        _readNotifications++;
      }
    }

    _socketClient.emit('notifications:read_all', {
      'userId': _currentUserId,
    });
  }

  /// Mute user notifications
  void muteUser(String userId) {
    _socketClient.emit('notifications:mute_user', {
      'userId': userId,
      'mutedBy': _currentUserId,
    });
  }

  /// Unmute user notifications
  void unmuteUser(String userId) {
    _socketClient.emit('notifications:unmute_user', {
      'userId': userId,
      'unmutedBy': _currentUserId,
    });
  }

  /// Mute group notifications
  void muteGroup(String groupId) {
    _socketClient.emit('notifications:mute_group', {
      'groupId': groupId,
      'mutedBy': _currentUserId,
    });
  }

  /// Unmute group notifications
  void unmuteGroup(String groupId) {
    _socketClient.emit('notifications:unmute_group', {
      'groupId': groupId,
      'unmutedBy': _currentUserId,
    });
  }

  /// Update notification preferences
  void updatePreferences(NotificationPreferences preferences) {
    _preferences = preferences;
    _socketClient.emit('notifications:update_preferences', {
      'userId': _currentUserId,
      'preferences': preferences.toJson(),
    });
  }

  /// Clear notifications
  void clearNotifications({NotificationType? type}) {
    if (type != null) {
      _notifications.removeWhere((n) => n.type == type);
    } else {
      _notifications.clear();
    }
    _notificationCache.clear();
  }

  /// Setup event listeners
  void _setupEventListeners() {
    // Notification received
    _socketClient.on('notification:received', (data) {
      try {
        final notification = RealtimeNotification.fromJson(data);

        // Check if notification should be muted
        if (_shouldMuteNotification(notification)) {
          _mutedNotifications++;
          developer.log('Notification muted: ${notification.id}',
              name: 'RealtimeNotificationService');
          return;
        }

        _notifications.insert(0, notification);
        _notificationCache[notification.id] = notification;
        _totalNotifications++;

        _notificationController.add(notification);
        developer.log('Notification received: ${notification.id}',
            name: 'RealtimeNotificationService');
      } catch (e) {
        developer.log('Error parsing notification: $e',
            name: 'RealtimeNotificationService');
      }
    });

    // Notification read confirmation
    _socketClient.on('notification:read_confirmed', (data) {
      try {
        final notificationId = data['notificationId'];
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index >= 0) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
          _notificationCache[notificationId] = _notifications[index];
        }
      } catch (e) {
        developer.log('Error processing read confirmation: $e',
            name: 'RealtimeNotificationService');
      }
    });

    // Bulk notifications
    _socketClient.on('notifications:bulk', (data) {
      try {
        final notifications = (data['notifications'] as List)
            .map((n) => RealtimeNotification.fromJson(n))
            .toList();

        for (final notification in notifications) {
          if (!_shouldMuteNotification(notification)) {
            _notifications.insert(0, notification);
            _notificationCache[notification.id] = notification;
            _totalNotifications++;
            _notificationController.add(notification);
          } else {
            _mutedNotifications++;
          }
        }

        developer.log('Bulk notifications received: ${notifications.length}',
            name: 'RealtimeNotificationService');
      } catch (e) {
        developer.log('Error processing bulk notifications: $e',
            name: 'RealtimeNotificationService');
      }
    });

    // Notification expired
    _socketClient.on('notification:expired', (data) {
      try {
        final notificationId = data['notificationId'];
        _notifications.removeWhere((n) => n.id == notificationId);
        _notificationCache.remove(notificationId);
        developer.log('Notification expired: $notificationId',
            name: 'RealtimeNotificationService');
      } catch (e) {
        developer.log('Error processing expired notification: $e',
            name: 'RealtimeNotificationService');
      }
    });
  }

  /// Check if notification should be muted
  bool _shouldMuteNotification(RealtimeNotification notification) {
    // Check quiet hours
    final now = DateTime.now();
    final currentTime = Duration(hours: now.hour, minutes: now.minute);

    if (_isInQuietHours(currentTime)) {
      return notification.priority != NotificationPriority.critical;
    }

    // Check type preferences
    if (_preferences.typePreferences.containsKey(notification.type) &&
        !_preferences.typePreferences[notification.type]!) {
      return true;
    }

    // Check priority preferences
    if (_preferences.priorityPreferences.containsKey(notification.priority) &&
        !_preferences.priorityPreferences[notification.priority]!) {
      return true;
    }

    // Check muted users
    if (notification.userId != null &&
        _preferences.mutedUsers.contains(notification.userId)) {
      return true;
    }

    // Check muted groups
    if (notification.groupId != null &&
        _preferences.mutedGroups.contains(notification.groupId)) {
      return true;
    }

    return false;
  }

  /// Check if current time is in quiet hours
  bool _isInQuietHours(Duration currentTime) {
    if (_preferences.quietHoursStart <= _preferences.quietHoursEnd) {
      // Same day quiet hours
      return currentTime >= _preferences.quietHoursStart &&
          currentTime <= _preferences.quietHoursEnd;
    } else {
      // Overnight quiet hours
      return currentTime >= _preferences.quietHoursStart ||
          currentTime <= _preferences.quietHoursEnd;
    }
  }

  /// Get notification statistics
  Map<String, dynamic> getStats() {
    return {
      'total': _totalNotifications,
      'unread': unreadCount,
      'read': _readNotifications,
      'muted': _mutedNotifications,
      'types': _getTypeStats(),
      'priorities': _getPriorityStats(),
    };
  }

  /// Get type statistics
  Map<String, int> _getTypeStats() {
    final stats = <String, int>{};
    for (final notification in _notifications) {
      stats[notification.type.name] = (stats[notification.type.name] ?? 0) + 1;
    }
    return stats;
  }

  /// Get priority statistics
  Map<String, int> _getPriorityStats() {
    final stats = <String, int>{};
    for (final notification in _notifications) {
      stats[notification.priority.name] =
          (stats[notification.priority.name] ?? 0) + 1;
    }
    return stats;
  }

  /// Get notifications by type
  List<RealtimeNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  /// Get notifications by priority
  List<RealtimeNotification> getNotificationsByPriority(
      NotificationPriority priority) {
    return _notifications.where((n) => n.priority == priority).toList();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _notificationController.close();
    _notifications.clear();
    _notificationCache.clear();
    developer.log('Notification service disposed',
        name: 'RealtimeNotificationService');
  }
}
