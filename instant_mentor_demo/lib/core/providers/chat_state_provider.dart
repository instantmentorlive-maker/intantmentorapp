import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for chat sending status
class ChatSendingState {
  final bool isSending;
  final String? error;

  const ChatSendingState({
    this.isSending = false,
    this.error,
  });

  ChatSendingState copyWith({
    bool? isSending,
    String? error,
  }) {
    return ChatSendingState(
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

/// Notifier for managing chat sending state
class ChatSendingNotifier extends StateNotifier<ChatSendingState> {
  ChatSendingNotifier() : super(const ChatSendingState());

  void setSending(bool sending) {
    state = state.copyWith(isSending: sending);
  }

  void setError(String? error) {
    state = state.copyWith(error: error, isSending: false);
  }

  void reset() {
    state = const ChatSendingState();
  }
}

/// Provider for chat sending state - using autoDispose to prevent memory leaks
final chatSendingProvider =
    StateNotifierProvider.autoDispose<ChatSendingNotifier, ChatSendingState>(
        (ref) {
  return ChatSendingNotifier();
});

/// Provider for individual chat room states by chat ID
final chatSendingFamilyProvider = StateNotifierProvider.autoDispose
    .family<ChatSendingNotifier, ChatSendingState, String>((ref, chatId) {
  return ChatSendingNotifier();
});
