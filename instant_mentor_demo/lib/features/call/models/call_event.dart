/// Defines the various signaling-level events and internal controller events
/// for a WebRTC call lifecycle.
enum CallEventType {
  joinRequested,
  joined,
  offerReceived,
  answerReceived,
  iceCandidateReceived,
  negotiationNeeded,
  participantUpdated,
  participantLeft,
  mediaError,
  callEnded,
  connectionStateChanged,
}

class CallEvent {
  final CallEventType type;
  final dynamic data;
  final DateTime timestamp;

  CallEvent(this.type, {this.data}) : timestamp = DateTime.now();
}
