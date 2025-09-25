import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Conditional import to prevent flutter_webrtc usage on web (stub instead)
// ignore: uri_does_not_exist
import 'package:flutter_webrtc/flutter_webrtc.dart'
    if (dart.library.html) 'package:instant_mentor_demo/features/shared/live_session/webrtc_stub.dart';

import '../../../core/data/repositories/call_history_repository.dart';
import '../models/call_data.dart';
import '../models/call_history.dart';
import '../models/call_state.dart';
import '../models/signaling_message.dart';
import '../services/signaling_service.dart';

/// Exception thrown by the call controller
class CallException implements Exception {
  final String message;
  final String? code;

  const CallException(this.message, [this.code]);

  @override
  String toString() =>
      'CallException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Configuration for WebRTC peer connection
class RTCConfiguration {
  static const List<Map<String, String>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
  ];

  static const Map<String, dynamic> configuration = {
    'iceServers': iceServers,
    'sdpSemantics': 'unified-plan',
  };

  static const Map<String, dynamic> constraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };
}

/// Main controller for managing WebRTC video calls
/// Handles call lifecycle, media streams, and peer connections
class CallController extends StateNotifier<CallData?> {
  CallController({
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

  // Stream controllers for real-time updates
  final StreamController<MediaStream?> _localStreamController =
      StreamController<MediaStream?>.broadcast();
  final StreamController<MediaStream?> _remoteStreamController =
      StreamController<MediaStream?>.broadcast();
  final StreamController<CallStats> _statsController =
      StreamController<CallStats>.broadcast();

  // Call state management
  Timer? _callTimer;
  Timer? _statsTimer;
  DateTime? _callStartTime;

  // Public streams
  Stream<MediaStream?> get localStreamStream => _localStreamController.stream;
  Stream<MediaStream?> get remoteStreamStream => _remoteStreamController.stream;
  Stream<CallStats> get statsStream => _statsController.stream;

  // Getters
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get hasActiveCall => state != null && state!.state != CallState.ended;
  CallData? get currentCall => state;

  /// Initialize the call controller
  void _initialize() {
    // Listen to signaling messages
    signalingService.messageStream.listen(_handleSignalingMessage);
    signalingService.connectionStream.listen(_handleConnectionStateChange);
  }

  /// Start an outgoing call
  Future<void> startCall({
    required String callId,
    required String currentUserId,
    required String targetUserId,
    required String targetUserName,
    required String currentUserName,
    bool isVideoCall = true,
  }) async {
    try {
      debugPrint(
          '📞 Starting ${isVideoCall ? 'video' : 'audio'} call to $targetUserName');

      // Initialize signaling for this call
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

      // Add local stream to peer connection
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

      // Update state to ringing
      _updateCallState(CallState.ringing);

      debugPrint('📞 Call offer sent to $targetUserName');
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
      debugPrint('📞 Accepting call from ${state!.callerName}');

      // Get user media - determine if it's video call from media state or data
      final isVideoCall = state!.mediaState.isVideoEnabled;
      await _getUserMedia(video: isVideoCall, audio: true);

      // Create peer connection if not exists
      if (_peerConnection == null) {
        await _createPeerConnection();
      }

      // Add local stream
      if (_localStream != null) {
        await _peerConnection!.addStream(_localStream!);
      }

      // Create and send answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      await signalingService.sendAnswer(
        sdp: answer.toMap(),
        toUserId: state!.callerId,
      );

      _updateCallState(CallState.inCall);
      _startCallTimer();

      debugPrint('📞 Call accepted and connected');
    } catch (e) {
      debugPrint('❌ Failed to accept call: $e');
      await _handleCallError('Failed to accept call: $e');
    }
  }

  /// Reject an incoming call
  Future<void> rejectCall({String? reason}) async {
    if (state == null || state!.callState != CallState.incoming) {
      throw const CallException('No incoming call to reject');
    }

    try {
      debugPrint('📞 Rejecting call from ${state!.callerName}');

      await signalingService.sendCallReject(toUserId: state!.callerId);
      await _endCall(reason: reason ?? 'Call rejected');

      debugPrint('📞 Call rejected');
    } catch (e) {
      debugPrint('❌ Failed to reject call: $e');
      await _handleCallError('Failed to reject call: $e');
    }
  }

  /// End the current call
  Future<void> endCall({String? reason}) async {
    if (state == null) return;

    try {
      debugPrint('📞 Ending call');

      final otherUserId = state!.callerId == signalingService.currentUserId
          ? state!.receiverId
          : state!.callerId;

      if (state!.callState == CallState.ringing) {
        // Cancel outgoing call
        await signalingService.sendCallCancel(toUserId: otherUserId);
      } else {
        // End active call
        await signalingService.sendCallEnd(toUserId: otherUserId);
      }

      await _endCall(reason: reason ?? 'Call ended');

      debugPrint('📞 Call ended');
    } catch (e) {
      debugPrint('❌ Failed to end call: $e');
      await _handleCallError('Failed to end call: $e');
    }
  }

  /// Toggle video on/off
  Future<void> toggleVideo() async {
    if (_localStream == null) return;

    try {
      final videoTrack = _localStream!.getVideoTracks().isNotEmpty
          ? _localStream!.getVideoTracks().first
          : null;

      if (videoTrack != null) {
        final newEnabled = !videoTrack.enabled;
        videoTrack.enabled = newEnabled;

        _updateMediaState(
            state!.mediaState.copyWith(isVideoEnabled: newEnabled));
        debugPrint('📹 Video ${newEnabled ? 'enabled' : 'disabled'}');
      }
    } catch (e) {
      debugPrint('❌ Failed to toggle video: $e');
    }
  }

  /// Toggle audio on/off
  Future<void> toggleAudio() async {
    if (_localStream == null) return;

    try {
      final audioTrack = _localStream!.getAudioTracks().isNotEmpty
          ? _localStream!.getAudioTracks().first
          : null;

      if (audioTrack != null) {
        final newEnabled = !audioTrack.enabled;
        audioTrack.enabled = newEnabled;

        _updateMediaState(
            state!.mediaState.copyWith(isAudioEnabled: newEnabled));
        debugPrint('🎤 Audio ${newEnabled ? 'enabled' : 'disabled'}');
      }
    } catch (e) {
      debugPrint('❌ Failed to toggle audio: $e');
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_localStream == null) return;

    try {
      final videoTrack = _localStream!.getVideoTracks().isNotEmpty
          ? _localStream!.getVideoTracks().first
          : null;

      if (videoTrack != null) {
        await Helper.switchCamera(videoTrack);
        debugPrint('📷 Camera switched');
      }
    } catch (e) {
      debugPrint('❌ Failed to switch camera: $e');
    }
  }

  /// Handle incoming signaling messages
  void _handleSignalingMessage(signalingMessage) async {
    try {
      debugPrint(
          '📡 Handling signaling message: ${signalingMessage.type.name}');

      switch (signalingMessage.type) {
        case SignalingMessageType.callOffer:
          await _handleCallOffer(signalingMessage);
          break;
        case SignalingMessageType.callAnswer:
          await _handleCallAnswer(signalingMessage);
          break;
        case SignalingMessageType.iceCandidate:
          await _handleIceCandidate(signalingMessage);
          break;
        case SignalingMessageType.callReject:
          await _handleCallReject(signalingMessage);
          break;
        case SignalingMessageType.callEnd:
        case SignalingMessageType.callCancel:
          await _handleCallEnd(signalingMessage);
          break;
        default:
          debugPrint(
              '🤷 Unhandled signaling message type: ${signalingMessage.type}');
      }
    } catch (e) {
      debugPrint('❌ Error handling signaling message: $e');
    }
  }

  /// Handle incoming call offer
  Future<void> _handleCallOffer(signalingMessage) async {
    if (hasActiveCall) {
      // Reject if already in a call
      await signalingService.sendCallReject(
          toUserId: signalingMessage.fromUserId);
      return;
    }

    // Create incoming call data
    final callData = CallData.incoming(
      callId: signalingMessage.callId,
      callerId: signalingMessage.fromUserId,
      callerName: signalingMessage.data?['callerName'] ?? 'Unknown',
      receiverId: signalingMessage.toUserId,
      isVideoCall: signalingMessage.data?['sdp']?['type'] == 'offer',
    );

    state = callData;

    // Create peer connection
    await _createPeerConnection();

    // Set remote description
    final offer = RTCSessionDescription(
      signalingMessage.data!['sdp']['sdp'],
      signalingMessage.data!['sdp']['type'],
    );
    await _peerConnection!.setRemoteDescription(offer);

    debugPrint('📞 Incoming call from ${callData.callerName}');
  }

  /// Handle call answer
  Future<void> _handleCallAnswer(signalingMessage) async {
    if (_peerConnection == null) return;

    try {
      final answer = RTCSessionDescription(
        signalingMessage.data!['sdp']['sdp'],
        signalingMessage.data!['sdp']['type'],
      );
      await _peerConnection!.setRemoteDescription(answer);

      _updateCallState(CallState.connected);
      _startCallTimer();

      debugPrint('📞 Call answered and connected');
    } catch (e) {
      debugPrint('❌ Error handling call answer: $e');
    }
  }

  /// Handle ICE candidate
  Future<void> _handleIceCandidate(signalingMessage) async {
    if (_peerConnection == null) return;

    try {
      final candidateData = signalingMessage.data!['candidate'];
      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);

      debugPrint('📡 ICE candidate added');
    } catch (e) {
      debugPrint('❌ Error handling ICE candidate: $e');
    }
  }

  /// Handle call rejection
  Future<void> _handleCallReject(signalingMessage) async {
    final reason = signalingMessage.data?['reason'] ?? 'Call rejected';
    await _endCall(reason: reason);
    debugPrint('📞 Call rejected: $reason');
  }

  /// Handle call end
  Future<void> _handleCallEnd(signalingMessage) async {
    final reason = signalingMessage.data?['reason'] ?? 'Call ended by peer';
    await _endCall(reason: reason);
    debugPrint('📞 Call ended: $reason');
  }

  /// Handle connection state changes
  void _handleConnectionStateChange(bool isConnected) {
    if (!isConnected && hasActiveCall) {
      debugPrint('📡 Signaling connection lost during call');
      _updateCallState(CallState.failed);
    }
  }

  /// Get user media (camera and microphone)
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

      debugPrint('📹 User media obtained: video=$video, audio=$audio');
    } catch (e) {
      debugPrint('❌ Failed to get user media: $e');
      throw CallException('Failed to access camera/microphone: $e');
    }
  }

  /// Create WebRTC peer connection
  Future<void> _createPeerConnection() async {
    try {
      _peerConnection = await createPeerConnection(
        RTCConfiguration.configuration,
        RTCConfiguration.constraints,
      );

      // Handle ICE candidates
      _peerConnection!.onIceCandidate = (candidate) async {
        if (candidate.candidate != null && state != null) {
          final otherUserId = state!.callerId == signalingService.currentUserId
              ? state!.receiverId
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

      // Handle connection state changes
      _peerConnection!.onConnectionState = (state) {
        debugPrint('🔗 Connection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _startStatsTimer();
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _handleCallError('Peer connection failed');
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
      state = state!.copyWith(callState: newState);
    }
  }

  /// Update media state
  void _updateMediaState(MediaState newMediaState) {
    if (state != null) {
      state = state!.copyWith(mediaState: newMediaState);
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

  /// Start statistics timer
  void _startStatsTimer() {
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_peerConnection != null) {
        try {
          final stats = await _peerConnection!.getStats();
          _processStats(stats);
        } catch (e) {
          debugPrint('❌ Failed to get stats: $e');
        }
      }
    });
  }

  /// Process WebRTC statistics
  void _processStats(List<StatsReport> reports) {
    try {
      int bytesSent = 0;
      int bytesReceived = 0;
      int packetsLost = 0;
      double jitter = 0.0;
      double roundTripTime = 0.0;

      for (final report in reports) {
        if (report.type == 'outbound-rtp') {
          bytesSent += int.tryParse(report.values['bytesSent'] ?? '0') ?? 0;
        } else if (report.type == 'inbound-rtp') {
          bytesReceived +=
              int.tryParse(report.values['bytesReceived'] ?? '0') ?? 0;
          packetsLost += int.tryParse(report.values['packetsLost'] ?? '0') ?? 0;
          jitter = double.tryParse(report.values['jitter'] ?? '0') ?? 0.0;
        } else if (report.type == 'candidate-pair' &&
            report.values['state'] == 'succeeded') {
          roundTripTime =
              double.tryParse(report.values['currentRoundTripTime'] ?? '0') ??
                  0.0;
        }
      }

      final stats = CallStats(
        bytesSent: bytesSent,
        bytesReceived: bytesReceived,
        packetsLost: packetsLost,
        jitter: jitter,
        roundTripTime: roundTripTime,
        timestamp: DateTime.now(),
      );

      _statsController.add(stats);
    } catch (e) {
      debugPrint('❌ Error processing stats: $e');
    }
  }

  /// Handle call errors
  Future<void> _handleCallError(String error) async {
    debugPrint('❌ Call error: $error');
    _updateCallState(CallState.failed);
    await _cleanup();
  }

  /// End call and cleanup
  Future<void> _endCall({required String reason}) async {
    try {
      // Save call to history
      if (state != null) {
        final callHistory = CallHistory.fromCallData(
          callData: state!,
          endTime: DateTime.now(),
          endReason: reason,
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
      // Stop timers
      _callTimer?.cancel();
      _statsTimer?.cancel();
      _callTimer = null;
      _statsTimer = null;
      _callStartTime = null;

      // Close streams
      _localStream?.getTracks().forEach((track) => track.stop());
      _localStream = null;
      _remoteStream = null;

      _localStreamController.add(null);
      _remoteStreamController.add(null);

      // Close peer connection
      await _peerConnection?.close();
      _peerConnection = null;

      // Disconnect signaling
      await signalingService.disconnect();

      // Clear state
      state = null;

      debugPrint('🧹 Call resources cleaned up');
    } catch (e) {
      debugPrint('❌ Error during cleanup: $e');
    }
  }

  @override
  void dispose() {
    _cleanup();
    _localStreamController.close();
    _remoteStreamController.close();
    _statsController.close();
    super.dispose();
  }
}

/// Provider for call controller
final callControllerProvider =
    StateNotifierProvider<CallController, CallData?>((ref) {
  final callHistoryRepository = ref.watch(callHistoryRepositoryProvider);
  final signalingService = SignalingService.instance;

  return CallController(
    callHistoryRepository: callHistoryRepository,
    signalingService: signalingService,
  );
});

/// Provider for local media stream
final localStreamProvider = StreamProvider<MediaStream?>((ref) {
  final controller = ref.watch(callControllerProvider.notifier);
  return controller.localStreamStream;
});

/// Provider for remote media stream
final remoteStreamProvider = StreamProvider<MediaStream?>((ref) {
  final controller = ref.watch(callControllerProvider.notifier);
  return controller.remoteStreamStream;
});

/// Provider for call statistics
final callStatsProvider = StreamProvider<CallStats>((ref) {
  final controller = ref.watch(callControllerProvider.notifier);
  return controller.statsStream;
});
