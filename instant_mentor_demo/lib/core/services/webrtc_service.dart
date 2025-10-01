import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config/app_config.dart';
import 'websocket_service.dart';

// Stub: WebRTCService removed
class WebRTCService {
  WebRTCService._();
  static final WebRTCService instance = WebRTCService._();

  // WebRTC implementation variables
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  StreamSubscription<WebSocketMessage>? _wsSub;
  bool _inited = false;
  String? _peerUserId;
  String? _currentCallId;

  bool get isInitialized => _inited;

  Future<void> initialize() async {
    if (_inited) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _wsSub = WebSocketService.instance.messageStream.listen(_onSignalMessage);
    _inited = true;
  }

  Future<void> dispose() async {
    await _wsSub?.cancel();
    await _closePeer();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
    _inited = false;
  }

  Future<void> _ensurePeer() async {
    if (_pc != null) return;
    final config = {
      'iceServers': AppConfig.instance.webrtcIceServers,
      'sdpSemantics': 'unified-plan',
    };

    _pc = await createPeerConnection(config);

    // Remote track hookup
    _pc!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
      }
    };

    _pc!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_peerUserId == null || _currentCallId == null) return;
      _sendSignal('ice-candidate', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _pc!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('WebRTC connection state: $state');
    };
  }

  Future<MediaStream> _getUserMedia(
      {bool video = true, bool audio = true}) async {
    final constraints = <String, dynamic>{
      'audio': audio,
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
              'frameRate': {'ideal': 30},
            }
          : false,
    };
    final stream = await navigator.mediaDevices.getUserMedia(constraints);
    return stream;
  }

  Future<void> startCall({
    required String callId,
    required String peerUserId,
    bool video = true,
  }) async {
    await initialize();
    _currentCallId = callId;
    _peerUserId = peerUserId;
    await _ensurePeer();

    _localStream = await _getUserMedia(video: video);
    for (var track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
    localRenderer.srcObject = _localStream;

    final offer = await _pc!.createOffer(
        {'offerToReceiveAudio': 1, 'offerToReceiveVideo': video ? 1 : 0});
    await _pc!.setLocalDescription(offer);

    _sendSignal('webrtc-offer', {
      'sdp': offer.sdp,
      'type': offer.type,
    });
  }

  Future<void> acceptCall({
    required String callId,
    required String peerUserId,
    bool video = true,
  }) async {
    await initialize();
    _currentCallId = callId;
    _peerUserId = peerUserId;
    await _ensurePeer();

    _localStream = await _getUserMedia(video: video);
    for (var track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
    localRenderer.srcObject = _localStream;
  }

  Future<void> handleRemoteOffer(Map<String, dynamic> data) async {
    await _ensurePeer();
    final desc =
        RTCSessionDescription(data['sdp'] as String, data['type'] as String);
    await _pc!.setRemoteDescription(desc);

    final answer = await _pc!
        .createAnswer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': 1});
    await _pc!.setLocalDescription(answer);

    _sendSignal('webrtc-answer', {
      'sdp': answer.sdp,
      'type': answer.type,
    });
  }

  Future<void> handleRemoteAnswer(Map<String, dynamic> data) async {
    final desc =
        RTCSessionDescription(data['sdp'] as String, data['type'] as String);
    await _pc?.setRemoteDescription(desc);
  }

  Future<void> handleRemoteIce(Map<String, dynamic> data) async {
    final cand = RTCIceCandidate(
      data['candidate'] as String?,
      data['sdpMid'] as String?,
      data['sdpMLineIndex'] as int?,
    );
    await _pc?.addCandidate(cand);
  }

  Future<void> toggleMute() async {
    if (_localStream == null) return;
    for (var track in _localStream!.getAudioTracks()) {
      track.enabled = !track.enabled;
    }
  }

  Future<void> toggleCamera() async {
    if (_localStream == null) return;
    for (var track in _localStream!.getVideoTracks()) {
      track.enabled = !track.enabled;
    }
  }

  Future<void> endCall() async {
    if (_currentCallId != null && _peerUserId != null) {
      _sendSignal('webrtc-hangup', {});
    }
    await _closePeer();
  }

  Future<void> _closePeer() async {
    try {
      await _pc?.close();
      _pc = null;
    } catch (_) {}
    try {
      await _localStream?.dispose();
    } catch (_) {}
    try {
      await _remoteStream?.dispose();
    } catch (_) {}
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    _currentCallId = null;
    _peerUserId = null;
  }

  void _sendSignal(String type, Map<String, dynamic> payload) {
    if (_peerUserId == null || _currentCallId == null) return;
    
    final message = WebSocketMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      event: WebSocketEvent.systemUpdate, // Using systemUpdate as generic event
      data: {
        'sig': type,
        'callId': _currentCallId,
        ...payload,
      },
      senderId: WebSocketService.instance.currentUserId,
      receiverId: _peerUserId,
    );
    
    WebSocketService.instance.sendMessage(message);
  }

  void _onSignalMessage(WebSocketMessage msg) {
    if (msg.receiverId != WebSocketService.instance.currentUserId) return;
    final Map<String, dynamic> map = msg.data;
    // Only process true WebRTC signaling relays
    if (!map.containsKey('sig')) return;
    // If we haven't bound to a call yet, adopt ids from the first signal
    _currentCallId ??= map['callId'] as String?;
    _peerUserId ??= msg.senderId;
    if (_currentCallId != null && map['callId'] != _currentCallId) return;

    final type = map['sig'] as String;
    final payload = Map<String, dynamic>.from(map['payload'] as Map? ?? {});
    switch (type) {
      case 'webrtc-offer':
        handleRemoteOffer(payload);
        break;
      case 'webrtc-answer':
        handleRemoteAnswer(payload);
        break;
      case 'ice-candidate':
        handleRemoteIce(payload);
        break;
      case 'webrtc-hangup':
        endCall();
        break;
    }
  }
}
