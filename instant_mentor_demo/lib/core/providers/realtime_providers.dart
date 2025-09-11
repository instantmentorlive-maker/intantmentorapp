import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../realtime/websocket_client.dart';
import '../realtime/socketio_client.dart';
import '../realtime/messaging_service.dart';
import '../realtime/notification_service.dart';

// =============================================================================
// WebSocket Providers
// =============================================================================

/// WebSocket client provider
final webSocketClientProvider = Provider<WebSocketClient>((ref) {
  return WebSocketClient.instance;
});

/// WebSocket connection state provider
final webSocketStateProvider = StateNotifierProvider<WebSocketStateNotifier, WebSocketConnectionState>((ref) {
  return WebSocketStateNotifier(ref);
});

class WebSocketStateNotifier extends StateNotifier<WebSocketConnectionState> {
  WebSocketStateNotifier(this.ref) : super(WebSocketConnectionState.disconnected) {
    _initialize();
  }

  final Ref ref;
  StreamSubscription? _eventSubscription;

  void _initialize() {
    final client = ref.read(webSocketClientProvider);
    _eventSubscription = client.events.listen((event) {
      switch (event.type) {
        case WebSocketEventType.connect:
          state = WebSocketConnectionState.connected;
          break;
        case WebSocketEventType.disconnect:
          state = WebSocketConnectionState.disconnected;
          break;
        case WebSocketEventType.error:
          state = WebSocketConnectionState.error;
          break;
        case WebSocketEventType.reconnect:
          state = WebSocketConnectionState.reconnecting;
          break;
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}

/// WebSocket statistics provider
final webSocketStatsProvider = StateNotifierProvider<WebSocketStatsNotifier, WebSocketStats>((ref) {
  return WebSocketStatsNotifier(ref);
});

class WebSocketStatsNotifier extends StateNotifier<WebSocketStats> {
  WebSocketStatsNotifier(this.ref) : super(WebSocketStats(
    totalConnections: 0,
    totalReconnections: 0,
    totalMessages: 0,
    totalErrors: 0,
    totalUptime: Duration.zero,
    lastConnected: DateTime.now(),
    recentErrors: [],
  )) {
    _startPeriodicUpdate();
  }

  final Ref ref;
  Timer? _updateTimer;

  void _startPeriodicUpdate() {
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final client = ref.read(webSocketClientProvider);
      state = client.stats;
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

// =============================================================================
// Socket.IO Providers
// =============================================================================

/// Socket.IO client provider
final socketIOClientProvider = Provider<SocketIOClient>((ref) {
  return SocketIOClient.instance;
});

/// Socket.IO connection state provider
final socketIOStateProvider = StateNotifierProvider<SocketIOStateNotifier, SocketConnectionState>((ref) {
  return SocketIOStateNotifier(ref);
});

class SocketIOStateNotifier extends StateNotifier<SocketConnectionState> {
  SocketIOStateNotifier(this.ref) : super(SocketConnectionState.disconnected) {
    _initialize();
  }

  final Ref ref;
  StreamSubscription? _eventSubscription;

  void _initialize() {
    final client = ref.read(socketIOClientProvider);
    _eventSubscription = client.events.listen((event) {
      switch (event.event) {
        case 'connect':
          state = SocketConnectionState.connected;
          break;
        case 'disconnect':
          state = SocketConnectionState.disconnected;
          break;
        case 'connect_error':
        case 'reconnect_error':
        case 'reconnect_failed':
          state = SocketConnectionState.error;
          break;
        case 'reconnect':
          state = SocketConnectionState.connected;
          break;
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}

/// Socket.IO statistics provider
final socketIOStatsProvider = StateNotifierProvider<SocketIOStatsNotifier, SocketStats>((ref) {
  return SocketIOStatsNotifier(ref);
});

class SocketIOStatsNotifier extends StateNotifier<SocketStats> {
  SocketIOStatsNotifier(this.ref) : super(SocketStats(
    totalConnections: 0,
    totalDisconnections: 0,
    totalEvents: 0,
    totalErrors: 0,
    totalUptime: Duration.zero,
    lastConnected: DateTime.now(),
    eventCounts: {},
    recentErrors: [],
  )) {
    _startPeriodicUpdate();
  }

  final Ref ref;
  Timer? _updateTimer;

  void _startPeriodicUpdate() {
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final client = ref.read(socketIOClientProvider);
      state = client.stats;
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

// =============================================================================
// Messaging Providers
// =============================================================================

/// Messaging service provider
final messagingServiceProvider = Provider<RealtimeMessagingService>((ref) {
  return RealtimeMessagingService.instance;
});

/// Messages stream provider
final messagesStreamProvider = StreamProvider<RealtimeMessage>((ref) {
  final service = ref.read(messagingServiceProvider);
  return service.messages;
});

/// Typing indicators stream provider
final typingIndicatorsStreamProvider = StreamProvider<TypingIndicator>((ref) {
  final service = ref.read(messagingServiceProvider);
  return service.typingIndicators;
});

/// User presence stream provider
final presenceUpdatesStreamProvider = StreamProvider<UserPresence>((ref) {
  final service = ref.read(messagingServiceProvider);
  return service.presenceUpdates;
});

/// Room messages provider
final roomMessagesProvider = StreamProviderFamily<RealtimeMessage, String>((ref, roomId) {
  final service = ref.read(messagingServiceProvider);
  return service.getMessagesForRoom(roomId);
});

/// User messages provider
final userMessagesProvider = StreamProviderFamily<RealtimeMessage, String>((ref, userId) {
  final service = ref.read(messagingServiceProvider);
  return service.getMessagesForUser(userId);
});

/// User presences provider
final userPresencesProvider = StateNotifierProvider<UserPresencesNotifier, Map<String, UserPresence>>((ref) {
  return UserPresencesNotifier(ref);
});

class UserPresencesNotifier extends StateNotifier<Map<String, UserPresence>> {
  UserPresencesNotifier(this.ref) : super({}) {
    _initialize();
  }

  final Ref ref;
  StreamSubscription? _presenceSubscription;

  void _initialize() {
    final service = ref.read(messagingServiceProvider);
    _presenceSubscription = service.presenceUpdates.listen((presence) {
      state = {
        ...state,
        presence.userId: presence,
      };
    });
  }

  @override
  void dispose() {
    _presenceSubscription?.cancel();
    super.dispose();
  }
}

/// Typing users provider
final typingUsersProvider = StateNotifierProvider<TypingUsersNotifier, Map<String, TypingIndicator>>((ref) {
  return TypingUsersNotifier(ref);
});

class TypingUsersNotifier extends StateNotifier<Map<String, TypingIndicator>> {
  TypingUsersNotifier(this.ref) : super({}) {
    _initialize();
  }

  final Ref ref;
  StreamSubscription? _typingSubscription;

  void _initialize() {
    final service = ref.read(messagingServiceProvider);
    _typingSubscription = service.typingIndicators.listen((typing) {
      final newState = Map<String, TypingIndicator>.from(state);
      newState[typing.userId] = typing;

      // Remove old typing indicators (older than 5 seconds)
      final now = DateTime.now();
      newState.removeWhere((key, value) {
        return now.difference(value.timestamp).inSeconds > 5;
      });

      state = newState;
    });

    // Cleanup old typing indicators periodically
    Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final newState = Map<String, TypingIndicator>.from(state);
      newState.removeWhere((key, value) {
        return now.difference(value.timestamp).inSeconds > 5;
      });
      if (newState.length != state.length) {
        state = newState;
      }
    });
  }

  @override
  void dispose() {
    _typingSubscription?.cancel();
    super.dispose();
  }
}

// =============================================================================
// Notification Providers
// =============================================================================

/// Notification service provider
final notificationServiceProvider = Provider<RealtimeNotificationService>((ref) {
  return RealtimeNotificationService.instance;
});

/// Notifications stream provider
final notificationsStreamProvider = StreamProvider<RealtimeNotification>((ref) {
  final service = ref.read(notificationServiceProvider);
  return service.notifications;
});

/// All notifications provider
final allNotificationsProvider = StateNotifierProvider<AllNotificationsNotifier, List<RealtimeNotification>>((ref) {
  return AllNotificationsNotifier(ref);
});

class AllNotificationsNotifier extends StateNotifier<List<RealtimeNotification>> {
  AllNotificationsNotifier(this.ref) : super([]) {
    _initialize();
  }

  final Ref ref;
  StreamSubscription? _notificationSubscription;

  void _initialize() {
    final service = ref.read(notificationServiceProvider);
    _notificationSubscription = service.notifications.listen((notification) {
      state = [notification, ...state];
    });

    // Initialize with existing notifications
    state = service.allNotifications;
  }

  void markAsRead(String notificationId) {
    final service = ref.read(notificationServiceProvider);
    service.markAsRead(notificationId);
    
    final index = state.indexWhere((n) => n.id == notificationId);
    if (index >= 0) {
      final updatedNotification = state[index].copyWith(isRead: true);
      final newState = List<RealtimeNotification>.from(state);
      newState[index] = updatedNotification;
      state = newState;
    }
  }

  void markAllAsRead() {
    final service = ref.read(notificationServiceProvider);
    service.markAllAsRead();
    
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void clearNotifications({NotificationType? type}) {
    final service = ref.read(notificationServiceProvider);
    service.clearNotifications(type: type);
    
    if (type != null) {
      state = state.where((n) => n.type != type).toList();
    } else {
      state = [];
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
}

/// Unread notifications provider
final unreadNotificationsProvider = Provider<List<RealtimeNotification>>((ref) {
  final notifications = ref.watch(allNotificationsProvider);
  return notifications.where((n) => !n.isRead).toList();
});

/// Unread count provider
final unreadCountProvider = Provider<int>((ref) {
  final unread = ref.watch(unreadNotificationsProvider);
  return unread.length;
});

/// Notifications by type provider
final notificationsByTypeProvider = ProviderFamily<List<RealtimeNotification>, NotificationType>((ref, type) {
  final notifications = ref.watch(allNotificationsProvider);
  return notifications.where((n) => n.type == type).toList();
});

/// Notification preferences provider
final notificationPreferencesProvider = StateNotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>((ref) {
  return NotificationPreferencesNotifier(ref);
});

class NotificationPreferencesNotifier extends StateNotifier<NotificationPreferences> {
  NotificationPreferencesNotifier(this.ref) : super(const NotificationPreferences());

  final Ref ref;

  void updatePreferences(NotificationPreferences preferences) {
    final service = ref.read(notificationServiceProvider);
    service.updatePreferences(preferences);
    state = preferences;
  }

  void togglePush(bool enabled) {
    final newPrefs = NotificationPreferences(
      enablePush: enabled,
      enableInApp: state.enableInApp,
      enableEmail: state.enableEmail,
      enableSms: state.enableSms,
      typePreferences: state.typePreferences,
      priorityPreferences: state.priorityPreferences,
      mutedUsers: state.mutedUsers,
      mutedGroups: state.mutedGroups,
      quietHoursStart: state.quietHoursStart,
      quietHoursEnd: state.quietHoursEnd,
    );
    updatePreferences(newPrefs);
  }

  void toggleInApp(bool enabled) {
    final newPrefs = NotificationPreferences(
      enablePush: state.enablePush,
      enableInApp: enabled,
      enableEmail: state.enableEmail,
      enableSms: state.enableSms,
      typePreferences: state.typePreferences,
      priorityPreferences: state.priorityPreferences,
      mutedUsers: state.mutedUsers,
      mutedGroups: state.mutedGroups,
      quietHoursStart: state.quietHoursStart,
      quietHoursEnd: state.quietHoursEnd,
    );
    updatePreferences(newPrefs);
  }

  void setTypePreference(NotificationType type, bool enabled) {
    final newTypePrefs = Map<NotificationType, bool>.from(state.typePreferences);
    newTypePrefs[type] = enabled;
    
    final newPrefs = NotificationPreferences(
      enablePush: state.enablePush,
      enableInApp: state.enableInApp,
      enableEmail: state.enableEmail,
      enableSms: state.enableSms,
      typePreferences: newTypePrefs,
      priorityPreferences: state.priorityPreferences,
      mutedUsers: state.mutedUsers,
      mutedGroups: state.mutedGroups,
      quietHoursStart: state.quietHoursStart,
      quietHoursEnd: state.quietHoursEnd,
    );
    updatePreferences(newPrefs);
  }

  void muteUser(String userId) {
    final newMutedUsers = List<String>.from(state.mutedUsers);
    if (!newMutedUsers.contains(userId)) {
      newMutedUsers.add(userId);
    }
    
    final newPrefs = NotificationPreferences(
      enablePush: state.enablePush,
      enableInApp: state.enableInApp,
      enableEmail: state.enableEmail,
      enableSms: state.enableSms,
      typePreferences: state.typePreferences,
      priorityPreferences: state.priorityPreferences,
      mutedUsers: newMutedUsers,
      mutedGroups: state.mutedGroups,
      quietHoursStart: state.quietHoursStart,
      quietHoursEnd: state.quietHoursEnd,
    );
    updatePreferences(newPrefs);
  }

  void unmuteUser(String userId) {
    final newMutedUsers = List<String>.from(state.mutedUsers);
    newMutedUsers.remove(userId);
    
    final newPrefs = NotificationPreferences(
      enablePush: state.enablePush,
      enableInApp: state.enableInApp,
      enableEmail: state.enableEmail,
      enableSms: state.enableSms,
      typePreferences: state.typePreferences,
      priorityPreferences: state.priorityPreferences,
      mutedUsers: newMutedUsers,
      mutedGroups: state.mutedGroups,
      quietHoursStart: state.quietHoursStart,
      quietHoursEnd: state.quietHoursEnd,
    );
    updatePreferences(newPrefs);
  }
}

// =============================================================================
// Real-time Dashboard Provider
// =============================================================================

/// Real-time dashboard state
class RealtimeDashboardState {
  final WebSocketConnectionState webSocketState;
  final SocketConnectionState socketIOState;
  final WebSocketStats webSocketStats;
  final SocketStats socketIOStats;
  final int unreadNotifications;
  final Map<String, UserPresence> userPresences;
  final Map<String, TypingIndicator> typingUsers;
  final bool isConnected;

  const RealtimeDashboardState({
    required this.webSocketState,
    required this.socketIOState,
    required this.webSocketStats,
    required this.socketIOStats,
    required this.unreadNotifications,
    required this.userPresences,
    required this.typingUsers,
    required this.isConnected,
  });
}

/// Real-time dashboard provider
final realtimeDashboardProvider = Provider<RealtimeDashboardState>((ref) {
  final webSocketState = ref.watch(webSocketStateProvider);
  final socketIOState = ref.watch(socketIOStateProvider);
  final webSocketStats = ref.watch(webSocketStatsProvider);
  final socketIOStats = ref.watch(socketIOStatsProvider);
  final unreadCount = ref.watch(unreadCountProvider);
  final userPresences = ref.watch(userPresencesProvider);
  final typingUsers = ref.watch(typingUsersProvider);

  final isConnected = webSocketState == WebSocketConnectionState.connected ||
                     socketIOState == SocketConnectionState.connected;

  return RealtimeDashboardState(
    webSocketState: webSocketState,
    socketIOState: socketIOState,
    webSocketStats: webSocketStats,
    socketIOStats: socketIOStats,
    unreadNotifications: unreadCount,
    userPresences: userPresences,
    typingUsers: typingUsers,
    isConnected: isConnected,
  );
});
