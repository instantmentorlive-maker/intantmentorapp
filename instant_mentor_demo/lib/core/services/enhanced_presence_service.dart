import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'presence_service.dart';

/// Phase 2 Day 17: Per-conversation presence state
class ConversationPresence {
  final String chatId;
  final String userId;
  final DateTime lastRead;
  final DateTime lastActive;
  final bool isVisible;
  final PresenceStatus status;

  const ConversationPresence({
    required this.chatId,
    required this.userId,
    required this.lastRead,
    required this.lastActive,
    this.isVisible = true,
    this.status = PresenceStatus.offline,
  });

  ConversationPresence copyWith({
    String? chatId,
    String? userId,
    DateTime? lastRead,
    DateTime? lastActive,
    bool? isVisible,
    PresenceStatus? status,
  }) {
    return ConversationPresence(
      chatId: chatId ?? this.chatId,
      userId: userId ?? this.userId,
      lastRead: lastRead ?? this.lastRead,
      lastActive: lastActive ?? this.lastActive,
      isVisible: isVisible ?? this.isVisible,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'userId': userId,
      'lastRead': lastRead.toIso8601String(),
      'lastActive': lastActive.toIso8601String(),
      'isVisible': isVisible,
      'status': status.name,
    };
  }

  factory ConversationPresence.fromJson(Map<String, dynamic> json) {
    return ConversationPresence(
      chatId: json['chatId'],
      userId: json['userId'],
      lastRead: DateTime.parse(json['lastRead']),
      lastActive: DateTime.parse(json['lastActive']),
      isVisible: json['isVisible'] ?? true,
      status: PresenceStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PresenceStatus.offline,
      ),
    );
  }
}

/// Phase 2 Day 17: Enhanced Presence System with per-conversation state
/// Optimizes event fan-out and provides granular presence control
class EnhancedPresenceService {
  static EnhancedPresenceService? _instance;
  static EnhancedPresenceService get instance =>
      _instance ??= EnhancedPresenceService._();

  EnhancedPresenceService._();

  // Core presence service integration
  final PresenceService _presenceService = PresenceService.instance;

  // Per-conversation presence tracking
  final Map<String, Map<String, ConversationPresence>> _conversationPresences =
      {};
  final StreamController<Map<String, Map<String, ConversationPresence>>>
      _conversationPresenceController = StreamController<
          Map<String, Map<String, ConversationPresence>>>.broadcast();

  // Optimized event fan-out control
  final Map<String, Timer> _presenceUpdateTimers = {};
  final Map<String, List<String>> _chatSubscriptions =
      {}; // userId -> list of chatIds
  static const Duration _presenceUpdateBatchDelay = Duration(milliseconds: 200);

  // Privacy settings persistence
  SharedPreferences? _prefs;
  bool _globalPresenceVisible = true;
  final Set<String> _hiddenFromChats = {};
  final Map<String, PresenceStatus> _perChatStatus = {};

  /// Initialize enhanced presence system
  Future<void> initialize({
    required String userId,
    required String userName,
  }) async {
    await _presenceService.initialize(
      userId: userId,
      userName: userName,
    );

    _prefs = await SharedPreferences.getInstance();
    await _loadPrivacySettings();

    // Listen to base presence updates and optimize fan-out
    _presenceService.presenceStream.listen(_handlePresenceUpdates);

    debugPrint('✅ EnhancedPresenceService initialized');
  }

  /// Phase 2 Day 17: Load privacy settings from persistent storage
  Future<void> _loadPrivacySettings() async {
    if (_prefs == null) return;

    _globalPresenceVisible = _prefs!.getBool('global_presence_visible') ?? true;

    final hiddenChatsJson = _prefs!.getStringList('hidden_from_chats') ?? [];
    _hiddenFromChats.addAll(hiddenChatsJson);

    final perChatStatusJson = _prefs!.getString('per_chat_status');
    if (perChatStatusJson != null) {
      // Parse per-chat status settings
      // Implementation would depend on JSON structure
    }

    debugPrint(
        '📱 Privacy settings loaded: global=$_globalPresenceVisible, hidden=${_hiddenFromChats.length}');
  }

  /// Save privacy settings to persistent storage
  Future<void> _savePrivacySettings() async {
    if (_prefs == null) return;

    await _prefs!.setBool('global_presence_visible', _globalPresenceVisible);
    await _prefs!.setStringList('hidden_from_chats', _hiddenFromChats.toList());

    debugPrint('💾 Privacy settings saved');
  }

  /// Phase 2 Day 17: Subscribe to presence updates for a specific chat
  void subscribeToChat(String chatId, String userId) {
    _chatSubscriptions[userId] ??= [];
    if (!_chatSubscriptions[userId]!.contains(chatId)) {
      _chatSubscriptions[userId]!.add(chatId);
      debugPrint('📺 Subscribed user $userId to chat $chatId presence');
    }
  }

  /// Unsubscribe from chat presence updates
  void unsubscribeFromChat(String chatId, String userId) {
    _chatSubscriptions[userId]?.remove(chatId);
    if (_chatSubscriptions[userId]?.isEmpty == true) {
      _chatSubscriptions.remove(userId);
    }
    debugPrint('📺 Unsubscribed user $userId from chat $chatId presence');
  }

  /// Phase 2 Day 17: Handle presence updates with optimized fan-out
  void _handlePresenceUpdates(Map<String, UserPresence> presences) {
    // Batch updates to prevent UI thrash
    for (final presence in presences.values) {
      _presenceUpdateTimers[presence.userId]?.cancel();
      _presenceUpdateTimers[presence.userId] =
          Timer(_presenceUpdateBatchDelay, () {
        _updateConversationPresences(presence);
      });
    }
  }

  /// Update conversation-specific presence states
  void _updateConversationPresences(UserPresence presence) {
    final userId = presence.userId;
    final subscribedChats = _chatSubscriptions[userId] ?? [];

    for (final chatId in subscribedChats) {
      // Check privacy settings for this chat
      final isVisible = _isPresenceVisibleInChat(chatId, userId);
      final effectiveStatus =
          isVisible ? presence.status : PresenceStatus.invisible;

      _conversationPresences[chatId] ??= {};
      _conversationPresences[chatId]![userId] = ConversationPresence(
        chatId: chatId,
        userId: userId,
        lastRead: presence.lastSeen,
        lastActive: DateTime.now(),
        isVisible: isVisible,
        status: effectiveStatus,
      );
    }

    // Emit batched update
    _conversationPresenceController.add(Map.from(_conversationPresences));
  }

  /// Check if presence should be visible in a specific chat
  bool _isPresenceVisibleInChat(String chatId, String userId) {
    // Check global privacy setting
    if (!_globalPresenceVisible) return false;

    // Check if user is hidden from this specific chat
    if (_hiddenFromChats.contains(chatId)) return false;

    // Check per-chat status override
    if (_perChatStatus.containsKey(chatId)) {
      return _perChatStatus[chatId] != PresenceStatus.invisible;
    }

    return true;
  }

  /// Phase 2 Day 17: Set presence visibility for specific chat
  Future<void> setPresenceVisibilityForChat(String chatId, bool visible) async {
    if (visible) {
      _hiddenFromChats.remove(chatId);
    } else {
      _hiddenFromChats.add(chatId);
    }

    await _savePrivacySettings();

    // Refresh presence for affected chat
    _refreshChatPresence(chatId);

    debugPrint('👁️ Set presence visibility for chat $chatId: $visible');
  }

  /// Set custom status for specific chat
  Future<void> setChatSpecificStatus(
      String chatId, PresenceStatus status) async {
    _perChatStatus[chatId] = status;
    await _savePrivacySettings();

    _refreshChatPresence(chatId);

    debugPrint('📝 Set chat-specific status for $chatId: ${status.name}');
  }

  /// Remove chat-specific status (use global status)
  Future<void> removeChatSpecificStatus(String chatId) async {
    _perChatStatus.remove(chatId);
    await _savePrivacySettings();

    _refreshChatPresence(chatId);

    debugPrint('🗑️ Removed chat-specific status for $chatId');
  }

  /// Refresh presence state for a specific chat
  void _refreshChatPresence(String chatId) {
    final currentPresences = _presenceService.getAllUserPresences();
    for (final presence in currentPresences.values) {
      _updateConversationPresences(presence);
    }
  }

  /// Phase 2 Day 17: Set global presence visibility
  Future<void> setGlobalPresenceVisibility(bool visible) async {
    _globalPresenceVisible = visible;
    await _savePrivacySettings();

    // Update base presence service
    _presenceService.setPresenceEnabled(visible);

    // Refresh all conversation presences
    for (final chatId in _conversationPresences.keys) {
      _refreshChatPresence(chatId);
    }

    debugPrint('🌍 Set global presence visibility: $visible');
  }

  /// Get presence state for users in a specific chat
  Map<String, ConversationPresence> getChatPresences(String chatId) {
    return Map.from(_conversationPresences[chatId] ?? {});
  }

  /// Get presence for a specific user in a specific chat
  ConversationPresence? getUserPresenceInChat(String chatId, String userId) {
    return _conversationPresences[chatId]?[userId];
  }

  /// Check if user is active in a specific chat
  bool isUserActiveInChat(String chatId, String userId) {
    final presence = getUserPresenceInChat(chatId, userId);
    if (presence == null || !presence.isVisible) return false;

    final timeSinceLastActive = DateTime.now().difference(presence.lastActive);
    return timeSinceLastActive.inMinutes < 5 &&
        presence.status != PresenceStatus.offline;
  }

  /// Get active users count for a chat
  int getActiveChatUsersCount(String chatId) {
    final chatPresences = getChatPresences(chatId);
    return chatPresences.values
        .where((p) => p.isVisible && p.status != PresenceStatus.offline)
        .length;
  }

  /// Phase 2 Day 17: Mark user as active in chat (for read receipts)
  Future<void> markActiveInChat(String chatId, String userId) async {
    _conversationPresences[chatId] ??= {};

    final existing = _conversationPresences[chatId]![userId];
    if (existing != null) {
      _conversationPresences[chatId]![userId] = existing.copyWith(
        lastActive: DateTime.now(),
        lastRead: DateTime.now(),
      );
    } else {
      _conversationPresences[chatId]![userId] = ConversationPresence(
        chatId: chatId,
        userId: userId,
        lastRead: DateTime.now(),
        lastActive: DateTime.now(),
        isVisible: _isPresenceVisibleInChat(chatId, userId),
      );
    }

    _conversationPresenceController.add(Map.from(_conversationPresences));
  }

  /// Get typing indicators with privacy filtering
  List<String> getTypingUsersInChat(String chatId) {
    final baseTypingUsers = _presenceService.getTypingUserNamesInChat(chatId);
    final chatPresences = getChatPresences(chatId);

    // Filter out users who have disabled presence in this chat
    return baseTypingUsers.where((userName) {
      final userId = chatPresences.entries
          .firstWhere((entry) => entry.value.userId == userName,
              orElse: () => MapEntry(
                  '',
                  ConversationPresence(
                      chatId: '',
                      userId: '',
                      lastRead: DateTime.now(),
                      lastActive: DateTime.now())))
          .key;

      final presence = chatPresences[userId];
      return presence?.isVisible == true;
    }).toList();
  }

  /// Get privacy settings summary
  Map<String, dynamic> getPrivacySettings() {
    return {
      'global_presence_visible': _globalPresenceVisible,
      'hidden_from_chats_count': _hiddenFromChats.length,
      'per_chat_status_count': _perChatStatus.length,
      'hidden_chats': _hiddenFromChats.toList(),
      'chat_statuses': Map.fromEntries(
          _perChatStatus.entries.map((e) => MapEntry(e.key, e.value.name))),
    };
  }

  /// Bulk update privacy settings
  Future<void> updatePrivacySettings({
    bool? globalVisible,
    Set<String>? hiddenChats,
    Map<String, PresenceStatus>? chatStatuses,
  }) async {
    bool needsRefresh = false;

    if (globalVisible != null && globalVisible != _globalPresenceVisible) {
      _globalPresenceVisible = globalVisible;
      needsRefresh = true;
    }

    if (hiddenChats != null) {
      _hiddenFromChats.clear();
      _hiddenFromChats.addAll(hiddenChats);
      needsRefresh = true;
    }

    if (chatStatuses != null) {
      _perChatStatus.clear();
      _perChatStatus.addAll(chatStatuses);
      needsRefresh = true;
    }

    if (needsRefresh) {
      await _savePrivacySettings();

      // Refresh all presence states
      for (final chatId in _conversationPresences.keys) {
        _refreshChatPresence(chatId);
      }
    }

    debugPrint('🔧 Bulk privacy settings updated');
  }

  /// Stream for conversation presence updates
  Stream<Map<String, Map<String, ConversationPresence>>>
      get conversationPresenceStream => _conversationPresenceController.stream;

  /// Clean up resources
  void dispose() {
    for (var timer in _presenceUpdateTimers.values) {
      timer.cancel();
    }
    _presenceUpdateTimers.clear();
    _conversationPresenceController.close();
    _conversationPresences.clear();
    _chatSubscriptions.clear();
    _hiddenFromChats.clear();
    _perChatStatus.clear();
    _presenceService.dispose();
  }
}
