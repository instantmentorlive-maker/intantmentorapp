import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/services/websocket_service.dart';
import '../models/signaling_message.dart';

/// Exception thrown by the signaling service
class SignalingException implements Exception {
  final String message;
  final String? code;

  const SignalingException(this.message, [this.code]);

  @override
  String toString() =>
      'SignalingException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Service for WebRTC signaling communication
/// Manages peer-to-peer connection establishment between call participants
class SignalingService {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  static SignalingService get instance => _instance;

  // WebSocket service for real-time communication
  final WebSocketService _webSocketService = WebSocketService.instance;

  // Connection state management
  bool _isConnected = false;
  String? _currentUserId;
  String? _currentCallId;
  StreamSubscription<WebSocketMessage>? _messageSubscription;

  // Stream controllers for signaling events
  final StreamController<SignalingMessage> _messageController =
      StreamController<SignalingMessage>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  // Public streams
  Stream<SignalingMessage> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  // Getters
  bool get isConnected => _isConnected;
  String? get currentCallId => _currentCallId;
  String? get currentUserId => _currentUserId;

  /// Initialize signaling service for a specific call
  Future<void> initializeForCall({
    required String callId,
    required String userId,
    String userRole = 'user',
  }) async {
    try {
      _currentCallId = callId;
      _currentUserId = userId;

      // Subscribe to WebSocket messages for call events
      _messageSubscription = _webSocketService.messageStream.listen((message) {
        if (_isCallRelatedMessage(message)) {
          _handleIncomingMessage(message);
        }
      });

      // Ensure WebSocket is connected
      if (!_webSocketService.isConnected) {
        await _webSocketService.connect(userId: userId, userRole: userRole);
      }

      _isConnected = true;
      _connectionController.add(true);

      debugPrint('📡 Signaling service initialized for call: $callId');
    } catch (e) {
      debugPrint('❌ Failed to initialize signaling service: $e');
      _isConnected = false;
      _connectionController.add(false);
    }
  }

  /// Check if a WebSocket message is related to the current call
  bool _isCallRelatedMessage(WebSocketMessage message) {
    // Check if it's a call-related event
    if (!_isCallEvent(message.event)) return false;

    // Check if it's for the current call
    final callId = message.data['callId'] as String?;
    return callId == _currentCallId;
  }

  /// Check if WebSocket event is call-related
  bool _isCallEvent(WebSocketEvent event) {
    return [
      WebSocketEvent.callInitiated,
      WebSocketEvent.callAccepted,
      WebSocketEvent.callRejected,
      WebSocketEvent.callEnded,
      WebSocketEvent.callRinging,
    ].contains(event);
  }

  /// Handle incoming WebSocket message and convert to SignalingMessage
  void _handleIncomingMessage(WebSocketMessage message) {
    try {
      final signalingData = message.data['signaling'] as Map<String, dynamic>?;
      if (signalingData == null) return;

      final signalingMessage = SignalingMessage.fromJson(signalingData);
      _messageController.add(signalingMessage);

      debugPrint(
          '📡 Received signaling message: ${signalingMessage.type.name}');
    } catch (e) {
      debugPrint('❌ Failed to parse signaling message: $e');
    }
  }

  /// Send a signaling message to the peer
  Future<void> sendMessage(SignalingMessage message) async {
    if (!_isConnected || _currentCallId == null) {
      throw const SignalingException('Not connected to signaling service');
    }

    try {
      final webSocketMessage = WebSocketMessage(
        id: 'signaling_${DateTime.now().millisecondsSinceEpoch}',
        event: _getWebSocketEventForSignaling(message.type),
        senderId: _currentUserId,
        receiverId: message.toUserId,
        data: {
          'callId': _currentCallId,
          'signaling': message.toJson(),
        },
      );

      await _webSocketService.sendMessage(webSocketMessage);
      debugPrint('📡 Sent signaling message: ${message.type.name}');
    } catch (e) {
      debugPrint('❌ Failed to send signaling message: $e');
      throw SignalingException('Failed to send message: $e');
    }
  }

  /// Get appropriate WebSocket event for signaling message type
  WebSocketEvent _getWebSocketEventForSignaling(SignalingMessageType type) {
    switch (type) {
      case SignalingMessageType.callOffer:
      case SignalingMessageType.callAnswer:
        return WebSocketEvent.callInitiated;
      case SignalingMessageType.iceCandidate:
        return WebSocketEvent.callAccepted;
      case SignalingMessageType.callEnd:
      case SignalingMessageType.callCancel:
        return WebSocketEvent.callEnded;
      case SignalingMessageType.callReject:
        return WebSocketEvent.callRejected;
      case SignalingMessageType.callTimeout:
        return WebSocketEvent.callEnded;
      case SignalingMessageType.heartbeat:
        return WebSocketEvent.systemUpdate;
    }
  }

  /// Send WebRTC offer to initiate call
  Future<void> sendOffer({
    required Map<String, dynamic> sdp,
    required String toUserId,
    required String callerName,
    String callerAvatar = '',
  }) async {
    final message = SignalingMessage.callOffer(
      callId: _currentCallId!,
      fromUserId: _currentUserId!,
      toUserId: toUserId,
      sdp: sdp,
      callerName: callerName,
      callerAvatar: callerAvatar,
    );

    await sendMessage(message);
  }

  /// Send WebRTC answer to accept call
  Future<void> sendAnswer({
    required Map<String, dynamic> sdp,
    required String toUserId,
  }) async {
    final message = SignalingMessage.callAnswer(
      callId: _currentCallId!,
      fromUserId: _currentUserId!,
      toUserId: toUserId,
      sdp: sdp,
    );

    await sendMessage(message);
  }

  /// Send ICE candidate for connection establishment
  Future<void> sendIceCandidate({
    required Map<String, dynamic> candidate,
    required String toUserId,
  }) async {
    final message = SignalingMessage.iceCandidate(
      callId: _currentCallId!,
      fromUserId: _currentUserId!,
      toUserId: toUserId,
      candidate: candidate,
    );

    await sendMessage(message);
  }

  /// Send call rejection signal
  Future<void> sendCallReject({required String toUserId}) async {
    final message = SignalingMessage.callReject(
      callId: _currentCallId!,
      fromUserId: _currentUserId!,
      toUserId: toUserId,
    );

    await sendMessage(message);
  }

  /// Send call end signal
  Future<void> sendCallEnd({required String toUserId}) async {
    final message = SignalingMessage.callEnd(
      callId: _currentCallId!,
      fromUserId: _currentUserId!,
      toUserId: toUserId,
    );

    await sendMessage(message);
  }

  /// Send call cancel signal
  Future<void> sendCallCancel({required String toUserId}) async {
    final message = SignalingMessage.callCancel(
      callId: _currentCallId!,
      fromUserId: _currentUserId!,
      toUserId: toUserId,
    );

    await sendMessage(message);
  }

  /// Disconnect from signaling service
  Future<void> disconnect() async {
    try {
      _messageSubscription?.cancel();
      _messageSubscription = null;

      _isConnected = false;
      _currentCallId = null;
      _connectionController.add(false);

      debugPrint('📡 Disconnected from signaling service');
    } catch (e) {
      debugPrint('❌ Error during signaling disconnect: $e');
    }
  }

  /// Dispose of the signaling service
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
