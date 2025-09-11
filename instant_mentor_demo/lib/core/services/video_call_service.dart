import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../config/app_config.dart';
import 'supabase_service.dart';

class VideoCallService {
  static VideoCallService? _instance;
  static VideoCallService get instance => _instance ??= VideoCallService._();

  VideoCallService._();

  final SupabaseService _supabase = SupabaseService.instance;
  RtcEngine? _engine;

  bool _isInitialized = false;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;

  String? _currentChannelId;
  String? _currentToken;
  int? _currentUid;

  // Callbacks
  Function(int uid, bool muted)? onUserMutedAudio;
  Function(int uid, bool enabled)? onUserEnabledVideo;
  Function(int uid)? onUserJoined;
  Function(int uid)? onUserLeft;
  Function(String error)? onError;

  /// Initialize Agora SDK
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: AppConfig.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      await _setupEventHandlers();
      await _enableVideo();

      _isInitialized = true;
      debugPrint('Agora SDK initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Failed to initialize Agora SDK: $e');
      onError?.call('Failed to initialize video call: $e');
      return false;
    }
  }

  /// Setup event handlers
  Future<void> _setupEventHandlers() async {
    if (_engine == null) return;

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint('Local user joined: ${connection.localUid}');
        _currentUid = connection.localUid;
        _isInCall = true;
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint('Remote user joined: $remoteUid');
        onUserJoined?.call(remoteUid);
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        debugPrint('Remote user left: $remoteUid');
        onUserLeft?.call(remoteUid);
      },
      onRemoteAudioStateChanged: (RtcConnection connection, int remoteUid,
          RemoteAudioState state, RemoteAudioStateReason reason, int elapsed) {
        final isMuted = state == RemoteAudioState.remoteAudioStateStopped;
        onUserMutedAudio?.call(remoteUid, isMuted);
      },
      onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid,
          RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
        final isEnabled = state == RemoteVideoState.remoteVideoStateStarting ||
            state == RemoteVideoState.remoteVideoStateDecoding;
        onUserEnabledVideo?.call(remoteUid, isEnabled);
      },
      onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
        debugPrint('Token will expire, refreshing...');
        _refreshToken();
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint('Agora error: $err - $msg');
        onError?.call('Video call error: $msg');
      },
    ));
  }

  /// Enable video
  Future<void> _enableVideo() async {
    if (_engine == null) return;

    await _engine!.enableVideo();
    await _engine!.enableLocalVideo(true);
    await _engine!.setVideoEncoderConfiguration(const VideoEncoderConfiguration(
      dimensions: VideoDimensions(width: 640, height: 360),
      frameRate: 15,
      bitrate: 400,
    ));
  }

  /// Generate Agora token
  Future<String?> _generateToken(String channelId, int uid) async {
    try {
      final response = await _supabase.client.functions.invoke(
        'generate-agora-token',
        body: {
          'channelId': channelId,
          'uid': uid,
          'role': 'publisher', // Can be 'publisher' or 'subscriber'
        },
      );

      return response.data?['token'];
    } catch (e) {
      debugPrint('Failed to generate Agora token: $e');
      return null;
    }
  }

  /// Join video call
  Future<bool> joinCall({
    required String sessionId,
    required String channelId,
    int? uid,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    try {
      // Generate UID if not provided
      uid ??= DateTime.now().millisecondsSinceEpoch % 100000;

      // Generate token
      final token = await _generateToken(channelId, uid);
      if (token == null) {
        onError?.call('Failed to generate access token');
        return false;
      }

      // Join channel
      await _engine!.joinChannel(
        token: token,
        channelId: channelId,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      _currentChannelId = channelId;
      _currentToken = token;
      _currentUid = uid;

      // Update session status
      await _updateSessionStatus(sessionId, 'in_progress');

      debugPrint('Joined video call: $channelId');
      return true;
    } catch (e) {
      debugPrint('Failed to join call: $e');
      onError?.call('Failed to join video call: $e');
      return false;
    }
  }

  /// Leave video call
  Future<void> leaveCall({String? sessionId}) async {
    if (!_isInCall || _engine == null) return;

    try {
      await _engine!.leaveChannel();

      _currentChannelId = null;
      _currentToken = null;
      _currentUid = null;
      _isInCall = false;

      // Update session status
      if (sessionId != null) {
        await _updateSessionStatus(sessionId, 'completed');
      }

      debugPrint('Left video call');
    } catch (e) {
      debugPrint('Failed to leave call: $e');
    }
  }

  /// Toggle microphone
  Future<void> toggleMicrophone() async {
    if (_engine == null) return;

    _isMuted = !_isMuted;
    await _engine!.muteLocalAudioStream(_isMuted);
    debugPrint('Microphone ${_isMuted ? 'muted' : 'unmuted'}');
  }

  /// Toggle camera
  Future<void> toggleCamera() async {
    if (_engine == null) return;

    _isVideoEnabled = !_isVideoEnabled;
    await _engine!.muteLocalVideoStream(!_isVideoEnabled);
    debugPrint('Camera ${_isVideoEnabled ? 'enabled' : 'disabled'}');
  }

  /// Switch camera
  Future<void> switchCamera() async {
    if (_engine == null) return;

    await _engine!.switchCamera();
    debugPrint('Camera switched');
  }

  /// Start screen sharing
  Future<bool> startScreenShare() async {
    if (_engine == null) return false;

    try {
      await _engine!.startScreenCapture(const ScreenCaptureParameters2(
        captureAudio: true,
        captureVideo: true,
      ));
      debugPrint('Screen sharing started');
      return true;
    } catch (e) {
      debugPrint('Failed to start screen sharing: $e');
      return false;
    }
  }

  /// Stop screen sharing
  Future<void> stopScreenShare() async {
    if (_engine == null) return;

    await _engine!.stopScreenCapture();
    debugPrint('Screen sharing stopped');
  }

  /// Refresh token
  Future<void> _refreshToken() async {
    if (_currentChannelId == null || _currentUid == null) return;

    final newToken = await _generateToken(_currentChannelId!, _currentUid!);
    if (newToken != null) {
      await _engine!.renewToken(newToken);
      _currentToken = newToken;
      debugPrint('Token refreshed');
    }
  }

  /// Update session status
  Future<void> _updateSessionStatus(String sessionId, String status) async {
    try {
      await _supabase.updateData(
        table: 'mentoring_sessions',
        data: {
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        },
        column: 'id',
        value: sessionId,
      );
    } catch (e) {
      debugPrint('Failed to update session status: $e');
    }
  }

  /// Get video call statistics
  Future<Map<String, dynamic>?> getCallStats() async {
    if (_engine == null || !_isInCall) return null;

    try {
      final stats = await _engine!.getRtcStats();
      return {
        'duration': stats.duration,
        'txBytes': stats.txBytes,
        'rxBytes': stats.rxBytes,
        'txKBitRate': stats.txKBitRate,
        'rxKBitRate': stats.rxKBitRate,
        'users': stats.userCount,
      };
    } catch (e) {
      debugPrint('Failed to get call stats: $e');
      return null;
    }
  }

  /// Destroy engine
  Future<void> dispose() async {
    if (_isInCall) {
      await leaveCall();
    }

    if (_engine != null) {
      await _engine!.release();
      _engine = null;
    }

    _isInitialized = false;
    debugPrint('Video call service disposed');
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  String? get currentChannelId => _currentChannelId;
  int? get currentUid => _currentUid;
  RtcEngine? get engine => _engine;
}
