import 'dart:async';

/// Minimal, clean stub for video calling. All Agora-specific code removed.
/// Provides just enough structure for the rest of the app to compile & run.
class VideoCallingService {
  bool _isInitialized = false;
  bool _isInCall = false;
  bool _isLocalVideoEnabled = true;
  bool _isLocalAudioEnabled = true;
  String? _currentChannelName;
  int? _localUserId;
  Timer? _qualityTimer;

  final _eventController = StreamController<VideoCallEvent>.broadcast();
  final _qualityController = StreamController<SimpleQualitySample>.broadcast();

  // Streams
  Stream<VideoCallEvent> get eventStream => _eventController.stream;
  Stream<SimpleQualitySample> get qualityStream => _qualityController.stream;

  // Getters
  bool get isInCall => _isInCall;
  bool get isLocalVideoEnabled => _isLocalVideoEnabled;
  bool get isLocalAudioEnabled => _isLocalAudioEnabled;
  String? get currentChannelName => _currentChannelName;
  int? get localUserId => _localUserId;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = true;
    _emit(VideoCallEventType.initialized, 'Video service initialized');
    return true;
  }

  Future<bool> requestPermissions() async => true; // No-op in stub

  Future<bool> joinCall(
      {required String channelName, required int userId, String? token}) async {
    if (!_isInitialized) await initialize();
    _isInCall = true;
    _currentChannelName = channelName;
    _localUserId = userId;
    _emit(VideoCallEventType.callJoined, 'Joined channel $channelName', data: {
      'channel': channelName,
      'userId': userId,
    });
    _startQualityFeed();
    return true;
  }

  Future<void> leaveCall() async {
    if (!_isInCall) return;
    _isInCall = false;
    _emit(VideoCallEventType.callEnded,
        'Left channel ${_currentChannelName ?? ''}');
    _currentChannelName = null;
    _qualityTimer?.cancel();
  }

  Future<void> toggleVideo() async {
    _isLocalVideoEnabled = !_isLocalVideoEnabled;
    _emit(VideoCallEventType.videoToggled,
        'Video ${_isLocalVideoEnabled ? 'enabled' : 'disabled'}',
        data: {
          'enabled': _isLocalVideoEnabled,
        });
  }

  Future<void> toggleAudio() async {
    _isLocalAudioEnabled = !_isLocalAudioEnabled;
    _emit(VideoCallEventType.audioToggled,
        'Audio ${_isLocalAudioEnabled ? 'unmuted' : 'muted'}',
        data: {
          'enabled': _isLocalAudioEnabled,
        });
  }

  Future<void> switchCamera() async {
    _emit(VideoCallEventType.cameraSwitched, 'Camera switched (stub)');
  }

  Future<bool> startCallRecording() async {
    _emit(VideoCallEventType.recordingStarted, 'Recording started (stub)');
    return true;
  }

  Future<bool> stopCallRecording() async {
    _emit(VideoCallEventType.recordingStopped, 'Recording stopped (stub)');
    return true;
  }

  void handleCallError(String message) =>
      _emit(VideoCallEventType.callError, message);

  void _startQualityFeed() {
    _qualityTimer?.cancel();
    _qualityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isInCall) return;
      _qualityController.add(SimpleQualitySample(
        timestamp: DateTime.now(),
        latencyMs: 60 + DateTime.now().second % 40,
        jitterMs: 5 + DateTime.now().second % 8,
        packetLossPct: (DateTime.now().millisecond % 3).toDouble(),
      ));
    });
  }

  void _emit(VideoCallEventType type, String msg,
      {Map<String, dynamic>? data}) {
    _eventController.add(VideoCallEvent(type: type, message: msg, data: data));
  }

  Future<void> dispose() async {
    await leaveCall();
    await _eventController.close();
    await _qualityController.close();
    _isInitialized = false;
  }
}

class VideoCallEvent {
  final VideoCallEventType type;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  VideoCallEvent({
    required this.type,
    required this.message,
    this.data,
  }) : timestamp = DateTime.now();
}

// Consolidated enum containing all variants referenced across the codebase
enum VideoCallEventType {
  initialized,
  permissionDenied,
  callJoined,
  callEnded,
  callFailed,
  callError,
  userJoined,
  userLeft,
  remoteVideoStateChanged,
  remoteAudioStateChanged,
  videoToggled,
  audioToggled,
  cameraSwitched,
  recordingStarted,
  recordingStopped,
  error, // legacy / generic
}

// Very lightweight quality sample for simple UI display
class SimpleQualitySample {
  final DateTime timestamp;
  final int latencyMs;
  final int jitterMs;
  final double packetLossPct;

  SimpleQualitySample({
    required this.timestamp,
    required this.latencyMs,
    required this.jitterMs,
    required this.packetLossPct,
  });
}
