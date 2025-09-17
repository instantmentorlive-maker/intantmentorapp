/// Types of signaling messages for WebRTC communication
enum SignalingMessageType {
  /// Initiating a call
  callOffer,

  /// Responding to a call offer
  callAnswer,

  /// ICE candidate for connection establishment
  iceCandidate,

  /// Rejecting an incoming call
  callReject,

  /// Ending an active call
  callEnd,

  /// Cancelling an outgoing call
  callCancel,

  /// Call timeout notification
  callTimeout,

  /// Heartbeat to keep connection alive
  heartbeat;
}

/// Signaling message for WebRTC peer-to-peer communication
class SignalingMessage {
  final SignalingMessageType type;
  final String callId;
  final String fromUserId;
  final String toUserId;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const SignalingMessage({
    required this.type,
    required this.callId,
    required this.fromUserId,
    required this.toUserId,
    this.data,
    required this.timestamp,
  });

  /// Creates a call offer message
  factory SignalingMessage.callOffer({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required Map<String, dynamic> sdp,
    required String callerName,
    String callerAvatar = '',
  }) {
    return SignalingMessage(
      type: SignalingMessageType.callOffer,
      callId: callId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      data: {
        'sdp': sdp,
        'callerName': callerName,
        'callerAvatar': callerAvatar,
      },
      timestamp: DateTime.now(),
    );
  }

  /// Creates a call answer message
  factory SignalingMessage.callAnswer({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required Map<String, dynamic> sdp,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.callAnswer,
      callId: callId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      data: {'sdp': sdp},
      timestamp: DateTime.now(),
    );
  }

  /// Creates an ICE candidate message
  factory SignalingMessage.iceCandidate({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required Map<String, dynamic> candidate,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.iceCandidate,
      callId: callId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      data: {'candidate': candidate},
      timestamp: DateTime.now(),
    );
  }

  /// Creates a call reject message
  factory SignalingMessage.callReject({
    required String callId,
    required String fromUserId,
    required String toUserId,
    String? reason,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.callReject,
      callId: callId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      data: reason != null ? {'reason': reason} : null,
      timestamp: DateTime.now(),
    );
  }

  /// Creates a call end message
  factory SignalingMessage.callEnd({
    required String callId,
    required String fromUserId,
    required String toUserId,
    String? reason,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.callEnd,
      callId: callId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      data: reason != null ? {'reason': reason} : null,
      timestamp: DateTime.now(),
    );
  }

  /// Creates a call cancel message
  factory SignalingMessage.callCancel({
    required String callId,
    required String fromUserId,
    required String toUserId,
  }) {
    return SignalingMessage(
      type: SignalingMessageType.callCancel,
      callId: callId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      timestamp: DateTime.now(),
    );
  }

  /// Creates from JSON (for Supabase Realtime)
  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: SignalingMessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => SignalingMessageType.heartbeat,
      ),
      callId: json['call_id'] as String,
      fromUserId: json['from_user_id'] as String,
      toUserId: json['to_user_id'] as String,
      data: json['data'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Converts to JSON (for Supabase Realtime)
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'call_id': callId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SignalingMessage &&
        other.type == type &&
        other.callId == callId &&
        other.fromUserId == fromUserId &&
        other.toUserId == toUserId;
  }

  @override
  int get hashCode {
    return Object.hash(type, callId, fromUserId, toUserId);
  }

  @override
  String toString() {
    return 'SignalingMessage(type: $type, callId: $callId, from: $fromUserId, to: $toUserId)';
  }
}
