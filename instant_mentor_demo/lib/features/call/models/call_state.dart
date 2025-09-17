/// Call state enum representing all possible states of a video call
enum CallState {
  /// No active call
  idle,

  /// Initiating an outgoing call
  calling,

  /// Incoming call ringing
  ringing,

  /// Call is connecting (establishing WebRTC connection)
  connecting,

  /// Call is active and in progress
  inCall,

  /// Call is ending
  ending,

  /// Call has ended
  ended,

  /// Call failed due to error
  failed,

  /// Call was rejected by the callee
  rejected,

  /// Call was missed (no answer within timeout)
  missed,

  /// Call was cancelled by the caller
  cancelled;

  /// Returns true if the call is active (connecting or in progress)
  bool get isActive => this == connecting || this == inCall;

  /// Returns true if the call is finished (ended, failed, rejected, missed, cancelled)
  bool get isFinished =>
      [ended, failed, rejected, missed, cancelled].contains(this);

  /// Returns true if the call is ongoing (calling, ringing, connecting, inCall)
  bool get isOngoing => [calling, ringing, connecting, inCall].contains(this);
}

/// Call statistics for monitoring connection quality
class CallStats {
  final int bandwidth;
  final int packetsLost;
  final int packetsReceived;
  final double connectionQuality; // 0.0 to 1.0
  final int roundTripTime; // in milliseconds
  final String codec;
  final String resolution;
  final int frameRate;

  const CallStats({
    this.bandwidth = 0,
    this.packetsLost = 0,
    this.packetsReceived = 0,
    this.connectionQuality = 0.0,
    this.roundTripTime = 0,
    this.codec = '',
    this.resolution = '',
    this.frameRate = 0,
  });

  bool get hasGoodConnection => connectionQuality > 0.7;
  bool get hasPoorConnection => connectionQuality < 0.3;
}
