import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for help request form
class HelpRequestState {
  final String subject;
  final String message;
  final String urgency;
  final bool isLoading;
  final String? error;

  const HelpRequestState({
    this.subject = '',
    this.message = '',
    this.urgency = 'medium',
    this.isLoading = false,
    this.error,
  });

  HelpRequestState copyWith({
    String? subject,
    String? message,
    String? urgency,
    bool? isLoading,
    String? error,
  }) {
    return HelpRequestState(
      subject: subject ?? this.subject,
      message: message ?? this.message,
      urgency: urgency ?? this.urgency,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Notifier for managing help request state
class HelpRequestNotifier extends StateNotifier<HelpRequestState> {
  HelpRequestNotifier() : super(const HelpRequestState());

  void updateSubject(String subject) {
    state = state.copyWith(subject: subject);
  }

  void updateMessage(String message) {
    state = state.copyWith(message: message);
  }

  void updateUrgency(String urgency) {
    state = state.copyWith(urgency: urgency);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void clearForm() {
    state = const HelpRequestState();
  }

  void quickRequest(String subject, String message) {
    state = state.copyWith(
      subject: subject,
      message: message,
    );
  }
}

/// Provider for help request state
final helpRequestProvider =
    StateNotifierProvider.autoDispose<HelpRequestNotifier, HelpRequestState>(
        (ref) {
  return HelpRequestNotifier();
});
