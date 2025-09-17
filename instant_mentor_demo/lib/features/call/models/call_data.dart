import 'call_state.dart';
import 'media_state.dart';

/// Data model representing a video call session
class CallData {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerAvatar;
  final String calleeId;
  final String calleeName;
  final String calleeAvatar;
  final CallState state;
  final MediaState mediaState;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? duration;
  final String? errorMessage;
  final CallStats? stats;
  final bool isIncoming;

  const CallData({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar = '',
    required this.calleeId,
    required this.calleeName,
    this.calleeAvatar = '',
    required this.state,
    this.mediaState = const MediaState(),
    required this.startTime,
    this.endTime,
    this.duration,
    this.errorMessage,
    this.stats,
    required this.isIncoming,
  });

  /// Creates a new outgoing call
  factory CallData.outgoing({
    required String callerId,
    required String callerName,
    String callerAvatar = '',
    required String calleeId,
    required String calleeName,
    String calleeAvatar = '',
  }) {
    return CallData(
      callId: 'call_${DateTime.now().millisecondsSinceEpoch}',
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      calleeId: calleeId,
      calleeName: calleeName,
      calleeAvatar: calleeAvatar,
      state: CallState.calling,
      startTime: DateTime.now(),
      isIncoming: false,
    );
  }

  /// Creates a new incoming call
  factory CallData.incoming({
    required String callId,
    required String callerId,
    required String callerName,
    String callerAvatar = '',
    required String calleeId,
    required String calleeName,
    String calleeAvatar = '',
  }) {
    return CallData(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      calleeId: calleeId,
      calleeName: calleeName,
      calleeAvatar: calleeAvatar,
      state: CallState.ringing,
      startTime: DateTime.now(),
      isIncoming: true,
    );
  }

  /// Returns the display name of the other participant
  String getOtherParticipantName(String currentUserId) {
    return currentUserId == callerId ? calleeName : callerName;
  }

  /// Returns the avatar of the other participant
  String getOtherParticipantAvatar(String currentUserId) {
    return currentUserId == callerId ? calleeAvatar : callerAvatar;
  }

  /// Returns the ID of the other participant
  String getOtherParticipantId(String currentUserId) {
    return currentUserId == callerId ? calleeId : callerId;
  }

  CallData copyWith({
    String? callId,
    String? callerId,
    String? callerName,
    String? callerAvatar,
    String? calleeId,
    String? calleeName,
    String? calleeAvatar,
    CallState? state,
    MediaState? mediaState,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    String? errorMessage,
    CallStats? stats,
    bool? isIncoming,
  }) {
    return CallData(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      calleeId: calleeId ?? this.calleeId,
      calleeName: calleeName ?? this.calleeName,
      calleeAvatar: calleeAvatar ?? this.calleeAvatar,
      state: state ?? this.state,
      mediaState: mediaState ?? this.mediaState,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      errorMessage: errorMessage ?? this.errorMessage,
      stats: stats ?? this.stats,
      isIncoming: isIncoming ?? this.isIncoming,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CallData &&
        other.callId == callId &&
        other.callerId == callerId &&
        other.calleeId == calleeId &&
        other.state == state;
  }

  @override
  int get hashCode {
    return Object.hash(callId, callerId, calleeId, state);
  }

  @override
  String toString() {
    return 'CallData(callId: $callId, caller: $callerName, callee: $calleeName, state: $state)';
  }
}
