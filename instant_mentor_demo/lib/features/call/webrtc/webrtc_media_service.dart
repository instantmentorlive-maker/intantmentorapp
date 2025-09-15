import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../call/signaling/signaling_service.dart';

/// Lightweight media service wrapping a single RTCPeerConnection for 1:1 calls.
/// Separation of concerns: SignalingService transports JSON messages; this class
/// manages local media, peer connection state, and surfaces renderers.
class WebRTCMediaService {
  final SignalingService signaling;
  final String callId;
  final bool enableVideo;

  // When signaling is in demoMode we avoid creating a real RTCPeerConnection / SDP.
  bool get _demo => signaling.demoMode;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  final _connectionStateController =
      StreamController<RTCPeerConnectionState>.broadcast();
  Stream<RTCPeerConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  WebRTCMediaService({
    required this.signaling,
    required this.callId,
    this.enableVideo = true,
  });

  Future<void> initialize() async {
    if (_initialized) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    if (_demo) {
      // In demo mode we don't create a peer connection. We provide a placeholder local stream later.
      debugPrint('[webrtc][demo] Skipping peer connection initialization');
    } else {
      await _ensurePeer();
    }
    _initialized = true;
  }

  Future<void> _ensurePeer() async {
    if (_pc != null) return;
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };
    _pc = await createPeerConnection(config);

    _pc!.onIceCandidate = (c) {
      if (c.candidate != null) {
        signaling.sendIceCandidate(callId, {
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        });
      }
    };

    _pc!.onTrack = (RTCTrackEvent e) {
      if (e.streams.isNotEmpty) {
        _remoteStream = e.streams.first;
        remoteRenderer.srcObject = _remoteStream;
      }
    };

    _pc!.onConnectionState = (state) {
      _connectionStateController.add(state);
      debugPrint('[webrtc] PeerConnection state: $state');
    };
  }

  Future<void> startLocalMedia() async {
    if (_demo) {
      if (_localStream == null) {
        // Provide a fake (empty) MediaStream so UI shows a participant tile (once).
        debugPrint('[webrtc][demo] Creating synthetic local media placeholder');
        _localStream = await createLocalMediaStream('demo-local');
        localRenderer.srcObject = _localStream;
      }
      return;
    }
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': enableVideo
            ? {
                'facingMode': 'user',
                'width': {'ideal': 640},
                'height': {'ideal': 480},
                'frameRate': {'ideal': 24},
              }
            : false,
      });
      for (var track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }
      localRenderer.srcObject = _localStream;
    } catch (e) {
      debugPrint('[webrtc] Error getting user media: $e');
      rethrow;
    }
  }

  Future<void> createAndSendOffer() async {
    if (_demo) {
      debugPrint(
          '[webrtc][demo] Skipping real offer creation; simulating answer later');
      // Directly simulate that an answer will arrive (signaling service already does this after sendOffer call)
      signaling.sendOffer(callId, {
        'sdp': 'demo-offer-sdp',
        'type': 'offer',
      });
      return;
    }
    final offer = await _pc!.createOffer(
        {'offerToReceiveAudio': 1, 'offerToReceiveVideo': enableVideo ? 1 : 0});
    await _pc!.setLocalDescription(offer);
    signaling.sendOffer(callId, {'sdp': offer.sdp, 'type': offer.type});
  }

  Future<void> createAndSendAnswer() async {
    if (_demo) {
      debugPrint('[webrtc][demo] Skipping real answer creation');
      signaling
          .sendAnswer(callId, {'sdp': 'demo-answer-sdp', 'type': 'answer'});
      return;
    }
    final answer = await _pc!
        .createAnswer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': 1});
    await _pc!.setLocalDescription(answer);
    signaling.sendAnswer(callId, {'sdp': answer.sdp, 'type': answer.type});
  }

  Future<void> setRemoteDescription(Map<String, dynamic> sdp) async {
    if (_demo) {
      if (remoteRenderer.srcObject == null) {
        debugPrint('[webrtc][demo] Ignoring remote description (demo - first)');
        // Simulate remote stream by cloning local (placeholder) once when first remote desc would be applied.
        if (localRenderer.srcObject != null) {
          debugPrint('[webrtc][demo] Attaching synthetic remote stream');
          remoteRenderer.srcObject = localRenderer.srcObject;
        }
      } // subsequent demo remote descriptions are silently ignored
      return;
    }
    final desc =
        RTCSessionDescription(sdp['sdp'] as String, sdp['type'] as String);
    await _pc!.setRemoteDescription(desc);
  }

  Future<void> addRemoteIce(Map<String, dynamic> cand) async {
    if (_demo) {
      // No-op in demo; no real peer connection
      return;
    }
    await _pc?.addCandidate(RTCIceCandidate(
        cand['candidate'], cand['sdpMid'], cand['sdpMLineIndex']));
  }

  Future<void> toggleMute() async {
    if (_localStream == null) return;
    for (var t in _localStream!.getAudioTracks()) {
      t.enabled = !t.enabled;
    }
  }

  Future<void> toggleCamera() async {
    if (_localStream == null) return;
    for (var t in _localStream!.getVideoTracks()) {
      t.enabled = !t.enabled;
    }
  }

  Future<void> dispose() async {
    try {
      await _pc?.close();
    } catch (e) {
      debugPrint('[webrtc] Error closing pc: $e');
    }
    try {
      await _localStream?.dispose();
    } catch (e) {
      debugPrint('[webrtc] Error disposing local stream: $e');
    }
    try {
      await _remoteStream?.dispose();
    } catch (e) {
      debugPrint('[webrtc] Error disposing remote stream: $e');
    }
    try {
      await localRenderer.dispose();
    } catch (e) {
      debugPrint('[webrtc] Error disposing local renderer: $e');
    }
    try {
      await remoteRenderer.dispose();
    } catch (e) {
      debugPrint('[webrtc] Error disposing remote renderer: $e');
    }
    try {
      await _connectionStateController.close();
    } catch (e) {
      debugPrint('[webrtc] Error closing controller: $e');
    }
    _pc = null;
  }

  /// Returns a simplified stats snapshot map extracting a few key metrics.
  /// If peer connection not ready, returns empty map.
  Future<Map<String, dynamic>> getStatsSnapshot() async {
    final pc = _pc;
    if (pc == null) return {};
    try {
      final raw = await pc.getStats();
      // raw is a list of RTCStatsReport (platform dependent). We'll condense.
      double outboundBits = 0;
      double inboundBits = 0;
      int framesSent = 0;
      int framesRecv = 0;
      double rttMs = 0;
      int packetsLost = 0;
      int packetsSent = 0;
      int packetsRecv = 0;
      int width = 0;
      int height = 0;
      for (final report in raw) {
        final type =
            report.type; // e.g. outbound-rtp, inbound-rtp, candidate-pair
        final values = report.values;
        if (type.contains('outbound-rtp')) {
          final bytes = _asInt(values['bytesSent']);
          outboundBits += bytes * 8;
          packetsSent += _asInt(values['packetsSent']);
          framesSent += _asInt(values['framesEncoded']);
          width = width == 0 ? _asInt(values['frameWidth']) : width;
          height = height == 0 ? _asInt(values['frameHeight']) : height;
        } else if (type.contains('inbound-rtp')) {
          final bytes = _asInt(values['bytesReceived']);
          inboundBits += bytes * 8;
          packetsRecv += _asInt(values['packetsReceived']);
          packetsLost += _asInt(values['packetsLost']);
          framesRecv += _asInt(values['framesDecoded']);
        } else if (type.contains('candidate-pair') &&
            values['currentRoundTripTime'] != null) {
          rttMs = (_asDouble(values['currentRoundTripTime']) * 1000);
        }
      }
      final lossPct = (packetsLost > 0 && (packetsRecv + packetsLost) > 0)
          ? (packetsLost / (packetsRecv + packetsLost)) * 100
          : 0.0;
      return {
        'outbound_bitrate_bps':
            outboundBits, // total bits (not per second delta; caller can diff sample)
        'inbound_bitrate_bps': inboundBits,
        'rtt_ms': rttMs,
        'packets_lost': packetsLost,
        'packets_recv': packetsRecv,
        'packets_sent': packetsSent,
        'loss_pct': lossPct,
        'frames_sent': framesSent,
        'frames_recv': framesRecv,
        'resolution': width > 0 && height > 0 ? '${width}x$height' : null,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('[webrtc] getStats error: $e');
      return {};
    }
  }
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}
