import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat.dart';
import 'local_message_service.dart';
import 'supabase_service.dart';

/// Phase 2 Day 18: Message reaction types
enum ReactionType {
  like,
  love,
  laugh,
  wow,
  sad,
  angry,
  thumbsUp,
  thumbsDown,
  fire,
  heart,
}

/// Message reaction model
class MessageReaction {
  final String messageId;
  final String userId;
  final String userName;
  final ReactionType reaction;
  final DateTime timestamp;

  const MessageReaction({
    required this.messageId,
    required this.userId,
    required this.userName,
    required this.reaction,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'userId': userId,
      'userName': userName,
      'reaction': reaction.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      messageId: json['messageId'],
      userId: json['userId'],
      userName: json['userName'],
      reaction: ReactionType.values.firstWhere(
        (r) => r.name == json['reaction'],
        orElse: () => ReactionType.like,
      ),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// File attachment model (Phase 2 Day 18 - behind feature flag)
class MessageAttachment {
  final String id;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String? thumbnailUrl;
  final String? downloadUrl;
  final bool isUploaded;
  final double? uploadProgress;

  const MessageAttachment({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    this.thumbnailUrl,
    this.downloadUrl,
    this.isUploaded = false,
    this.uploadProgress,
  });

  MessageAttachment copyWith({
    String? id,
    String? fileName,
    String? fileType,
    int? fileSize,
    String? thumbnailUrl,
    String? downloadUrl,
    bool? isUploaded,
    double? uploadProgress,
  }) {
    return MessageAttachment(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      isUploaded: isUploaded ?? this.isUploaded,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'thumbnailUrl': thumbnailUrl,
      'downloadUrl': downloadUrl,
      'isUploaded': isUploaded,
      'uploadProgress': uploadProgress,
    };
  }

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: json['id'],
      fileName: json['fileName'],
      fileType: json['fileType'],
      fileSize: json['fileSize'],
      thumbnailUrl: json['thumbnailUrl'],
      downloadUrl: json['downloadUrl'],
      isUploaded: json['isUploaded'] ?? false,
      uploadProgress: json['uploadProgress'],
    );
  }
}

/// Phase 2 Day 18: Enhanced Chat History Service with lazy loading and attachments
class ChatHistoryService {
  static ChatHistoryService? _instance;
  static ChatHistoryService get instance =>
      _instance ??= ChatHistoryService._();

  ChatHistoryService._();

  final LocalMessageService _localMessageService = LocalMessageService.instance;
  final SupabaseService _supabaseService = SupabaseService.instance;

  // Message reactions tracking
  final Map<String, List<MessageReaction>> _messageReactions = {};
  final StreamController<Map<String, List<MessageReaction>>>
      _reactionsStreamController =
      StreamController<Map<String, List<MessageReaction>>>.broadcast();

  // Pagination state
  final Map<String, int> _chatPageOffsets = {}; // chatId -> current offset
  final Map<String, bool> _hasMoreMessages = {}; // chatId -> has more flag
  final Map<String, bool> _isLoadingHistory = {}; // chatId -> loading state

  // Message caching for performance
  final Map<String, List<ChatMessage>> _cachedMessages = {};
  static const int _pageSize = 50;
  static const int _maxCachedMessages = 500;

  // Feature flags
  bool _reactionsEnabled = true;
  // Feature flags for Phase 2 future implementations
  // bool _attachmentsEnabled = false; // Behind feature flag for Phase 2

  /// Initialize chat history service
  Future<void> initialize() async {
    await _localMessageService.initialize();
    debugPrint('✅ ChatHistoryService initialized');
  }

  /// Phase 2 Day 18: Load chat history with pagination
  Future<List<ChatMessage>> loadChatHistory({
    required String chatId,
    int? limit,
    bool forceRefresh = false,
  }) async {
    final pageSize = limit ?? _pageSize;

    if (_isLoadingHistory[chatId] == true) {
      debugPrint('⏳ Chat history already loading for $chatId');
      return _cachedMessages[chatId] ?? [];
    }

    _isLoadingHistory[chatId] = true;

    try {
      // Get current offset for pagination
      final currentOffset = _chatPageOffsets[chatId] ?? 0;

      List<ChatMessage> messages;

      if (forceRefresh || currentOffset == 0) {
        // Fresh load - get from local storage first, then sync with server
        messages = await _loadFreshHistory(chatId, pageSize);
        _chatPageOffsets[chatId] = messages.length;
      } else {
        // Pagination load - get older messages
        messages = await _loadOlderMessages(chatId, currentOffset, pageSize);
        _chatPageOffsets[chatId] = currentOffset + messages.length;
      }

      // Update cache
      _updateMessageCache(chatId, messages, append: currentOffset > 0);

      // Check if there are more messages to load
      _hasMoreMessages[chatId] = messages.length == pageSize;

      debugPrint(
          '📚 Loaded ${messages.length} messages for chat $chatId (offset: ${_chatPageOffsets[chatId]})');
      return messages;
    } catch (e) {
      debugPrint('❌ Failed to load chat history for $chatId: $e');
      return _cachedMessages[chatId] ?? [];
    } finally {
      _isLoadingHistory[chatId] = false;
    }
  }

  /// Load fresh history (most recent messages)
  Future<List<ChatMessage>> _loadFreshHistory(String chatId, int limit) async {
    // Get from local storage first
    final localMessages = await _localMessageService.getMessagesForChat(
      chatId,
      limit: limit,
      offset: 0,
    );

    // If we have enough local messages, return them
    if (localMessages.length >= limit) {
      return localMessages;
    }

    // Otherwise, fetch from server to fill the gap
    try {
      final serverMessages = await _fetchMessagesFromServer(
        chatId: chatId,
        limit: limit,
        offset: 0,
      );

      // Merge and deduplicate
      final allMessages = _mergeAndDeduplicate(localMessages, serverMessages);

      // Save server messages locally for future offline access
      for (final message in serverMessages) {
        if (!localMessages.any((local) => local.id == message.id)) {
          await _localMessageService.saveMessageLocally(message,
              markForSync: false);
        }
      }

      return allMessages.take(limit).toList();
    } catch (e) {
      debugPrint('⚠️ Server fetch failed, returning local messages: $e');
      return localMessages;
    }
  }

  /// Load older messages for pagination
  Future<List<ChatMessage>> _loadOlderMessages(
      String chatId, int offset, int limit) async {
    // Try local storage first
    final localMessages = await _localMessageService.getMessagesForChat(
      chatId,
      limit: limit,
      offset: offset,
    );

    if (localMessages.length >= limit) {
      return localMessages;
    }

    // Fetch older messages from server
    try {
      final serverMessages = await _fetchMessagesFromServer(
        chatId: chatId,
        limit: limit,
        offset: offset,
      );

      return _mergeAndDeduplicate(localMessages, serverMessages);
    } catch (e) {
      debugPrint('⚠️ Failed to fetch older messages from server: $e');
      return localMessages;
    }
  }

  /// Fetch messages from server
  Future<List<ChatMessage>> _fetchMessagesFromServer({
    required String chatId,
    required int limit,
    required int offset,
  }) async {
    final response = await _supabaseService.client
        .from('chat_messages')
        .select('*')
        .eq('chat_id', chatId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response.map<ChatMessage>((data) {
      return ChatMessage(
        id: data['id'],
        chatId: data['chat_id'],
        senderId: data['sender_id'],
        senderName: data['sender_name'] ?? 'Unknown',
        type: MessageType.values.firstWhere(
          (t) => t.name == data['type'],
          orElse: () => MessageType.text,
        ),
        content: data['content'] ?? '',
        timestamp: DateTime.parse(data['created_at']),
        isRead: data['is_read'] ?? false,
        isSent: true,
        attachments: List<String>.from(data['attachments'] ?? []),
      );
    }).toList();
  }

  /// Merge local and server messages, removing duplicates
  List<ChatMessage> _mergeAndDeduplicate(
    List<ChatMessage> local,
    List<ChatMessage> server,
  ) {
    final messageMap = <String, ChatMessage>{};

    // Add local messages first
    for (final message in local) {
      messageMap[message.id] = message;
    }

    // Add server messages (will overwrite local if IDs match)
    for (final message in server) {
      messageMap[message.id] = message;
    }

    // Sort by timestamp
    final sortedMessages = messageMap.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return sortedMessages;
  }

  /// Update message cache efficiently
  void _updateMessageCache(String chatId, List<ChatMessage> newMessages,
      {bool append = false}) {
    if (append) {
      _cachedMessages[chatId] ??= [];
      _cachedMessages[chatId]!.addAll(newMessages);
    } else {
      _cachedMessages[chatId] = List.from(newMessages);
    }

    // Limit cache size to prevent memory issues
    if (_cachedMessages[chatId]!.length > _maxCachedMessages) {
      _cachedMessages[chatId] =
          _cachedMessages[chatId]!.take(_maxCachedMessages).toList();
    }
  }

  /// Phase 2 Day 18: Add reaction to message
  Future<void> addMessageReaction({
    required String messageId,
    required String userId,
    required String userName,
    required ReactionType reaction,
  }) async {
    if (!_reactionsEnabled) {
      debugPrint('⚠️ Message reactions are disabled');
      return;
    }

    try {
      final messageReaction = MessageReaction(
        messageId: messageId,
        userId: userId,
        userName: userName,
        reaction: reaction,
        timestamp: DateTime.now(),
      );

      // Add to local cache
      _messageReactions[messageId] ??= [];

      // Remove existing reaction from this user (users can only have one reaction per message)
      _messageReactions[messageId]!.removeWhere((r) => r.userId == userId);
      _messageReactions[messageId]!.add(messageReaction);

      // Emit update
      _reactionsStreamController.add(Map.from(_messageReactions));

      // Save to server
      await _supabaseService.client.from('message_reactions').upsert({
        'message_id': messageId,
        'user_id': userId,
        'user_name': userName,
        'reaction': reaction.name,
        'created_at': messageReaction.timestamp.toIso8601String(),
      });

      debugPrint('👍 Added ${reaction.name} reaction to message $messageId');
    } catch (e) {
      debugPrint('❌ Failed to add reaction: $e');
    }
  }

  /// Remove reaction from message
  Future<void> removeMessageReaction({
    required String messageId,
    required String userId,
  }) async {
    if (!_reactionsEnabled) return;

    try {
      // Remove from local cache
      _messageReactions[messageId]?.removeWhere((r) => r.userId == userId);

      if (_messageReactions[messageId]?.isEmpty == true) {
        _messageReactions.remove(messageId);
      }

      // Emit update
      _reactionsStreamController.add(Map.from(_messageReactions));

      // Remove from server
      await _supabaseService.client
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId);

      debugPrint('🗑️ Removed reaction from message $messageId');
    } catch (e) {
      debugPrint('❌ Failed to remove reaction: $e');
    }
  }

  /// Get reactions for a message
  List<MessageReaction> getMessageReactions(String messageId) {
    return _messageReactions[messageId] ?? [];
  }

  /// Get reaction counts grouped by type
  Map<ReactionType, int> getReactionCounts(String messageId) {
    final reactions = getMessageReactions(messageId);
    final counts = <ReactionType, int>{};

    for (final reaction in reactions) {
      counts[reaction.reaction] = (counts[reaction.reaction] ?? 0) + 1;
    }

    return counts;
  }

  /// Check if there are more messages to load
  bool hasMoreMessages(String chatId) {
    return _hasMoreMessages[chatId] ?? true;
  }

  /// Check if currently loading history
  bool isLoadingHistory(String chatId) {
    return _isLoadingHistory[chatId] ?? false;
  }

  /// Get cached message count for a chat
  int getCachedMessageCount(String chatId) {
    return _cachedMessages[chatId]?.length ?? 0;
  }

  /// Phase 2 Day 18: Search messages in chat (local search)
  Future<List<ChatMessage>> searchMessages({
    required String chatId,
    required String query,
    int limit = 50,
  }) async {
    if (query.isEmpty) return [];

    final allMessages = _cachedMessages[chatId] ?? [];
    final queryLower = query.toLowerCase();

    final matchedMessages = allMessages
        .where((message) {
          return message.content.toLowerCase().contains(queryLower) ||
              message.senderName.toLowerCase().contains(queryLower);
        })
        .take(limit)
        .toList();

    debugPrint('🔍 Found ${matchedMessages.length} messages matching "$query"');
    return matchedMessages;
  }

  /// Clear cache for a specific chat
  void clearChatCache(String chatId) {
    _cachedMessages.remove(chatId);
    _chatPageOffsets.remove(chatId);
    _hasMoreMessages.remove(chatId);
    _isLoadingHistory.remove(chatId);
    _messageReactions.removeWhere((key, value) =>
        _cachedMessages[chatId]?.any((msg) => msg.id == key) ?? false);

    debugPrint('🧹 Cleared cache for chat $chatId');
  }

  /// Clear all caches
  void clearAllCaches() {
    _cachedMessages.clear();
    _chatPageOffsets.clear();
    _hasMoreMessages.clear();
    _isLoadingHistory.clear();
    _messageReactions.clear();

    debugPrint('🧹 Cleared all chat caches');
  }

  /// Enable/disable message reactions
  void setReactionsEnabled(bool enabled) {
    _reactionsEnabled = enabled;
    debugPrint('👍 Message reactions ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Enable/disable attachments (Phase 2 Day 18 - behind feature flag)
  void setAttachmentsEnabled(bool enabled) {
    // Future implementation - Phase 2 attachment system
    // _attachmentsEnabled = enabled;
    debugPrint('📎 Message attachments ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Get chat history statistics
  Map<String, dynamic> getChatHistoryStats(String chatId) {
    return {
      'cached_messages': getCachedMessageCount(chatId),
      'current_offset': _chatPageOffsets[chatId] ?? 0,
      'has_more': hasMoreMessages(chatId),
      'is_loading': isLoadingHistory(chatId),
      'reactions_count': _messageReactions.values
          .where((reactions) => reactions.any((r) =>
              _cachedMessages[chatId]?.any((msg) => msg.id == r.messageId) ??
              false))
          .length,
    };
  }

  /// Streams for real-time updates
  Stream<Map<String, List<MessageReaction>>> get reactionsStream =>
      _reactionsStreamController.stream;

  /// Dispose service
  void dispose() {
    _reactionsStreamController.close();
    _cachedMessages.clear();
    _chatPageOffsets.clear();
    _hasMoreMessages.clear();
    _isLoadingHistory.clear();
    _messageReactions.clear();
  }
}
