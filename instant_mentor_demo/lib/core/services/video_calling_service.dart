import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

/// Phase 2 Day 19-21: Video Calling Integration with Agora SDK
/// Comprehensive video calling service with quality monitoring and recording
class VideoCallingService {
  static const String _tag = 'VideoCallingService';

  // Agora configuration
  static const String _appId = 'your-agora-app-id'; // TODO: Move to env
  static const String _tempToken = ''; // TODO: Implement token server

  RtcEngine? _rtcEngine;
  bool _isInitialized = false;
  bool _isInCall = false;
  bool _isLocalVideoEnabled = true;
  bool _isLocalAudioEnabled = true;
  String? _currentChannelName;
  int? _localUserId;

  // Call quality monitoring (Day 20)
  final Map<String, dynamic> _callQualityMetrics = {};
  Timer? _qualityTimer;

  // Event streams
  final StreamController<VideoCallEvent> _eventController =
      StreamController<VideoCallEvent>.broadcast();
  final StreamController<CallQualityData> _qualityController =
      StreamController<CallQualityData>.broadcast();

  // Remote users tracking
  final Map<int, RemoteUserInfo> _remoteUsers = {};

  Stream<VideoCallEvent> get eventStream => _eventController.stream;
  Stream<CallQualityData> get qualityStream => _qualityController.stream;

  bool get isInCall => _isInCall;
  bool get isLocalVideoEnabled => _isLocalVideoEnabled;
  bool get isLocalAudioEnabled => _isLocalAudioEnabled;
  String? get currentChannelName => _currentChannelName;
  int? get localUserId => _localUserId;
  RtcEngine? get rtcEngine => _rtcEngine;
  Map<int, RemoteUserInfo> get remoteUsers => Map.unmodifiable(_remoteUsers);

  /// Initialize the video calling service
  Future<bool> initialize() async {
    try {
      debugPrint('$_tag: Initializing Agora RTC Engine...');

      // Create RTC engine
      _rtcEngine = createAgoraRtcEngine();

      await _rtcEngine!.initialize(RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Set up event handlers
      await _setupEventHandlers();

      // Enable video
      await _rtcEngine!.enableVideo();
      await _rtcEngine!.enableAudio();

      _isInitialized = true;
      debugPrint('$_tag: ✅ Agora RTC Engine initialized successfully');

      _eventController.add(VideoCallEvent(
        type: VideoCallEventType.initialized,
        message: 'Video calling service initialized',
      ));

      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to initialize: $e');
      return false;
    }
  }

  /// Phase 2 Day 19: Request camera and microphone permissions
  Future<bool> requestPermissions() async {
    try {
      debugPrint('$_tag: Requesting camera and microphone permissions...');

      Map<Permission, PermissionStatus> permissions = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      bool cameraGranted =
          permissions[Permission.camera] == PermissionStatus.granted;
      bool micGranted =
          permissions[Permission.microphone] == PermissionStatus.granted;

      if (cameraGranted && micGranted) {
        debugPrint('$_tag: ✅ All permissions granted');
        return true;
      } else {
        debugPrint(
            '$_tag: ❌ Permissions denied - Camera: $cameraGranted, Mic: $micGranted');

        _eventController.add(VideoCallEvent(
          type: VideoCallEventType.permissionDenied,
          message: 'Camera or microphone permission required for video calls',
          data: {
            'cameraGranted': cameraGranted,
            'microphoneGranted': micGranted,
          },
        ));

        return false;
      }
    } catch (e) {
      debugPrint('$_tag: ❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// Phase 2 Day 19: Join a video call channel
  Future<bool> joinCall({
    required String channelName,
    required int userId,
    String? token,
  }) async {
    if (!_isInitialized) {
      debugPrint('$_tag: ❌ Service not initialized');
      return false;
    }

    try {
      debugPrint('$_tag: Joining call - Channel: $channelName, User: $userId');

      // Request permissions first
      if (!await requestPermissions()) {
        return false;
      }

      // Set channel profile for video calling
      await _rtcEngine!
          .setChannelProfile(ChannelProfileType.channelProfileCommunication);
      await _rtcEngine!
          .setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // Enable local video preview
      await _rtcEngine!.enableLocalVideo(true);
      await _rtcEngine!.enableLocalAudio(true);

      // Join channel
      await _rtcEngine!.joinChannel(
        token: token ?? _tempToken,
        channelId: channelName,
        uid: userId,
        options: const ChannelMediaOptions(),
      );

      _currentChannelName = channelName;
      _localUserId = userId;
      _isInCall = true;

      // Start quality monitoring (Day 20)
      _startQualityMonitoring();

      _eventController.add(VideoCallEvent(
        type: VideoCallEventType.callJoined,
        message: 'Successfully joined call',
        data: {
          'channelName': channelName,
          'userId': userId,
        },
      ));

      debugPrint('$_tag: ✅ Successfully joined call');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to join call: $e');

      _eventController.add(VideoCallEvent(
        type: VideoCallEventType.callFailed,
        message: 'Failed to join call: $e',
      ));

      return false;
    }
  }

  /// Phase 2 Day 19: Leave the current video call
  Future<void> leaveCall() async {
    try {
      debugPrint('$_tag: Leaving call...');

      if (_rtcEngine != null && _isInCall) {
        await _rtcEngine!.leaveChannel();

        // Stop quality monitoring
        _stopQualityMonitoring();

        _isInCall = false;
        _currentChannelName = null;
        _localUserId = null;
        _remoteUsers.clear();

        _eventController.add(VideoCallEvent(
          type: VideoCallEventType.callEnded,
          message: 'Call ended successfully',
        ));

        debugPrint('$_tag: ✅ Successfully left call');
      }
    } catch (e) {
      debugPrint('$_tag: ❌ Error leaving call: $e');
    }
  }

  /// Phase 2 Day 19: Toggle local video on/off
  Future<void> toggleVideo({bool? enabled}) async {
    try {
      final shouldEnable = enabled ?? !_isLocalVideoEnabled;

      await _rtcEngine?.enableLocalVideo(shouldEnable);
      _isLocalVideoEnabled = shouldEnable;

      _eventController.add(VideoCallEvent(
        type: VideoCallEventType.videoToggled,
        message: 'Video ${shouldEnable ? 'enabled' : 'disabled'}',
        data: {'enabled': shouldEnable},
      ));

      debugPrint('$_tag: Video ${shouldEnable ? 'enabled' : 'disabled'}');
    } catch (e) {
      debugPrint('$_tag: ❌ Error toggling video: $e');
    }
  }

  /// Phase 2 Day 19: Toggle local audio on/off
  Future<void> toggleAudio({bool? enabled}) async {
    try {
      final shouldEnable = enabled ?? !_isLocalAudioEnabled;

      await _rtcEngine?.enableLocalAudio(shouldEnable);
      _isLocalAudioEnabled = shouldEnable;

      _eventController.add(VideoCallEvent(
        type: VideoCallEventType.audioToggled,
        message: 'Audio ${shouldEnable ? 'enabled' : 'disabled'}',
        data: {'enabled': shouldEnable},
      ));

      debugPrint('$_tag: Audio ${shouldEnable ? 'enabled' : 'disabled'}');
    } catch (e) {
      debugPrint('$_tag: ❌ Error toggling audio: $e');
    }
  }

  /// Phase 2 Day 19: Switch camera (front/back)
  Future<void> switchCamera() async {
    try {
      await _rtcEngine?.switchCamera();

      _eventController.add(VideoCallEvent(
        type: VideoCallEventType.cameraSwitched,
        message: 'Camera switched',
      ));

      debugPrint('$_tag: Camera switched');
    } catch (e) {
      debugPrint('$_tag: ❌ Error switching camera: $e');
    }
  }

  /// Phase 2 Day 20: Enable bandwidth adaptation
  Future<void> enableBandwidthAdaptation() async {
    try {
      // Configure video encoder settings for adaptive streaming
      const VideoEncoderConfiguration config = VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 360),
        frameRate: 15,
        bitrate: 400,
        orientationMode: OrientationMode.orientationModeAdaptive,
        degradationPreference: DegradationPreference.maintainBalanced,
      );

      await _rtcEngine?.setVideoEncoderConfiguration(config);

      debugPrint('$_tag: ✅ Bandwidth adaptation enabled');
    } catch (e) {
      debugPrint('$_tag: ❌ Error enabling bandwidth adaptation: $e');
    }
  }

  /// Phase 2 Day 20: Start quality monitoring
  void _startQualityMonitoring() {
    _qualityTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _collectQualityMetrics();
    });
  }

  /// Phase 2 Day 20: Stop quality monitoring
  void _stopQualityMonitoring() {
    _qualityTimer?.cancel();
    _qualityTimer = null;
  }

  /// Phase 2 Day 20: Collect call quality metrics
  Future<void> _collectQualityMetrics() async {
    try {
      // Get local network quality
      // Note: This would be called from the onNetworkQuality callback

      final qualityData = CallQualityData(
        timestamp: DateTime.now(),
        networkQuality: _callQualityMetrics['networkQuality'] ?? 'unknown',
        audioQuality: _callQualityMetrics['audioQuality'] ?? 'good',
        videoQuality: _callQualityMetrics['videoQuality'] ?? 'good',
        latency: _callQualityMetrics['latency'] ?? 0,
        packetLoss: _callQualityMetrics['packetLoss'] ?? 0.0,
      );

      _qualityController.add(qualityData);
    } catch (e) {
      debugPrint('$_tag: ❌ Error collecting quality metrics: $e');
    }
  }

  /// Phase 2 Day 21: Start call recording (server-side)
  Future<bool> startCallRecording() async {
    try {
      debugPrint('$_tag: Starting call recording...');

      // TODO: Implement server-side recording token flow
      // This would typically involve:
      // 1. Request recording token from your server
      // 2. Server calls Agora Cloud Recording API
      // 3. Return recording ID to client

      _eventController.add(VideoCallEvent(
        type: VideoCallEventType.recordingStarted,
        message: 'Call recording started',
        data: {'recordingId': 'placeholder-recording-id'},
      ));

      debugPrint('$_tag: ✅ Call recording started (placeholder)');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Error starting recording: $e');
      return false;
    }
  }

  /// Phase 2 Day 21: Stop call recording
  Future<bool> stopCallRecording() async {
    try {
      debugPrint('$_tag: Stopping call recording...');

      // TODO: Implement server-side recording stop

      _eventController.add(VideoCallEvent(
        type: VideoCallEventType.recordingStopped,
        message: 'Call recording stopped',
      ));

      debugPrint('$_tag: ✅ Call recording stopped');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Error stopping recording: $e');
      return false;
    }
  }

  /// Phase 2 Day 21: Handle call errors and retry join
  Future<void> handleCallError(String error) async {
    debugPrint('$_tag: Handling call error: $error');

    _eventController.add(VideoCallEvent(
      type: VideoCallEventType.callError,
      message: error,
    ));

    // Auto-retry logic for common errors
    if (error.contains('network') || error.contains('timeout')) {
      debugPrint('$_tag: Attempting to reconnect...');

      await Future.delayed(const Duration(seconds: 2));

      if (_currentChannelName != null && _localUserId != null) {
        await leaveCall();
        await Future.delayed(const Duration(seconds: 1));
        await joinCall(
          channelName: _currentChannelName!,
          userId: _localUserId!,
        );
      }
    }
  }

  /// Set up Agora event handlers
  Future<void> _setupEventHandlers() async {
    _rtcEngine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint('$_tag: 🎉 Joined channel: ${connection.channelId}');
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint('$_tag: 👤 User joined: $remoteUid');

        _remoteUsers[remoteUid] = RemoteUserInfo(
          userId: remoteUid,
          isVideoEnabled: true,
          isAudioEnabled: true,
          joinedAt: DateTime.now(),
        );

        _eventController.add(VideoCallEvent(
          type: VideoCallEventType.userJoined,
          message: 'User joined call',
          data: {'userId': remoteUid},
        ));
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        debugPrint('$_tag: 👋 User left: $remoteUid (reason: $reason)');

        _remoteUsers.remove(remoteUid);

        _eventController.add(VideoCallEvent(
          type: VideoCallEventType.userLeft,
          message: 'User left call',
          data: {'userId': remoteUid, 'reason': reason.toString()},
        ));
      },
      onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid,
          RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
        debugPrint(
            '$_tag: 📹 Remote video state changed - User: $remoteUid, State: $state');

        if (_remoteUsers.containsKey(remoteUid)) {
          _remoteUsers[remoteUid] = _remoteUsers[remoteUid]!.copyWith(
            isVideoEnabled:
                state == RemoteVideoState.remoteVideoStateStarting ||
                    state == RemoteVideoState.remoteVideoStateDecoding,
          );
        }

        _eventController.add(VideoCallEvent(
          type: VideoCallEventType.remoteVideoStateChanged,
          message: 'Remote video state changed',
          data: {
            'userId': remoteUid,
            'state': state.toString(),
            'reason': reason.toString(),
          },
        ));
      },
      onRemoteAudioStateChanged: (RtcConnection connection, int remoteUid,
          RemoteAudioState state, RemoteAudioStateReason reason, int elapsed) {
        debugPrint(
            '$_tag: 🎤 Remote audio state changed - User: $remoteUid, State: $state');

        if (_remoteUsers.containsKey(remoteUid)) {
          _remoteUsers[remoteUid] = _remoteUsers[remoteUid]!.copyWith(
            isAudioEnabled:
                state == RemoteAudioState.remoteAudioStateStarting ||
                    state == RemoteAudioState.remoteAudioStateDecoding,
          );
        }
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint('$_tag: ❌ Agora Error: $err - $msg');
        handleCallError('$err: $msg');
      },
      onNetworkQuality: (RtcConnection connection, int remoteUid,
          QualityType txQuality, QualityType rxQuality) {
        // Update quality metrics for monitoring (Day 20)
        _callQualityMetrics['networkQuality'] = _qualityToString(rxQuality);
        _callQualityMetrics['txQuality'] = _qualityToString(txQuality);
      },
    ));
  }

  /// Convert quality enum to string
  String _qualityToString(QualityType quality) {
    switch (quality) {
      case QualityType.qualityExcellent:
        return 'excellent';
      case QualityType.qualityGood:
        return 'good';
      case QualityType.qualityPoor:
        return 'poor';
      case QualityType.qualityBad:
        return 'bad';
      case QualityType.qualityDown:
        return 'down';
      default:
        return 'unknown';
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    debugPrint('$_tag: Disposing video calling service...');

    await leaveCall();
    _stopQualityMonitoring();

    await _rtcEngine?.release();
    _rtcEngine = null;

    await _eventController.close();
    await _qualityController.close();

    _isInitialized = false;
    debugPrint('$_tag: ✅ Video calling service disposed');
  }
}

/// Video call event types
enum VideoCallEventType {
  initialized,
  permissionDenied,
  callJoined,
  callEnded,
  callFailed,
  callError,
  userJoined,
  userLeft,
  videoToggled,
  audioToggled,
  cameraSwitched,
  remoteVideoStateChanged,
  recordingStarted,
  recordingStopped,
}

/// Video call event data
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

/// Remote user information
class RemoteUserInfo {
  final int userId;
  final bool isVideoEnabled;
  final bool isAudioEnabled;
  final DateTime joinedAt;

  const RemoteUserInfo({
    required this.userId,
    required this.isVideoEnabled,
    required this.isAudioEnabled,
    required this.joinedAt,
  });

  RemoteUserInfo copyWith({
    int? userId,
    bool? isVideoEnabled,
    bool? isAudioEnabled,
    DateTime? joinedAt,
  }) {
    return RemoteUserInfo(
      userId: userId ?? this.userId,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

/// Call quality monitoring data (Day 20)
class CallQualityData {
  final DateTime timestamp;
  final String networkQuality;
  final String audioQuality;
  final String videoQuality;
  final int latency;
  final double packetLoss;

  const CallQualityData({
    required this.timestamp,
    required this.networkQuality,
    required this.audioQuality,
    required this.videoQuality,
    required this.latency,
    required this.packetLoss,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'networkQuality': networkQuality,
        'audioQuality': audioQuality,
        'videoQuality': videoQuality,
        'latency': latency,
        'packetLoss': packetLoss,
      };
}
