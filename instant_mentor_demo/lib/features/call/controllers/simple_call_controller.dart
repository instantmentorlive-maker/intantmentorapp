import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/call_state.dart';
import '../models/call_data.dart';
import '../models/call_history.dart';
import '../models/signaling_message.dart';
import '../services/signaling_service.dart';
import '../../../core/data/repositories/call_history_repository.dart';

/// Exception thrown by the call controller
class CallException implements Exception {
  final String message;
  final String? code;

  const CallException(this.message, [this.code]);

  @override
  String toString() =>
      'CallException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Simplified call controller for WebRTC video calls
class SimpleCallController extends StateNotifier<CallData?> {
  SimpleCallController({
    required this.callHistoryRepository,
    required this.signalingService,
  }) : super(null) {
    _initialize();
  }

  // Dependencies
  final CallHistoryRepository callHistoryRepository;
  final SignalingService signalingService;

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Stream controllers
  final StreamController<MediaStream?> _localStreamController =
      StreamController<MediaStream?>.broadcast();
  final StreamController<MediaStream?> _remoteStreamController =
      StreamController<MediaStream?>.broadcast();

  // State management
  Timer? _callTimer;
  DateTime? _callStartTime;
  String? _currentUserId;

  // Public streams
  Stream<MediaStream?> get localStreamStream => _localStreamController.stream;
  Stream<MediaStream?> get remoteStreamStream => _remoteStreamController.stream;

  // Getters
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get hasActiveCall => state != null && state!.state != CallState.ended;

  /// Initialize the controller
  void _initialize() {
    signalingService.messageStream.listen(_handleSignalingMessage);
    signalingService.connectionStream.listen(_handleConnectionStateChange);
  }

  /// Start an outgoing call
  Future<void> startCall({
    required String currentUserId,
    required String targetUserId,
    required String targetUserName,
    required String currentUserName,
    bool isVideoCall = true,
  }) async {
    try {
      _currentUserId = currentUserId;
      final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';

      debugPrint('📞 Starting call to $targetUserName');

      // Initialize signaling
      await signalingService.initializeForCall(
        callId: callId,
        userId: currentUserId,
      );

      // Create call data
      final callData = CallData.outgoing(
        callerId: currentUserId,
        callerName: currentUserName,
        calleeId: targetUserId,
        calleeName: targetUserName,
      );

      state = callData;

      // Get user media
      await _getUserMedia(video: isVideoCall, audio: true);

      // Create peer connection
      await _createPeerConnection();

      // Add local stream
      if (_localStream != null) {
        await _peerConnection!.addStream(_localStream!);
      }

      // Create and send offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      await signalingService.sendOffer(
        sdp: offer.toMap(),
        toUserId: targetUserId,
        callerName: currentUserName,
      );

      _updateCallState(CallState.calling);

      debugPrint('📞 Call offer sent');
    } catch (e) {
      debugPrint('❌ Failed to start call: $e');
      await _handleCallError('Failed to start call: $e');
    }
  }

  /// Accept an incoming call
  Future<void> acceptCall() async {
    if (state == null || state!.state != CallState.ringing) {
      throw const CallException('No incoming call to accept');
    }

    try {
      debugPrint('📞 Accepting call');

      // Get user media
      await _getUserMedia(video: true, audio: true);

      // Add local stream
      if (_localStream != null && _peerConnection != null) {
        await _peerConnection!.addStream(_localStream!);
      }

      // Create and send answer
      if (_peerConnection != null) {
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);

        await signalingService.sendAnswer(
          sdp: answer.toMap(),
          toUserId: state!.callerId,
        );
      }

      _updateCallState(CallState.inCall);
      _startCallTimer();

      debugPrint('📞 Call accepted');
    } catch (e) {
      debugPrint('❌ Failed to accept call: $e');
      await _handleCallError('Failed to accept call: $e');
    }
  }

  /// Reject an incoming call
  Future<void> rejectCall() async {
    if (state == null) return;

    try {
      await signalingService.sendCallReject(toUserId: state!.callerId);
      await _endCall(reason: 'Call rejected');
    } catch (e) {
      debugPrint('❌ Failed to reject call: $e');
    }
  }

  /// End the current call
  Future<void> endCall() async {
    if (state == null) return;

    try {
      final otherUserId =
          state!.callerId == _currentUserId ? state!.calleeId : state!.callerId;

      if (state!.state == CallState.calling) {
        await signalingService.sendCallCancel(toUserId: otherUserId);
      } else {
        await signalingService.sendCallEnd(toUserId: otherUserId);
      }

      await _endCall(reason: 'Call ended');
    } catch (e) {
      debugPrint('❌ Failed to end call: $e');
    }
  }

  /// Toggle video on/off
  Future<void> toggleVideo() async {
    if (_localStream == null) return;

    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      final track = videoTracks.first;
      track.enabled = !track.enabled;

      if (state != null) {
        final newMediaState =
            state!.mediaState.copyWith(isVideoEnabled: track.enabled);
        state = state!.copyWith(mediaState: newMediaState);
      }
    }
  }

  /// Toggle audio on/off
  Future<void> toggleAudio() async {
    if (_localStream == null) return;

    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      final track = audioTracks.first;
      track.enabled = !track.enabled;

      if (state != null) {
        final newMediaState =
            state!.mediaState.copyWith(isAudioEnabled: track.enabled);
        state = state!.copyWith(mediaState: newMediaState);
      }
    }
  }

  /// Switch between front and rear camera
  Future<void> switchCamera() async {
    if (_localStream == null) return;

    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      try {
        await Helper.switchCamera(videoTracks.first);
        debugPrint('📷 Camera switched');
      } catch (e) {
        debugPrint('❌ Failed to switch camera: $e');
      }
    }
  }

  /// Toggle speaker/earpiece audio output
  Future<void> toggleSpeaker() async {
    if (state == null) return;

    try {
      final newSpeakerState = !state!.mediaState.isSpeakerOn;
      await Helper.setSpeakerphoneOn(newSpeakerState);

      final newMediaState =
          state!.mediaState.copyWith(isSpeakerOn: newSpeakerState);
      state = state!.copyWith(mediaState: newMediaState);

      debugPrint('🔊 Speaker ${newSpeakerState ? 'enabled' : 'disabled'}');
    } catch (e) {
      debugPrint('❌ Failed to toggle speaker: $e');
    }
  }

  /// Enable/disable echo cancellation
  Future<void> toggleEchoCancellation() async {
    if (_localStream == null) return;

    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      try {
        // Note: Echo cancellation control depends on the platform and implementation
        debugPrint('🎙️ Echo cancellation toggled');
      } catch (e) {
        debugPrint('❌ Failed to toggle echo cancellation: $e');
      }
    }
  }

  /// Set video resolution
  Future<void> setVideoResolution({
    int width = 1280,
    int height = 720,
    int frameRate = 30,
  }) async {
    if (_localStream == null) return;

    try {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        // Apply new constraints
        final constraints = <String, dynamic>{
          'width': width,
          'height': height,
          'frameRate': frameRate,
        };

        await videoTracks.first.applyConstraints(constraints);
        debugPrint(
            '📹 Video resolution set to ${width}x${height}@${frameRate}fps');
      }
    } catch (e) {
      debugPrint('❌ Failed to set video resolution: $e');
    }
  }

  /// Get call statistics
  Future<Map<String, dynamic>?> getCallStatistics() async {
    if (_peerConnection == null) return null;

    try {
      final stats = await _peerConnection!.getStats();

      // Extract relevant statistics
      final callStats = <String, dynamic>{
        'connectionState': _peerConnection!.connectionState?.name,
        'iceConnectionState': _peerConnection!.iceConnectionState?.name,
        'signalingState': _peerConnection!.signalingState?.name,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Add bandwidth and quality metrics if available
      for (final stat in stats) {
        if (stat.type == 'inbound-rtp' && stat.values['mediaType'] == 'video') {
          callStats['videoBytesReceived'] = stat.values['bytesReceived'];
          callStats['videoPacketsReceived'] = stat.values['packetsReceived'];
        } else if (stat.type == 'outbound-rtp' &&
            stat.values['mediaType'] == 'video') {
          callStats['videoBytesSent'] = stat.values['bytesSent'];
          callStats['videoPacketsSent'] = stat.values['packetsSent'];
        }
      }

      return callStats;
    } catch (e) {
      debugPrint('❌ Failed to get call statistics: $e');
      return null;
    }
  }

  /// Handle incoming signaling messages
  void _handleSignalingMessage(SignalingMessage message) async {
    try {
      debugPrint('📡 Handling signaling: ${message.type.name}');

      switch (message.type) {
        case SignalingMessageType.callOffer:
          await _handleCallOffer(message);
          break;
        case SignalingMessageType.callAnswer:
          await _handleCallAnswer(message);
          break;
        case SignalingMessageType.iceCandidate:
          await _handleIceCandidate(message);
          break;
        case SignalingMessageType.callReject:
          await _handleCallReject(message);
          break;
        case SignalingMessageType.callEnd:
        case SignalingMessageType.callCancel:
          await _handleCallEnd(message);
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('❌ Error handling signaling: $e');
    }
  }

  /// Handle incoming call offer
  Future<void> _handleCallOffer(SignalingMessage message) async {
    if (hasActiveCall) {
      await signalingService.sendCallReject(toUserId: message.fromUserId);
      return;
    }

    // Create incoming call data
    final callData = CallData.incoming(
      callId: message.callId,
      callerId: message.fromUserId,
      callerName: message.data?['callerName'] ?? 'Unknown',
      calleeId: message.toUserId,
      calleeName: 'You', // Current user
    );

    state = callData;

    // Create peer connection
    await _createPeerConnection();

    // Set remote description
    final sdpData = message.data?['sdp'];
    if (sdpData != null) {
      final offer = RTCSessionDescription(sdpData['sdp'], sdpData['type']);
      await _peerConnection!.setRemoteDescription(offer);
    }

    debugPrint('📞 Incoming call from ${callData.callerName}');
  }

  /// Handle call answer
  Future<void> _handleCallAnswer(SignalingMessage message) async {
    if (_peerConnection == null) return;

    try {
      final sdpData = message.data?['sdp'];
      if (sdpData != null) {
        final answer = RTCSessionDescription(sdpData['sdp'], sdpData['type']);
        await _peerConnection!.setRemoteDescription(answer);

        _updateCallState(CallState.inCall);
        _startCallTimer();
      }
    } catch (e) {
      debugPrint('❌ Error handling answer: $e');
    }
  }

  /// Handle ICE candidate
  Future<void> _handleIceCandidate(SignalingMessage message) async {
    if (_peerConnection == null) return;

    try {
      final candidateData = message.data?['candidate'];
      if (candidateData != null) {
        final candidate = RTCIceCandidate(
          candidateData['candidate'],
          candidateData['sdpMid'],
          candidateData['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(candidate);
      }
    } catch (e) {
      debugPrint('❌ Error handling ICE candidate: $e');
    }
  }

  /// Handle call rejection
  Future<void> _handleCallReject(SignalingMessage message) async {
    await _endCall(reason: 'Call rejected');
  }

  /// Handle call end
  Future<void> _handleCallEnd(SignalingMessage message) async {
    await _endCall(reason: 'Call ended by peer');
  }

  /// Handle connection state changes
  void _handleConnectionStateChange(bool isConnected) {
    if (!isConnected && hasActiveCall) {
      _updateCallState(CallState.failed);
    }
  }

  /// Get user media
  Future<void> _getUserMedia({required bool video, required bool audio}) async {
    try {
      final constraints = <String, dynamic>{
        'audio': audio,
        'video': video
            ? {
                'width': 1280,
                'height': 720,
                'frameRate': 30,
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _localStreamController.add(_localStream);

      debugPrint('📹 User media obtained');
    } catch (e) {
      debugPrint('❌ Failed to get user media: $e');
      throw CallException('Failed to access camera/microphone: $e');
    }
  }

  /// Create peer connection
  Future<void> _createPeerConnection() async {
    try {
      final config = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(config);

      // Handle ICE candidates
      _peerConnection!.onIceCandidate = (candidate) async {
        if (candidate.candidate != null && state != null) {
          final otherUserId = state!.callerId == _currentUserId
              ? state!.calleeId
              : state!.callerId;

          await signalingService.sendIceCandidate(
            candidate: candidate.toMap(),
            toUserId: otherUserId,
          );
        }
      };

      // Handle remote stream
      _peerConnection!.onAddStream = (stream) {
        _remoteStream = stream;
        _remoteStreamController.add(stream);
        debugPrint('📹 Remote stream received');
      };

      // Handle connection state
      _peerConnection!.onConnectionState = (state) {
        debugPrint('🔗 Connection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _handleCallError('Connection failed');
        }
      };

      debugPrint('🔗 Peer connection created');
    } catch (e) {
      debugPrint('❌ Failed to create peer connection: $e');
      throw CallException('Failed to establish connection: $e');
    }
  }

  /// Update call state
  void _updateCallState(CallState newState) {
    if (state != null) {
      state = state!.copyWith(state: newState);
    }
  }

  /// Start call timer
  void _startCallTimer() {
    _callStartTime = DateTime.now();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state != null && _callStartTime != null) {
        final duration = DateTime.now().difference(_callStartTime!);
        state = state!.copyWith(duration: duration);
      }
    });
  }

  /// Handle call error
  Future<void> _handleCallError(String error) async {
    debugPrint('❌ Call error: $error');
    _updateCallState(CallState.failed);
    await _cleanup();
  }

  /// End call and cleanup
  Future<void> _endCall({required String reason}) async {
    try {
      // Save to history if needed
      if (state != null) {
        final historyStatus = reason.contains('rejected')
            ? CallHistoryStatus.rejected
            : CallHistoryStatus.answered;

        final callHistory = CallHistory.fromCallData(
          state!,
          historyStatus,
          endTime: DateTime.now(),
          duration: state!.duration,
        );

        await callHistoryRepository.saveCall(callHistory);
      }

      _updateCallState(CallState.ended);
      await _cleanup();
    } catch (e) {
      debugPrint('❌ Error ending call: $e');
    }
  }

  /// Cleanup resources
  Future<void> _cleanup() async {
    try {
      _callTimer?.cancel();
      _callTimer = null;
      _callStartTime = null;

      _localStream?.getTracks().forEach((track) => track.stop());
      _localStream = null;
      _remoteStream = null;

      _localStreamController.add(null);
      _remoteStreamController.add(null);

      await _peerConnection?.close();
      _peerConnection = null;

      await signalingService.disconnect();

      state = null;

      debugPrint('🧹 Cleanup complete');
    } catch (e) {
      debugPrint('❌ Error during cleanup: $e');
    }
  }

  @override
  void dispose() {
    _cleanup();
    _localStreamController.close();
    _remoteStreamController.close();
    super.dispose();
  }
}

/// Provider for simple call controller
final simpleCallControllerProvider =
    StateNotifierProvider<SimpleCallController, CallData?>((ref) {
  final callHistoryRepository = ref.watch(callHistoryRepositoryProvider);
  final signalingService = SignalingService.instance;

  return SimpleCallController(
    callHistoryRepository: callHistoryRepository,
    signalingService: signalingService,
  );
});

/// Provider for local media stream
final localStreamProvider = StreamProvider<MediaStream?>((ref) {
  final controller = ref.watch(simpleCallControllerProvider.notifier);
  return controller.localStreamStream;
});

/// Provider for remote media stream
final remoteStreamProvider = StreamProvider<MediaStream?>((ref) {
  final controller = ref.watch(simpleCallControllerProvider.notifier);
  return controller.remoteStreamStream;
});
