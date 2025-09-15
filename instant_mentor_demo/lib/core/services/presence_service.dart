import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'websocket_service.dart';

/// Phase 2 Day 16: User presence and typing indicator states
enum PresenceStatus {
  online,
  offline,
  away,
  busy,
  invisible,
}

enum TypingStatus {
  idle,
  typing,
  stopped,
}

/// User presence information
class UserPresence {
  final String userId;
  final String userName;
  final PresenceStatus status;
  final DateTime lastSeen;
  final String? customStatus;
  final bool isTyping;
  final String? typingInChatId;

  const UserPresence({
    required this.userId,
    required this.userName,
    required this.status,
    required this.lastSeen,
    this.customStatus,
    this.isTyping = false,
    this.typingInChatId,
  });

  UserPresence copyWith({
    String? userId,
    String? userName,
    PresenceStatus? status,
    DateTime? lastSeen,
    String? customStatus,
    bool? isTyping,
    String? typingInChatId,
  }) {
    return UserPresence(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      customStatus: customStatus ?? this.customStatus,
      isTyping: isTyping ?? this.isTyping,
      typingInChatId: typingInChatId ?? this.typingInChatId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'status': status.name,
      'lastSeen': lastSeen.toIso8601String(),
      'customStatus': customStatus,
      'isTyping': isTyping,
      'typingInChatId': typingInChatId,
    };
  }

  factory UserPresence.fromJson(Map<String, dynamic> json) {
    return UserPresence(
      userId: json['userId'],
      userName: json['userName'],
      status: PresenceStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PresenceStatus.offline,
      ),
      lastSeen: DateTime.parse(json['lastSeen']),
      customStatus: json['customStatus'],
      isTyping: json['isTyping'] ?? false,
      typingInChatId: json['typingInChatId'],
    );
  }
}

/// Phase 2 Day 16: Typing Indicators & Presence System Service
/// Manages real-time user presence and typing indicators with privacy controls
class PresenceService {
  static PresenceService? _instance;
  static PresenceService get instance => _instance ??= PresenceService._();

  PresenceService._();

  // Current user state
  String? _currentUserId;
  String? _currentUserName;
  PresenceStatus _currentStatus = PresenceStatus.offline;
  bool _presenceEnabled = true;

  // Presence tracking
  final Map<String, UserPresence> _userPresences = {};
  final StreamController<Map<String, UserPresence>> _presenceStreamController =
      StreamController<Map<String, UserPresence>>.broadcast();

  // Typing indicators
  final Map<String, Set<String>> _typingUsers = {}; // chatId -> Set of userIds
  final StreamController<Map<String, Set<String>>> _typingStreamController =
      StreamController<Map<String, Set<String>>>.broadcast();

  // Debouncing and cleanup
  final Map<String, Timer> _typingTimers = {}; // userId -> cleanup timer
  static const Duration _typingTimeout = Duration(seconds: 3);

  // Presence update timer
  Timer? _presenceUpdateTimer;
  static const Duration _presenceUpdateInterval = Duration(minutes: 1);

  /// Initialize presence service for the current user
  Future<void> initialize({
    required String userId,
    required String userName,
    PresenceStatus initialStatus = PresenceStatus.online,
  }) async {
    _currentUserId = userId;
    _currentUserName = userName;
    _currentStatus = initialStatus;

    // Set up WebSocket listeners for presence events
    _setupPresenceEventListeners();

    // Start presence updates
    _startPresenceUpdates();

    // Announce initial presence
    await _broadcastPresenceUpdate();

    debugPrint('✅ PresenceService initialized for user: $userName');
  }

  /// Set up WebSocket event listeners for presence
  void _setupPresenceEventListeners() {
    final websocket = WebSocketService.instance;

    websocket.messageStream.listen((message) {
      switch (message.event) {
        case WebSocketEvent.userOnline:
        case WebSocketEvent.userOffline:
          _handlePresenceUpdate(message);
          break;
        case WebSocketEvent.userTyping:
          _handleTypingStart(message);
          break;
        case WebSocketEvent.userStoppedTyping:
          _handleTypingStop(message);
          break;
        default:
          // Handle other events as needed
          break;
      }
    });
  }

  /// Phase 2 Day 16: Handle presence updates from other users
  void _handlePresenceUpdate(WebSocketMessage message) {
    try {
      final data = message.data;
      final userId = data['userId'] as String?;
      final userName = data['userName'] as String?;
      final status = data['status'] as String?;

      if (userId == null || userName == null || status == null) return;

      final presence = UserPresence(
        userId: userId,
        userName: userName,
        status: PresenceStatus.values.firstWhere(
          (s) => s.name == status,
          orElse: () => PresenceStatus.offline,
        ),
        lastSeen: DateTime.now(),
        customStatus: data['customStatus'],
      );

      _userPresences[userId] = presence;
      _presenceStreamController.add(Map.from(_userPresences));

      debugPrint('👤 Presence updated: $userName is ${presence.status.name}');
    } catch (e) {
      debugPrint('❌ Error handling presence update: $e');
    }
  }

  /// Phase 2 Day 16: Handle typing start events with debouncing
  void _handleTypingStart(WebSocketMessage message) {
    try {
      final data = message.data;
      final userId = data['userId'] as String?;
      final chatId = data['chatId'] as String?;

      if (userId == null || chatId == null || userId == _currentUserId) return;

      // Add user to typing list for this chat
      _typingUsers[chatId] ??= {};
      _typingUsers[chatId]!.add(userId);

      // Update user presence with typing status
      if (_userPresences.containsKey(userId)) {
        _userPresences[userId] = _userPresences[userId]!.copyWith(
          isTyping: true,
          typingInChatId: chatId,
        );
      }

      // Set up cleanup timer
      _typingTimers[userId]?.cancel();
      _typingTimers[userId] = Timer(_typingTimeout, () {
        _stopTypingForUser(userId, chatId);
      });

      _typingStreamController.add(Map.from(_typingUsers));
      _presenceStreamController.add(Map.from(_userPresences));

      debugPrint('⌨️ User $userId started typing in chat $chatId');
    } catch (e) {
      debugPrint('❌ Error handling typing start: $e');
    }
  }

  /// Handle typing stop events
  void _handleTypingStop(WebSocketMessage message) {
    try {
      final data = message.data;
      final userId = data['userId'] as String?;
      final chatId = data['chatId'] as String?;

      if (userId == null || chatId == null) return;

      _stopTypingForUser(userId, chatId);
    } catch (e) {
      debugPrint('❌ Error handling typing stop: $e');
    }
  }

  /// Stop typing for a specific user
  void _stopTypingForUser(String userId, String chatId) {
    // Remove user from typing list
    _typingUsers[chatId]?.remove(userId);
    if (_typingUsers[chatId]?.isEmpty == true) {
      _typingUsers.remove(chatId);
    }

    // Update user presence
    if (_userPresences.containsKey(userId)) {
      _userPresences[userId] = _userPresences[userId]!.copyWith(
        isTyping: false,
        typingInChatId: null,
      );
    }

    // Cancel cleanup timer
    _typingTimers[userId]?.cancel();
    _typingTimers.remove(userId);

    _typingStreamController.add(Map.from(_typingUsers));
    _presenceStreamController.add(Map.from(_userPresences));

    debugPrint('⌨️ User $userId stopped typing in chat $chatId');
  }

  /// Phase 2 Day 16: Start typing in a chat (debounced)
  Future<void> startTyping(String chatId) async {
    if (!_presenceEnabled || _currentUserId == null) return;

    try {
      final message = WebSocketMessage(
        id: 'typing_${DateTime.now().millisecondsSinceEpoch}',
        event: WebSocketEvent.userTyping,
        senderId: _currentUserId,
        data: {
          'userId': _currentUserId,
          'userName': _currentUserName,
          'chatId': chatId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      await WebSocketService.instance.sendMessage(message);
      debugPrint('⌨️ Started typing in chat: $chatId');
    } catch (e) {
      debugPrint('❌ Failed to send typing start: $e');
    }
  }

  /// Stop typing in a chat
  Future<void> stopTyping(String chatId) async {
    if (!_presenceEnabled || _currentUserId == null) return;

    try {
      final message = WebSocketMessage(
        id: 'stop_typing_${DateTime.now().millisecondsSinceEpoch}',
        event: WebSocketEvent.userStoppedTyping,
        senderId: _currentUserId,
        data: {
          'userId': _currentUserId,
          'userName': _currentUserName,
          'chatId': chatId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      await WebSocketService.instance.sendMessage(message);
      debugPrint('⌨️ Stopped typing in chat: $chatId');
    } catch (e) {
      debugPrint('❌ Failed to send typing stop: $e');
    }
  }

  /// Update current user's presence status
  Future<void> updatePresenceStatus(PresenceStatus status,
      {String? customStatus}) async {
    if (_currentUserId == null) return;

    _currentStatus = status;

    if (_presenceEnabled) {
      await _broadcastPresenceUpdate(customStatus: customStatus);
    }

    debugPrint('👤 Updated presence status to: ${status.name}');
  }

  /// Broadcast presence update to all connected users
  Future<void> _broadcastPresenceUpdate({String? customStatus}) async {
    if (!_presenceEnabled || _currentUserId == null) return;

    try {
      final event = _currentStatus == PresenceStatus.offline
          ? WebSocketEvent.userOffline
          : WebSocketEvent.userOnline;

      final message = WebSocketMessage(
        id: 'presence_${DateTime.now().millisecondsSinceEpoch}',
        event: event,
        senderId: _currentUserId,
        data: {
          'userId': _currentUserId,
          'userName': _currentUserName,
          'status': _currentStatus.name,
          'customStatus': customStatus,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      await WebSocketService.instance.sendMessage(message);
      debugPrint('📡 Broadcasted presence update: ${_currentStatus.name}');
    } catch (e) {
      debugPrint('❌ Failed to broadcast presence: $e');
    }
  }

  /// Start periodic presence updates
  void _startPresenceUpdates() {
    _presenceUpdateTimer?.cancel();
    _presenceUpdateTimer = Timer.periodic(_presenceUpdateInterval, (_) {
      if (_presenceEnabled && _currentStatus != PresenceStatus.offline) {
        _broadcastPresenceUpdate();
      }
    });
  }

  /// Phase 2 Day 16: Toggle presence privacy (Day 17 requirement)
  void setPresenceEnabled(bool enabled) {
    _presenceEnabled = enabled;

    if (!enabled) {
      // Go offline when privacy is enabled
      updatePresenceStatus(PresenceStatus.invisible);
    } else if (_currentStatus == PresenceStatus.invisible) {
      // Come back online when privacy is disabled
      updatePresenceStatus(PresenceStatus.online);
    }

    debugPrint('👤 Presence privacy ${enabled ? 'disabled' : 'enabled'}');
  }

  /// Get typing users for a specific chat
  Set<String> getTypingUsersInChat(String chatId) {
    return Set.from(_typingUsers[chatId] ?? {});
  }

  /// Get typing user names for a specific chat
  List<String> getTypingUserNamesInChat(String chatId) {
    final typingUserIds = getTypingUsersInChat(chatId);
    return typingUserIds
        .map((userId) => _userPresences[userId]?.userName ?? 'Unknown')
        .toList();
  }

  /// Get presence for a specific user
  UserPresence? getUserPresence(String userId) {
    return _userPresences[userId];
  }

  /// Get all user presences
  Map<String, UserPresence> getAllUserPresences() {
    return Map.from(_userPresences);
  }

  /// Check if user is online
  bool isUserOnline(String userId) {
    final presence = _userPresences[userId];
    return presence?.status == PresenceStatus.online ||
        presence?.status == PresenceStatus.away ||
        presence?.status == PresenceStatus.busy;
  }

  /// Get last seen for user
  DateTime? getLastSeen(String userId) {
    return _userPresences[userId]?.lastSeen;
  }

  /// Get formatted last seen string
  String getFormattedLastSeen(String userId) {
    final lastSeen = getLastSeen(userId);
    if (lastSeen == null) return 'Never seen';

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Streams for real-time updates
  Stream<Map<String, UserPresence>> get presenceStream =>
      _presenceStreamController.stream;
  Stream<Map<String, Set<String>>> get typingStream =>
      _typingStreamController.stream;

  /// Handle app lifecycle changes
  void handleAppLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_presenceEnabled) {
          updatePresenceStatus(PresenceStatus.online);
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        if (_presenceEnabled) {
          updatePresenceStatus(PresenceStatus.away);
        }
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (_presenceEnabled) {
          updatePresenceStatus(PresenceStatus.offline);
        }
        break;
    }
  }

  /// Clean up resources
  void dispose() {
    _presenceUpdateTimer?.cancel();
    _typingTimers.values.forEach((timer) => timer.cancel());
    _typingTimers.clear();
    _presenceStreamController.close();
    _typingStreamController.close();
    _userPresences.clear();
    _typingUsers.clear();
  }
}
