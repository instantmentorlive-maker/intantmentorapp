import 'call_data.dart';

/// Call history status enum
enum CallHistoryStatus {
  answered,
  missed,
  failed,
  rejected,
  cancelled;

  String get displayName {
    switch (this) {
      case answered:
        return 'Answered';
      case missed:
        return 'Missed';
      case failed:
        return 'Failed';
      case rejected:
        return 'Rejected';
      case cancelled:
        return 'Cancelled';
    }
  }
}

/// Model for storing call history in Supabase
class CallHistory {
  final String id;
  final String callerId;
  final String callerName;
  final String callerAvatar;
  final String calleeId;
  final String calleeName;
  final String calleeAvatar;
  final CallHistoryStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? duration;
  final String? failureReason;
  final DateTime createdAt;

  const CallHistory({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerAvatar = '',
    required this.calleeId,
    required this.calleeName,
    this.calleeAvatar = '',
    required this.status,
    required this.startTime,
    this.endTime,
    this.duration,
    this.failureReason,
    required this.createdAt,
  });

  /// Creates a call history record from call data
  factory CallHistory.fromCallData(
    CallData callData,
    CallHistoryStatus status, {
    DateTime? endTime,
    Duration? duration,
    String? failureReason,
  }) {
    return CallHistory(
      id: callData.callId,
      callerId: callData.callerId,
      callerName: callData.callerName,
      callerAvatar: callData.callerAvatar,
      calleeId: callData.calleeId,
      calleeName: callData.calleeName,
      calleeAvatar: callData.calleeAvatar,
      status: status,
      startTime: callData.startTime,
      endTime: endTime,
      duration: duration,
      failureReason: failureReason,
      createdAt: DateTime.now(),
    );
  }

  /// Creates from Supabase JSON
  factory CallHistory.fromJson(Map<String, dynamic> json) {
    return CallHistory(
      id: json['id'] as String,
      callerId: json['caller_id'] as String,
      callerName: json['caller_name'] as String,
      callerAvatar: json['caller_avatar'] as String? ?? '',
      calleeId: json['callee_id'] as String,
      calleeName: json['callee_name'] as String,
      calleeAvatar: json['callee_avatar'] as String? ?? '',
      status: CallHistoryStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => CallHistoryStatus.failed,
      ),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      duration: json['duration_seconds'] != null
          ? Duration(seconds: json['duration_seconds'] as int)
          : null,
      failureReason: json['failure_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converts to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caller_id': callerId,
      'caller_name': callerName,
      'caller_avatar': callerAvatar.isEmpty ? null : callerAvatar,
      'callee_id': calleeId,
      'callee_name': calleeName,
      'callee_avatar': calleeAvatar.isEmpty ? null : calleeAvatar,
      'status': status.name,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_seconds': duration?.inSeconds,
      'failure_reason': failureReason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Returns the display name of the other participant
  String getOtherParticipantName(String currentUserId) {
    return currentUserId == callerId ? calleeName : callerName;
  }

  /// Returns the avatar of the other participant
  String getOtherParticipantAvatar(String currentUserId) {
    return currentUserId == callerId ? calleeAvatar : callerAvatar;
  }

  /// Returns whether this was an incoming call for the current user
  bool isIncoming(String currentUserId) {
    return currentUserId == calleeId;
  }

  /// Returns whether this was an outgoing call for the current user
  bool isOutgoing(String currentUserId) {
    return currentUserId == callerId;
  }

  /// Returns a formatted duration string
  String get formattedDuration {
    if (duration == null) return '';

    final hours = duration!.inHours;
    final minutes = duration!.inMinutes % 60;
    final seconds = duration!.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CallHistory &&
        other.id == id &&
        other.callerId == callerId &&
        other.calleeId == calleeId;
  }

  @override
  int get hashCode {
    return Object.hash(id, callerId, calleeId);
  }

  @override
  String toString() {
    return 'CallHistory(id: $id, caller: $callerName, callee: $calleeName, status: $status)';
  }
}
