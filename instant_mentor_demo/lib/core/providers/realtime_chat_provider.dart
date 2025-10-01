import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat.dart';

/// Chat message status enum
enum MessageStatus {
  sending,
  sent,
  failed,
}

/// State for realtime chat
class RealtimeChatState {
  final List<ChatMessage> messages;
  final bool showTypingIndicator;
  final bool isTyping;
  final String? error;

  const RealtimeChatState({
    this.messages = const [],
    this.showTypingIndicator = false,
    this.isTyping = false,
    this.error,
  });

  RealtimeChatState copyWith({
    List<ChatMessage>? messages,
    bool? showTypingIndicator,
    bool? isTyping,
    String? error,
  }) {
    return RealtimeChatState(
      messages: messages ?? this.messages,
      showTypingIndicator: showTypingIndicator ?? this.showTypingIndicator,
      isTyping: isTyping ?? this.isTyping,
      error: error ?? this.error,
    );
  }
}

/// Realtime chat state notifier
class RealtimeChatNotifier extends StateNotifier<RealtimeChatState> {
  final String receiverId;

  RealtimeChatNotifier(this.receiverId) : super(const RealtimeChatState()) {
    _loadFromPrefs();
  }

  String get _prefsKey =>
      'realtime_chat_messages_v2_$receiverId'; // More persistent key

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final messages = decoded
          .map((e) => ChatMessage.fromJson(
              Map<String, dynamic>.from(e as Map<String, dynamic>)))
          .toList();
      state = state.copyWith(messages: messages);
    } catch (e) {
      // If anything fails, keep state as empty but don't crash
      debugPrint('Failed to load chat messages from prefs: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          jsonEncode(state.messages.map((m) => m.toJson()).toList());
      await prefs.setString(_prefsKey, encoded);
    } catch (e) {
      debugPrint('Failed to save chat messages to prefs: $e');
    }
  }

  Future<void> _removeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      debugPrint('Failed to remove chat messages from prefs: $e');
    }
  }

  void addMessage(ChatMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
    );
    _saveToPrefs();
  }

  void updateMessage(String messageId, ChatMessage updatedMessage) {
    final messages = List<ChatMessage>.from(state.messages);
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      messages[index] = updatedMessage;
      state = state.copyWith(messages: messages);
      _saveToPrefs();
    }
  }

  void setTypingIndicator(bool showing) {
    state = state.copyWith(showTypingIndicator: showing);
  }

  void setIsTyping(bool typing) {
    state = state.copyWith(isTyping: typing);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void clearMessages() {
    state = state.copyWith(messages: []);
    // Remove from SharedPreferences instead of saving empty list
    _removeFromPrefs();
  }

  void reset() {
    state = const RealtimeChatState();
    _saveToPrefs();
  }
}

/// Provider for realtime chat state by receiver ID
final realtimeChatProvider = StateNotifierProvider.family<RealtimeChatNotifier,
    RealtimeChatState, String>((ref, receiverId) {
  return RealtimeChatNotifier(receiverId);
});

/// Simple providers for individual chat states
final typingIndicatorProvider =
    StateProvider.autoDispose.family<bool, String>((ref, chatId) => false);
final isTypingProvider =
    StateProvider.autoDispose.family<bool, String>((ref, chatId) => false);
