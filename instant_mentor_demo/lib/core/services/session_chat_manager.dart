import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat.dart';
import 'chat_service.dart';

/// Manages chat persistence specifically for live session screens
/// Handles proper loading, saving, and synchronization of chat messages
class SessionChatManager {
  static final SessionChatManager _instance = SessionChatManager._internal();
  factory SessionChatManager() => _instance;
  SessionChatManager._internal();

  // Cache for active session chats
  final Map<String, List<ChatMessage>> _sessionChats = {};
  final Map<String, String> _sessionChatThreads = {};
  final Map<String, Map<String, dynamic>> _sessionInfo =
      {}; // Store session metadata

  /// Initialize chat for a session between student and mentor
  Future<List<ChatMessage>> initializeSessionChat({
    required String sessionKey,
    required String studentId,
    required String mentorId,
    String? mentorName,
  }) async {
    debugPrint(
        '🚀 SessionChatManager: Initializing session chat for $sessionKey');

    try {
      // Check if we already have this session cached
      if (_sessionChats.containsKey(sessionKey)) {
        debugPrint(
            '📱 Using cached messages for session $sessionKey: ${_sessionChats[sessionKey]!.length} messages');
        return List.from(_sessionChats[sessionKey]!);
      }

      // Store the session info for later use in message persistence
      _sessionInfo[sessionKey] = {
        'studentId': studentId,
        'mentorId': mentorId,
        'mentorName': mentorName,
      };

      final chatService = ChatService.instance;

      // Get or create chat thread
      final chatThreadId = await chatService.createOrGetThread(
        studentId: studentId,
        mentorId: mentorId,
        subject: 'Live Session Chat',
      );

      _sessionChatThreads[sessionKey] = chatThreadId;
      debugPrint('💬 Chat thread ID for session $sessionKey: $chatThreadId');

      // Load existing messages from database
      final messages = await chatService.fetchMessages(chatThreadId);
      debugPrint(
          '📦 Loaded ${messages.length} messages from database for session $sessionKey');

      // If no messages exist, add welcome messages
      List<ChatMessage> finalMessages = List.from(messages);
      if (finalMessages.isEmpty) {
        debugPrint('📝 No existing messages, adding welcome messages');
        finalMessages = _createWelcomeMessages(
          chatId: chatThreadId,
          mentorId: mentorId,
          mentorName: mentorName ?? 'Demo Mentor',
        );
      }

      // Cache the messages
      _sessionChats[sessionKey] = finalMessages;
      debugPrint(
          '✅ Session chat initialized with ${finalMessages.length} total messages');

      return List.from(finalMessages);
    } catch (e) {
      debugPrint('❌ Failed to initialize session chat: $e');

      // Fallback to welcome messages only
      final welcomeMessages = _createWelcomeMessages(
        chatId: 'demo_$sessionKey',
        mentorId: mentorId,
        mentorName: mentorName ?? 'Demo Mentor',
      );

      _sessionChats[sessionKey] = welcomeMessages;
      return List.from(welcomeMessages);
    }
  }

  /// Send a message in a session chat
  Future<ChatMessage> sendSessionMessage({
    required String sessionKey,
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    debugPrint('💾 SessionChatManager: Sending message in session $sessionKey');

    // Create local message immediately
    final localMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: _sessionChatThreads[sessionKey] ?? 'demo_$sessionKey',
      senderId: senderId,
      senderName: senderName,
      type: MessageType.text,
      content: content,
      timestamp: DateTime.now(),
    );

    // Add to local cache immediately
    if (_sessionChats.containsKey(sessionKey)) {
      _sessionChats[sessionKey]!.add(localMessage);
    }

    // Try to save to database
    try {
      final chatThreadId = _sessionChatThreads[sessionKey];
      if (chatThreadId != null && !chatThreadId.startsWith('demo_')) {
        final chatService = ChatService.instance;
        await chatService.sendTextMessage(
          chatId: chatThreadId,
          senderId: senderId,
          senderName: senderName,
          content: content,
        );

        // Update message as sent
        final updatedMessage = localMessage.copyWith(isSent: true);
        if (_sessionChats.containsKey(sessionKey)) {
          final messages = _sessionChats[sessionKey]!;
          final index = messages.indexWhere((m) => m.id == localMessage.id);
          if (index != -1) {
            messages[index] = updatedMessage;
          }
        }

        debugPrint('✅ Message saved to database successfully');
        return updatedMessage;
      } else {
        debugPrint(
            '⚠️ No real chat thread available, using local storage only');
        return localMessage;
      }
    } catch (e) {
      debugPrint('❌ Failed to save message to database: $e');
      return localMessage;
    }
  }

  /// Get messages for a session
  List<ChatMessage> getSessionMessages(String sessionKey) {
    return List.from(_sessionChats[sessionKey] ?? []);
  }

  /// Refresh messages from database for a session
  Future<List<ChatMessage>> refreshSessionMessages(String sessionKey) async {
    final chatThreadId = _sessionChatThreads[sessionKey];
    if (chatThreadId == null || chatThreadId.startsWith('demo_')) {
      debugPrint('⚠️ No real chat thread to refresh for session $sessionKey');
      return getSessionMessages(sessionKey);
    }

    try {
      debugPrint('🔄 Refreshing messages for session $sessionKey');
      final chatService = ChatService.instance;
      final messages = await chatService.fetchMessages(chatThreadId);

      // Update cache
      _sessionChats[sessionKey] = List.from(messages);
      debugPrint(
          '✅ Refreshed ${messages.length} messages for session $sessionKey');

      return List.from(messages);
    } catch (e) {
      debugPrint('❌ Failed to refresh messages: $e');
      return getSessionMessages(sessionKey);
    }
  }

  /// Save all cached messages to database before logout/refresh
  Future<void> saveAllPendingMessages() async {
    debugPrint(
        '💾 SessionChatManager: Saving all pending messages to database');

    for (final sessionKey in _sessionChats.keys) {
      try {
        final messages = _sessionChats[sessionKey] ?? [];
        final chatThreadId = _sessionChatThreads[sessionKey];

        if (chatThreadId != null && !chatThreadId.startsWith('demo_')) {
          final chatService = ChatService.instance;

          // Save each unsent message
          for (final message in messages) {
            if (!message.isSent) {
              await chatService.sendTextMessage(
                chatId: chatThreadId,
                senderId: message.senderId,
                senderName: message.senderName,
                content: message.content,
              );
              debugPrint('💾 Saved pending message ${message.id} to database');
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Failed to save messages for session $sessionKey: $e');
      }
    }
  }

  /// Clear session cache (for memory management)
  void clearSessionCache(String sessionKey) {
    _sessionChats.remove(sessionKey);
    _sessionChatThreads.remove(sessionKey);
    debugPrint('🗑️ Cleared cache for session $sessionKey');
  }

  /// Create welcome messages for a new chat
  List<ChatMessage> _createWelcomeMessages({
    required String chatId,
    required String mentorId,
    required String mentorName,
  }) {
    final now = DateTime.now();
    return [
      ChatMessage(
        id: 'welcome_1',
        chatId: chatId,
        senderId: mentorId,
        senderName: mentorName,
        type: MessageType.text,
        content: 'Welcome to your mentoring session!',
        timestamp: now.subtract(const Duration(minutes: 2)),
        isSent: true,
      ),
      ChatMessage(
        id: 'welcome_2',
        chatId: chatId,
        senderId: mentorId,
        senderName: mentorName,
        type: MessageType.text,
        content: 'Feel free to ask any questions you have.',
        timestamp: now.subtract(const Duration(minutes: 1)),
        isSent: true,
      ),
      ChatMessage(
        id: 'welcome_3',
        chatId: chatId,
        senderId: mentorId,
        senderName: mentorName,
        type: MessageType.text,
        content: "I'm here to help you learn and grow.",
        timestamp: now,
        isSent: true,
      ),
    ];
  }
}
