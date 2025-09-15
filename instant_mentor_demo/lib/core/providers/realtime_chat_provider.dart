import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  RealtimeChatNotifier() : super(const RealtimeChatState());

  void addMessage(ChatMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
    );
  }

  void updateMessage(String messageId, ChatMessage updatedMessage) {
    final messages = List<ChatMessage>.from(state.messages);
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      messages[index] = updatedMessage;
      state = state.copyWith(messages: messages);
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
  }

  void reset() {
    state = const RealtimeChatState();
  }
}

/// Provider for realtime chat state by receiver ID
final realtimeChatProvider = StateNotifierProvider.autoDispose
    .family<RealtimeChatNotifier, RealtimeChatState, String>((ref, receiverId) {
  return RealtimeChatNotifier();
});

/// Simple providers for individual chat states
final typingIndicatorProvider =
    StateProvider.autoDispose.family<bool, String>((ref, chatId) => false);
final isTypingProvider =
    StateProvider.autoDispose.family<bool, String>((ref, chatId) => false);
