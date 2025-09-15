import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Thin abstraction over socket.io for call signaling.
/// Handles presence + call negotiation message dispatching.
class SignalingService {
  final String baseUrl; // e.g. http://localhost:3000
  final String userId;
  final String role; // 'student' | 'mentor'
  final bool demoMode; // If true, skip actual connections
  IO.Socket? _socket;
  final _connectionStateController = StreamController<bool>.broadcast();
  final _incomingCallController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _callAcceptedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _callRejectedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _callEndedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<Object>.broadcast();

  // WebRTC negotiation streams
  final _webrtcOfferController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _webrtcAnswerController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _webrtcIceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _webrtcHangupController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  Stream<Map<String, dynamic>> get incomingCallStream =>
      _incomingCallController.stream;
  Stream<Map<String, dynamic>> get callAcceptedStream =>
      _callAcceptedController.stream;
  Stream<Map<String, dynamic>> get callRejectedStream =>
      _callRejectedController.stream;
  Stream<Map<String, dynamic>> get callEndedStream =>
      _callEndedController.stream;
  Stream<Object> get errorStream => _errorController.stream;
  Stream<Map<String, dynamic>> get webrtcOfferStream =>
      _webrtcOfferController.stream;
  Stream<Map<String, dynamic>> get webrtcAnswerStream =>
      _webrtcAnswerController.stream;
  Stream<Map<String, dynamic>> get webrtcIceStream =>
      _webrtcIceController.stream;
  Stream<Map<String, dynamic>> get webrtcHangupStream =>
      _webrtcHangupController.stream;

  SignalingService({
    required this.baseUrl,
    required this.userId,
    required this.role,
    this.demoMode = false, // Add demo mode parameter
  });

  bool get isConnected => demoMode ? true : _socket?.connected == true;
  bool _demoConnected =
      false; // guard to avoid emitting multiple connect events in demo

  Future<void> connect() async {
    if (demoMode) {
      if (_demoConnected) {
        return; // already reported connected
      }
      if (kDebugMode) {
        debugPrint('[signaling] Demo mode: Skipping actual connection');
      }
      _demoConnected = true;
      _connectionStateController.add(true); // emit once
      return;
    }

    if (kDebugMode) {
      debugPrint('[signaling] Attempting real connection to: $baseUrl');
    }

    if (_socket != null && _socket!.connected) return;

    try {
      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .setAuth({'userId': userId, 'userRole': role})
            .build(),
      );

      _socket!
        ..on('connect', (_) {
          if (kDebugMode) debugPrint('[signaling] connected ${_socket!.id}');
          _connectionStateController.add(true);
        })
        ..on('disconnect', (_) {
          if (kDebugMode) debugPrint('[signaling] disconnected');
          _connectionStateController.add(false);
        })
        ..on('connect_error', (err) {
          if (kDebugMode) debugPrint('[signaling] connection error: $err');
          _errorController.add(err);
          _connectionStateController.add(false);
        })
        ..on('call_initiated',
            (data) => _incomingCallController.add(_asMap(data)))
        ..on('call_accepted',
            (data) => _callAcceptedController.add(_asMap(data)))
        ..on('call_rejected',
            (data) => _callRejectedController.add(_asMap(data)))
        ..on('call_ended', (data) => _callEndedController.add(_asMap(data)));
      // WebRTC signaling events relayed by server
      _socket!
        ..on('webrtc_offer', (data) => _webrtcOfferController.add(_asMap(data)))
        ..on('webrtc_answer',
            (data) => _webrtcAnswerController.add(_asMap(data)))
        ..on('webrtc_ice_candidate',
            (data) => _webrtcIceController.add(_asMap(data)))
        ..on('webrtc_hangup',
            (data) => _webrtcHangupController.add(_asMap(data)));
    } catch (e) {
      if (kDebugMode) debugPrint('[signaling] connect error: $e');
      _errorController.add(e);
      _connectionStateController.add(false);
      rethrow;
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry(k.toString(), v));
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    return {'raw': data};
  }

  void initiateCall({
    required String receiverId,
    String callType = 'video',
    String? callerName,
  }) {
    if (demoMode) {
      if (kDebugMode) {
        debugPrint('[signaling] Demo mode: Simulating outgoing call to $receiverId');
      }
      final demoCallId = 'demo-call-${DateTime.now().millisecondsSinceEpoch}';
      
      // For outgoing calls in demo mode, simulate immediate call acceptance
      // This shows the video call interface right away
      Future.delayed(const Duration(milliseconds: 800), () {
        _callAcceptedController.add({
          'callId': demoCallId,
          'callerId': userId, // We are the caller
          'receiverId': receiverId,
          'callType': callType,
          'timestamp': DateTime.now().toIso8601String(),
        });
      });

      // Simulate WebRTC offer exchange after acceptance
      Future.delayed(const Duration(milliseconds: 1200), () {
        _webrtcOfferController.add({
          'callId': demoCallId,
          'payload': {
            'type': 'offer',
            'sdp': 'demo-offer-sdp-${DateTime.now().millisecondsSinceEpoch}',
          },
        });
      });
      
      return;
    }
    _socket?.emit('initiate_call', {
      'receiverId': receiverId,
      'callType': callType,
      'callerName': callerName,
    });
  }

  void acceptCall(String callId) {
    if (demoMode) {
      if (kDebugMode) {
        debugPrint('[signaling] Demo mode: Simulating call accept');
      }
      // Simulate WebRTC offer/answer exchange
      Future.delayed(const Duration(milliseconds: 300), () {
        _webrtcOfferController.add({
          'callId': callId,
          'payload': {
            'type': 'offer',
            'sdp': 'demo-offer-sdp-${DateTime.now().millisecondsSinceEpoch}',
          },
        });
      });
      return;
    }
    _socket?.emit('accept_call', {'callId': callId});
  }

  void rejectCall(String callId, {String? reason}) {
    if (demoMode) {
      if (kDebugMode) {
        debugPrint('[signaling] Demo mode: Simulating call reject');
      }
      return;
    }
    _socket?.emit('reject_call', {'callId': callId, 'reason': reason});
  }

  void endCall(String callId, {String? reason}) {
    if (demoMode) {
      if (kDebugMode) debugPrint('[signaling] Demo mode: Simulating call end');
      return;
    }
    _socket?.emit('end_call', {'callId': callId, 'reason': reason});
  }

  // Future: WebRTC negotiation messages (offer/answer/candidate)
  void sendOffer(String callId, Map<String, dynamic> sdp) {
    if (demoMode) {
      if (kDebugMode) {
        debugPrint('[signaling] Demo mode: Simulating WebRTC offer');
      }
      // Simulate answer response
      Future.delayed(const Duration(milliseconds: 500), () {
        _webrtcAnswerController.add({
          'callId': callId,
          'payload': {
            'type': 'answer',
            'sdp': 'demo-answer-sdp-${DateTime.now().millisecondsSinceEpoch}',
          },
        });
      });
      return;
    }
    _socket?.emit('webrtc_offer', {'callId': callId, 'payload': sdp});
  }

  void sendAnswer(String callId, Map<String, dynamic> sdp) {
    if (demoMode) {
      if (kDebugMode) {
        debugPrint('[signaling] Demo mode: Simulating WebRTC answer');
      }
      // Simulate ICE candidates
      Future.delayed(const Duration(milliseconds: 300), () {
        _webrtcIceController.add({
          'callId': callId,
          'payload': {
            'candidate':
                'demo-ice-candidate-${DateTime.now().millisecondsSinceEpoch}',
            'sdpMid': 'demo',
            'sdpMLineIndex': 0,
          },
        });
      });
      return;
    }
    _socket?.emit('webrtc_answer', {'callId': callId, 'payload': sdp});
  }

  void sendIceCandidate(String callId, Map<String, dynamic> candidate) {
    if (demoMode) {
      if (kDebugMode) {
        debugPrint('[signaling] Demo mode: Simulating ICE candidate');
      }
      return;
    }
    _socket?.emit(
        'webrtc_ice_candidate', {'callId': callId, 'payload': candidate});
  }

  void sendHangup(String callId, {String? reason}) {
    if (demoMode) {
      if (kDebugMode) {
        debugPrint('[signaling] Demo mode: Simulating WebRTC hangup');
      }
      return;
    }
    _socket?.emit('webrtc_hangup', {
      'callId': callId,
      'payload': {'reason': reason}
    });
  }

  void dispose() {
    _socket?.dispose();
    _connectionStateController.close();
    _incomingCallController.close();
    _callAcceptedController.close();
    _callRejectedController.close();
    _callEndedController.close();
    _errorController.close();
    _webrtcOfferController.close();
    _webrtcAnswerController.close();
    _webrtcIceController.close();
    _webrtcHangupController.close();
  }
}
