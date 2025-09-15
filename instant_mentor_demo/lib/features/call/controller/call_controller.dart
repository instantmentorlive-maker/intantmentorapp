import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/call_session.dart';
import '../models/participant.dart';
import '../models/call_event.dart';
import '../signaling/signaling_service.dart';
import '../history/call_history_repository.dart';
import '../webrtc/webrtc_media_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// State container for the current call lifecycle.
class CallState {
  final CallSession? session;
  final List<Participant> participants;
  final bool micEnabled;
  final bool cameraEnabled;
  final bool pipEnabled;
  final bool connecting;
  final bool inCall;
  final String? activeCallId;
  final String? error;
  final bool isIncomingCall; // true = incoming call, false = outgoing call

  const CallState({
    this.session,
    this.participants = const [],
    this.micEnabled = true,
    this.cameraEnabled = true,
    this.pipEnabled = false,
    this.connecting = false,
    this.inCall = false,
    this.activeCallId,
    this.error,
    this.isIncomingCall = false,
  });

  // Legacy flag referenced by UI; currently always false (auto retry not implemented).
  bool get autoRetryDisabled => false;

  CallState copyWith({
    CallSession? session,
    List<Participant>? participants,
    bool? micEnabled,
    bool? cameraEnabled,
    bool? pipEnabled,
    bool? connecting,
    bool? inCall,
    String? activeCallId,
    String? error,
    bool? isIncomingCall,
  }) {
    return CallState(
      session: session ?? this.session,
      participants: participants ?? this.participants,
      micEnabled: micEnabled ?? this.micEnabled,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      pipEnabled: pipEnabled ?? this.pipEnabled,
      connecting: connecting ?? this.connecting,
      inCall: inCall ?? this.inCall,
      activeCallId: activeCallId ?? this.activeCallId,
      error: error,
      isIncomingCall: isIncomingCall ?? this.isIncomingCall,
    );
  }
}

class CallController extends StateNotifier<CallState> {
  final SignalingService signaling;
  final String localUserId;
  final String localDisplayName;
  final CallHistoryRepository history;

  late final StreamSubscription _incomingCallSub;
  late final StreamSubscription _acceptedSub;
  late final StreamSubscription _rejectedSub;
  late final StreamSubscription _endedSub;
  late final StreamSubscription _errorSub;
  late final StreamSubscription _webrtcOfferSub;
  late final StreamSubscription _webrtcAnswerSub;
  late final StreamSubscription _webrtcIceSub;
  late final StreamSubscription _webrtcHangupSub;

  WebRTCMediaService? _media;
  RTCVideoRenderer? get localRenderer => _media?.localRenderer;
  RTCVideoRenderer? get remoteRenderer => _media?.remoteRenderer;
  bool get demoMode => signaling.demoMode;
  Timer? _remoteTrackTimeout; // watchdog for remote media arrival

  final _events = <CallEvent>[];
  List<CallEvent> get events => List.unmodifiable(_events);
  bool _autoInitiatedOnce = false; // guard to prevent loops in demo

  CallController({
    required this.signaling,
    required this.localUserId,
    required this.localDisplayName,
    required this.history,
  }) : super(const CallState()) {
    _bind();
  }

  Future<void> _bind() async {
    await signaling.connect();
    _incomingCallSub = signaling.incomingCallStream.listen(_handleIncomingCall);
    _acceptedSub = signaling.callAcceptedStream.listen(_handleCallAccepted);
    _rejectedSub = signaling.callRejectedStream.listen(_handleCallRejected);
    _endedSub = signaling.callEndedStream.listen(_handleCallEnded);
    _errorSub = signaling.errorStream.listen((e) {
      _logEvent(CallEventType.mediaError, data: e);
      state = state.copyWith(error: e.toString(), connecting: false);
    });
    _bindWebRTCStreams();
  }

  void initiateCall({required String receiverId, String callType = 'video'}) {
    // Guard against duplicate initiation attempts (e.g., rebuilds / hot reloads)
    if (state.connecting || state.activeCallId != null) {
      if (kDebugMode) {
        debugPrint(
            '[call-controller] initiateCall ignored: already connecting or active call');
      }
      return;
    }
    if (_autoInitiatedOnce && signaling.demoMode) {
      if (kDebugMode) {
        debugPrint('[call-controller][demo] Skipping re-initiate (one-shot)');
      }
      return;
    }
    final provisionalId = 'pending-${DateTime.now().millisecondsSinceEpoch}';
    final parts = [
      Participant(
          id: localUserId, displayName: localDisplayName, isLocal: true),
      Participant(id: receiverId, displayName: receiverId, isLocal: false),
    ];
    state = state.copyWith(
      connecting: true,
      activeCallId: provisionalId,
      participants: parts,
      isIncomingCall: false, // This is an outgoing call
    );
    signaling.initiateCall(
      receiverId: receiverId,
      callType: callType,
      callerName: localDisplayName,
    );
    _autoInitiatedOnce = true;
    _logEvent(CallEventType.joinRequested, data: {'receiverId': receiverId});
    // Start local media early for self preview
    _ensureMedia(provisionalId).then((_) async {
      try {
        await _media!.startLocalMedia();
      } catch (e) {
        if (signaling.demoMode) {
          if (kDebugMode) {
            debugPrint(
                '[call-controller][demo] Ignoring local media error during initiateCall: $e');
          }
        } else {
          state =
              state.copyWith(error: 'Media permission denied or unavailable');
        }
      }
    });
    // Log tentative start (actual callId returned asynchronously in incoming events to caller side currently not exposed).
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    _logEvent(CallEventType.joined, data: data);
    final callId = data['callId'] as String?;
    if (callId == null) return;

    final callerId = data['callerId']?.toString() ?? 'unknown';
    final callerName = data['callerName']?.toString() ?? 'Caller';

    final parts = [
      Participant(id: callerId, displayName: callerName, isLocal: false),
      Participant(
          id: localUserId, displayName: localDisplayName, isLocal: true),
    ];

    state = state.copyWith(
      activeCallId: callId,
      participants: parts,
      connecting: false,
      isIncomingCall: true, // This is an incoming call
    );
    history.logCallStarted(
        callId: callId, callerId: callerId, receiverId: localUserId);
  }

  void acceptCall() {
    final callId = state.activeCallId;
    if (callId == null) return;
    signaling.acceptCall(callId);
    _logEvent(CallEventType.offerReceived, data: {'callId': callId});
    state = state.copyWith(inCall: true);
    history.logAccepted(callId);
    _ensureMedia(callId).then((_) async {
      try {
        await _media!.startLocalMedia();
      } catch (e) {
        if (signaling.demoMode) {
          if (kDebugMode) {
            debugPrint(
                '[call-controller][demo] Ignoring local media error after acceptance: $e');
          }
        } else {
          state =
              state.copyWith(error: 'Media permission denied or unavailable');
          endCall(reason: 'media_error');
        }
      }
      // Remote offer will be handled in webrtc_offer listener which then creates answer.
    });
  }

  void rejectCall({String? reason}) {
    final callId = state.activeCallId;
    if (callId == null) return;
    signaling.rejectCall(callId, reason: reason);
    _logEvent(CallEventType.callEnded,
        data: {'callId': callId, 'reason': reason});
    history.logEnded(callId, reason: reason ?? 'rejected');
    _reset();
  }

  void endCall({String? reason}) {
    final callId = state.activeCallId;
    if (callId == null) return;
    signaling.endCall(callId, reason: reason);
    _logEvent(CallEventType.callEnded,
        data: {'callId': callId, 'reason': reason});
    history.logEnded(callId, reason: reason);
    _reset();
  }

  void toggleMic() {
    state = state.copyWith(micEnabled: !state.micEnabled);
    _logEvent(CallEventType.participantUpdated,
        data: {'micEnabled': state.micEnabled});
    _media?.toggleMute();
  }

  void toggleCamera() {
    state = state.copyWith(cameraEnabled: !state.cameraEnabled);
    _logEvent(CallEventType.participantUpdated,
        data: {'cameraEnabled': state.cameraEnabled});
    _media?.toggleCamera();
  }

  void togglePip() {
    // Placeholder PiP toggle: updates state; real platform-specific PiP can be implemented later.
    final enabled = !state.pipEnabled;
    state = state.copyWith(pipEnabled: enabled);
    _logEvent(CallEventType.participantUpdated, data: {'pipEnabled': enabled});
    if (kDebugMode) {
      debugPrint(
          '[call-controller] PiP toggled -> $enabled (demo placeholder)');
    }
  }

  void _handleCallAccepted(Map<String, dynamic> data) {
    // Prevent duplicate handling if we already are marked inCall with same callId
    final callId = data['callId'] as String?;
    if (callId != null && state.inCall && state.activeCallId == callId) {
      if (kDebugMode) {
        debugPrint(
            '[call-controller] Ignoring duplicate callAccepted for $callId');
      }
      return;
    }
    _logEvent(CallEventType.answerReceived, data: data);
    // callId already extracted above
    if (callId != null &&
        (state.activeCallId == null ||
            state.activeCallId!.startsWith('pending-') ||
            callId == state.activeCallId)) {
      state =
          state.copyWith(activeCallId: callId, inCall: true, connecting: false);
      _ensureMedia(callId).then((_) async {
        try {
          await _media!.startLocalMedia();
        } catch (e) {
          if (signaling.demoMode) {
            // In demo mode we ignore local media acquisition failures so the UI can proceed.
            if (kDebugMode) {
              debugPrint(
                  '[call-controller][demo] Ignoring local media error after call accepted: $e');
            }
          } else {
            state =
                state.copyWith(error: 'Media permission denied or unavailable');
            endCall(reason: 'media_error');
            return;
          }
        }
        // Caller creates offer after acceptance
        await _media!.createAndSendOffer();
        _startRemoteTrackWatchdog();
      });
    }
  }

  void _handleCallRejected(Map<String, dynamic> data) {
    _logEvent(CallEventType.callEnded, data: data);
    _reset();
  }

  void _handleCallEnded(Map<String, dynamic> data) {
    _logEvent(CallEventType.callEnded, data: data);
    _reset();
  }

  void _reset() {
    state = const CallState();
    _disposeMedia();
  }

  void _logEvent(CallEventType type, {Object? data}) {
    _events.add(CallEvent(type, data: data));
    if (kDebugMode) {
      debugPrint('[call-event] $type :: $data');
    }
  }

  @override
  void dispose() {
    _incomingCallSub.cancel();
    _acceptedSub.cancel();
    _rejectedSub.cancel();
    _endedSub.cancel();
    _errorSub.cancel();
    _webrtcOfferSub.cancel();
    _webrtcAnswerSub.cancel();
    _webrtcIceSub.cancel();
    _webrtcHangupSub.cancel();
    _disposeMedia();
    signaling.dispose();
    super.dispose();
  }

  Future<void> _ensureMedia(String callId) async {
    if (_media != null) return;
    _media = WebRTCMediaService(
      signaling: signaling,
      callId: callId,
      enableVideo: state.cameraEnabled,
    );
    await _media!.initialize();
  }

  void _disposeMedia() {
    _media?.dispose();
    _media = null;
    _remoteTrackTimeout?.cancel();
    _remoteTrackTimeout = null;
  }

  /// Public surface for stats snapshot (used by upcoming stats drawer).
  Future<Map<String, dynamic>> getStats() async {
    return await _media?.getStatsSnapshot() ?? {};
  }

  void _bindWebRTCStreams() {
    _webrtcOfferSub = signaling.webrtcOfferStream.listen((data) async {
      final callId = data['callId'] as String?;
      if (callId == null) return;
      await _ensureMedia(callId);
      final payload = data['payload'] as Map<String, dynamic>?;
      if (payload == null) return;
      await _media!.setRemoteDescription(payload);
      if (!state.inCall) {
        try {
          await _media!.startLocalMedia();
        } catch (e) {
          if (signaling.demoMode) {
            if (kDebugMode) {
              debugPrint(
                  '[call-controller][demo] Ignoring local media error on offer handling: $e');
            }
          } else {
            state =
                state.copyWith(error: 'Media permission denied or unavailable');
            endCall(reason: 'media_error');
            return;
          }
        }
      }
      await _media!.createAndSendAnswer();
      _startRemoteTrackWatchdog();
    });

    _webrtcAnswerSub = signaling.webrtcAnswerStream.listen((data) async {
      final payload = data['payload'] as Map<String, dynamic>?;
      if (payload == null) return;
      await _media?.setRemoteDescription(payload);
    });

    _webrtcIceSub = signaling.webrtcIceStream.listen((data) async {
      final payload = data['payload'] as Map<String, dynamic>?;
      if (payload == null) return;
      await _media?.addRemoteIce(payload);
    });

    _webrtcHangupSub = signaling.webrtcHangupStream.listen((data) {
      state = state.copyWith(error: 'Call ended by remote');
      endCall(reason: 'remote-hangup');
    });
  }

  void _startRemoteTrackWatchdog() {
    _remoteTrackTimeout?.cancel();
    // Only if expecting a remote participant
    final expectingRemote = state.participants.any((p) => !p.isLocal);
    if (!expectingRemote) return;
    // Skip watchdog in demo mode to avoid auto-ending the simulated call due to lack of real media.
    if (signaling.demoMode) return;
    _remoteTrackTimeout = Timer(const Duration(seconds: 20), () {
      final hasRemoteStream = _media?.remoteRenderer.srcObject != null;
      if (!hasRemoteStream) {
        state = state.copyWith(error: "Couldn't connect. Please try again.");
        endCall(reason: 'remote-track-timeout');
      }
    });
  }

  Future<void> retrySignaling() async {
    // Allow retry only if not in call
    if (state.inCall) return;
    try {
      await signaling.connect();
      state = state.copyWith();
    } catch (e) {
      state = state.copyWith(error: 'Retry failed: $e');
    }
  }
}

// Providers
final signalingServiceProvider = Provider.family<SignalingService,
    ({String userId, String role, String baseUrl})>((ref, params) {
  // ENABLE DEMO MODE TO SHOW VIDEO CALL FUNCTIONALITY
  const demoMode = true; // Enable demo mode to show immediate video call

  // Enable demo mode only for specific demo ports (3001) or when explicitly configured
  // Regular localhost:3000 should use real WebRTC connections with our WebSocket server
  // final demoMode = kDebugMode &&
  //     (params.baseUrl.contains('3001') || // Explicit demo port
  //         params.baseUrl.contains('demo') || // Demo URLs
  //         params.baseUrl.contains('mock')); // Mock URLs

  if (kDebugMode) {
    debugPrint(
        '[SignalingService] Creating service with baseUrl: ${params.baseUrl}, demoMode: $demoMode');
  }

  return SignalingService(
    baseUrl: params.baseUrl,
    userId: params.userId,
    role: params.role,
  );
});

final callControllerProvider = StateNotifierProvider.family<
    CallController,
    CallState,
    ({
      String userId,
      String displayName,
      String role,
      String baseUrl
    })>((ref, params) {
  final signaling = ref.watch(signalingServiceProvider(
      (userId: params.userId, role: params.role, baseUrl: params.baseUrl)));
  final history = ref.watch(callHistoryRepositoryProvider);
  return CallController(
    signaling: signaling,
    localUserId: params.userId,
    localDisplayName: params.displayName,
    history: history,
  );
});

// History repository provider (simple singleton for now)
final callHistoryRepositoryProvider = Provider<CallHistoryRepository>((ref) {
  final repo = CallHistoryRepository();
  ref.onDispose(repo.dispose);
  return repo;
});
