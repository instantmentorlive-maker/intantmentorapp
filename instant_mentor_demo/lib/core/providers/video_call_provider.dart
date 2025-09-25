import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global video call state that persists throughout the app
class VideoCallState {
  final bool isActive;
  final bool isMinimized;
  final String? mentorId;
  final String? mentorName;
  final String? sessionId;

  const VideoCallState({
    this.isActive = false,
    this.isMinimized = false,
    this.mentorId,
    this.mentorName,
    this.sessionId,
  });

  VideoCallState copyWith({
    bool? isActive,
    bool? isMinimized,
    String? mentorId,
    String? mentorName,
    String? sessionId,
  }) {
    return VideoCallState(
      isActive: isActive ?? this.isActive,
      isMinimized: isMinimized ?? this.isMinimized,
      mentorId: mentorId ?? this.mentorId,
      mentorName: mentorName ?? this.mentorName,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  @override
  String toString() {
    return 'VideoCallState(isActive: $isActive, isMinimized: $isMinimized, mentorId: $mentorId, mentorName: $mentorName, sessionId: $sessionId)';
  }
}

/// Global video call state notifier
class VideoCallNotifier extends StateNotifier<VideoCallState> {
  VideoCallNotifier() : super(const VideoCallState());

  /// Start a video call with a mentor
  void startCall({
    required String mentorId,
    required String mentorName,
    String? sessionId,
  }) {
    state = state.copyWith(
      isActive: true,
      isMinimized: false,
      mentorId: mentorId,
      mentorName: mentorName,
      sessionId: sessionId,
    );
  }

  /// Minimize the current call
  void minimizeCall() {
    if (state.isActive) {
      state = state.copyWith(isMinimized: true);
    }
  }

  /// Maximize/restore the current call
  void maximizeCall() {
    if (state.isActive) {
      state = state.copyWith(isMinimized: false);
    }
  }

  /// End the current call completely
  void endCall() {
    state = const VideoCallState();
  }

  /// Check if there's an active call
  bool get hasActiveCall => state.isActive;

  /// Check if the call is minimized
  bool get isCallMinimized => state.isActive && state.isMinimized;

  /// Get current call details
  VideoCallState get currentCall => state;
}

/// Global provider for video call state
final videoCallProvider =
    StateNotifierProvider<VideoCallNotifier, VideoCallState>((ref) {
  return VideoCallNotifier();
});
