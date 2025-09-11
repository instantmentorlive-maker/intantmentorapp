import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// WebSocket connection states
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// WebSocket event types for real-time communication
enum WebSocketEvent {
  // User presence
  userOnline,
  userOffline,
  userTyping,
  userStoppedTyping,

  // Chat events
  messageReceived,
  messageSent,
  messageDelivered,
  messageRead,

  // Video calling events
  callInitiated,
  callAccepted,
  callRejected,
  callEnded,
  callRinging,

  // Session events
  sessionStarted,
  sessionEnded,
  sessionJoined,
  sessionLeft,

  // Mentor/Student interactions
  mentorAvailable,
  mentorBusy,
  studentRequestHelp,

  // System notifications
  notificationReceived,
  systemUpdate,
}

/// WebSocket message structure
class WebSocketMessage {
  final String id;
  final WebSocketEvent event;
  final Map<String, dynamic> data;
  final String? senderId;
  final String? receiverId;
  final DateTime timestamp;

  WebSocketMessage({
    required this.id,
    required this.event,
    required this.data,
    this.senderId,
    this.receiverId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event': event.name,
      'data': data,
      'senderId': senderId,
      'receiverId': receiverId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      id: json['id'] ?? '',
      event: WebSocketEvent.values.firstWhere(
        (e) => e.name == json['event'],
        orElse: () => WebSocketEvent.systemUpdate,
      ),
      data: json['data'] ?? {},
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

/// WebSocket Service for real-time communication
class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance => _instance ??= WebSocketService._();

  WebSocketService._();

  IO.Socket? _socket;
  final StreamController<WebSocketConnectionState> _connectionStateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final StreamController<WebSocketMessage> _messageController =
      StreamController<WebSocketMessage>.broadcast();

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  String? _currentUserId;
  String? _userRole;
  WebSocketConnectionState _connectionState =
      WebSocketConnectionState.disconnected;

  // Streams
  Stream<WebSocketConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<WebSocketMessage> get messageStream => _messageController.stream;

  // Getters
  WebSocketConnectionState get connectionState => _connectionState;
  bool get isConnected =>
      _connectionState == WebSocketConnectionState.connected;
  String? get currentUserId => _currentUserId;

  /// Initialize WebSocket connection
  Future<void> connect({
    required String userId,
    required String userRole,
    String? serverUrl,
  }) async {
    if (_socket?.connected == true) {
      debugPrint('🌐 WebSocket: Already connected');
      return;
    }

    _currentUserId = userId;
    _userRole = userRole;

    final wsUrl = serverUrl ?? _getDefaultServerUrl();
    debugPrint('🌐 WebSocket: Connecting to $wsUrl');

    _updateConnectionState(WebSocketConnectionState.connecting);

    try {
      _socket = IO.io(wsUrl, {
        'transports': ['websocket'],
        'autoConnect': false,
        'timeout': 20000,
        'reconnection': false, // We handle reconnection manually
        'extraHeaders': {
          'user-id': userId,
          'user-role': userRole,
        }
      });

      _setupEventHandlers();
      _socket!.connect();
    } catch (e) {
      debugPrint('🔴 WebSocket: Connection error: $e');
      _updateConnectionState(WebSocketConnectionState.error);
      _scheduleReconnect();
    }
  }

  /// Setup WebSocket event handlers
  void _setupEventHandlers() {
    if (_socket == null) return;

    // Connection events
    _socket!.onConnect((_) {
      debugPrint('🟢 WebSocket: Connected successfully');
      _updateConnectionState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();

      // Send user online status
      _sendUserPresence(true);
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔴 WebSocket: Disconnected');
      _updateConnectionState(WebSocketConnectionState.disconnected);
      _stopHeartbeat();
      _scheduleReconnect();
    });

    _socket!.onConnectError((error) {
      debugPrint('🔴 WebSocket: Connection error: $error');
      _updateConnectionState(WebSocketConnectionState.error);
      _scheduleReconnect();
    });

    _socket!.onError((error) {
      debugPrint('🔴 WebSocket: Socket error: $error');
      _updateConnectionState(WebSocketConnectionState.error);
    });

    // Message events
    _socket!.on('message', (data) {
      try {
        final message = WebSocketMessage.fromJson(data);
        debugPrint('📨 WebSocket: Received message: ${message.event.name}');
        _messageController.add(message);
      } catch (e) {
        debugPrint('🔴 WebSocket: Error parsing message: $e');
      }
    });

    // Specific event handlers
    _setupSpecificEventHandlers();
  }

  /// Setup handlers for specific events
  void _setupSpecificEventHandlers() {
    if (_socket == null) return;

    // User presence events
    _socket!.on('user_online', (data) {
      _handleMessage(WebSocketEvent.userOnline, data);
    });

    _socket!.on('user_offline', (data) {
      _handleMessage(WebSocketEvent.userOffline, data);
    });

    _socket!.on('user_typing', (data) {
      _handleMessage(WebSocketEvent.userTyping, data);
    });

    // Chat events
    _socket!.on('message_received', (data) {
      _handleMessage(WebSocketEvent.messageReceived, data);
    });

    _socket!.on('message_delivered', (data) {
      _handleMessage(WebSocketEvent.messageDelivered, data);
    });

    _socket!.on('message_read', (data) {
      _handleMessage(WebSocketEvent.messageRead, data);
    });

    // Video calling events
    _socket!.on('call_initiated', (data) {
      _handleMessage(WebSocketEvent.callInitiated, data);
    });

    _socket!.on('call_accepted', (data) {
      _handleMessage(WebSocketEvent.callAccepted, data);
    });

    _socket!.on('call_rejected', (data) {
      _handleMessage(WebSocketEvent.callRejected, data);
    });

    _socket!.on('call_ended', (data) {
      _handleMessage(WebSocketEvent.callEnded, data);
    });

    // Session events
    _socket!.on('session_started', (data) {
      _handleMessage(WebSocketEvent.sessionStarted, data);
    });

    _socket!.on('session_ended', (data) {
      _handleMessage(WebSocketEvent.sessionEnded, data);
    });

    // System notifications
    _socket!.on('notification', (data) {
      _handleMessage(WebSocketEvent.notificationReceived, data);
    });

    // Heartbeat response
    _socket!.on('pong', (_) {
      debugPrint('💓 WebSocket: Heartbeat acknowledged');
    });
  }

  /// Handle incoming message
  void _handleMessage(WebSocketEvent event, dynamic data) {
    try {
      final message = WebSocketMessage(
        id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        event: event,
        data: Map<String, dynamic>.from(data),
        senderId: data['senderId'],
        receiverId: data['receiverId'],
      );

      debugPrint('📨 WebSocket: Handling ${event.name}');
      _messageController.add(message);
    } catch (e) {
      debugPrint('🔴 WebSocket: Error handling message: $e');
    }
  }

  /// Send a message through WebSocket
  Future<void> sendMessage(WebSocketMessage message) async {
    if (!isConnected) {
      debugPrint('🔴 WebSocket: Cannot send message - not connected');
      throw Exception('WebSocket not connected');
    }

    try {
      final eventName = _getEventName(message.event);
      debugPrint('📤 WebSocket: Sending ${message.event.name}');

      _socket!.emit(eventName, message.toJson());
    } catch (e) {
      debugPrint('🔴 WebSocket: Error sending message: $e');
      rethrow;
    }
  }

  /// Send user presence status
  void _sendUserPresence(bool isOnline) {
    if (!isConnected || _currentUserId == null) return;

    final message = WebSocketMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      event: isOnline ? WebSocketEvent.userOnline : WebSocketEvent.userOffline,
      data: {
        'userId': _currentUserId,
        'role': _userRole,
        'timestamp': DateTime.now().toIso8601String(),
      },
      senderId: _currentUserId,
    );

    sendMessage(message).catchError((e) {
      debugPrint('🔴 WebSocket: Error sending presence: $e');
    });
  }

  /// Send typing indicator
  Future<void> sendTypingIndicator({
    required String receiverId,
    required bool isTyping,
  }) async {
    final message = WebSocketMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      event: isTyping
          ? WebSocketEvent.userTyping
          : WebSocketEvent.userStoppedTyping,
      data: {
        'receiverId': receiverId,
        'isTyping': isTyping,
      },
      senderId: _currentUserId,
      receiverId: receiverId,
    );

    await sendMessage(message);
  }

  /// Send chat message
  Future<void> sendChatMessage({
    required String receiverId,
    required String content,
    String? messageType,
    Map<String, dynamic>? metadata,
  }) async {
    final message = WebSocketMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      event: WebSocketEvent.messageSent,
      data: {
        'content': content,
        'messageType': messageType ?? 'text',
        'metadata': metadata ?? {},
      },
      senderId: _currentUserId,
      receiverId: receiverId,
    );

    await sendMessage(message);
  }

  /// Initiate video call
  Future<void> initiateCall({
    required String receiverId,
    required String callType, // 'video' or 'audio'
    Map<String, dynamic>? callData,
  }) async {
    final message = WebSocketMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      event: WebSocketEvent.callInitiated,
      data: {
        'callType': callType,
        'callData': callData ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      },
      senderId: _currentUserId,
      receiverId: receiverId,
    );

    await sendMessage(message);
  }

  /// Accept incoming call
  Future<void> acceptCall({
    required String callId,
    required String callerId,
    Map<String, dynamic>? callData,
  }) async {
    final message = WebSocketMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      event: WebSocketEvent.callAccepted,
      data: {
        'callId': callId,
        'callData': callData ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      },
      senderId: _currentUserId,
      receiverId: callerId,
    );

    await sendMessage(message);
  }

  /// Reject incoming call
  Future<void> rejectCall({
    required String callId,
    required String callerId,
    String? reason,
    Map<String, dynamic>? callData,
  }) async {
    final message = WebSocketMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      event: WebSocketEvent.callRejected,
      data: {
        'callId': callId,
        'reason': reason ?? 'Call rejected',
        'callData': callData ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      },
      senderId: _currentUserId,
      receiverId: callerId,
    );

    await sendMessage(message);
  }

  /// End ongoing call
  Future<void> endCall({
    required String callId,
    required String receiverId,
    Map<String, dynamic>? callData,
  }) async {
    final message = WebSocketMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      event: WebSocketEvent.callEnded,
      data: {
        'callId': callId,
        'callData': callData ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      },
      senderId: _currentUserId,
      receiverId: receiverId,
    );

    await sendMessage(message);
  }

  /// Update mentor availability status
  Future<void> updateMentorStatus({
    required bool isAvailable,
    String? statusMessage,
    Map<String, dynamic>? statusData,
  }) async {
    final event = isAvailable
        ? WebSocketEvent.mentorAvailable
        : WebSocketEvent.mentorBusy;

    final message = WebSocketMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      event: event,
      data: {
        'isAvailable': isAvailable,
        'statusMessage': statusMessage ??
            (isAvailable ? 'Available for sessions' : 'Currently busy'),
        'statusData': statusData ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      },
      senderId: _currentUserId,
    );

    await sendMessage(message);
  }

  /// Send student help request
  Future<void> requestHelp({
    required String mentorId,
    required String subject,
    String? message,
    String? urgency, // 'low', 'medium', 'high'
    Map<String, dynamic>? requestData,
  }) async {
    final requestMessage = WebSocketMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      event: WebSocketEvent.studentRequestHelp,
      data: {
        'subject': subject,
        'message': message ?? '',
        'urgency': urgency ?? 'medium',
        'requestData': requestData ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      },
      senderId: _currentUserId,
      receiverId: mentorId,
    );

    await sendMessage(requestMessage);
  }

  /// Join session
  Future<void> joinSession({
    required String sessionId,
    Map<String, dynamic>? sessionData,
  }) async {
    final message = WebSocketMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      event: WebSocketEvent.sessionJoined,
      data: {
        'sessionId': sessionId,
        'sessionData': sessionData ?? {},
        'userId': _currentUserId,
        'userRole': _userRole,
      },
      senderId: _currentUserId,
    );

    await sendMessage(message);
  }

  /// Get event name for socket emission
  String _getEventName(WebSocketEvent event) {
    switch (event) {
      case WebSocketEvent.userOnline:
        return 'user_online';
      case WebSocketEvent.userOffline:
        return 'user_offline';
      case WebSocketEvent.userTyping:
        return 'user_typing';
      case WebSocketEvent.userStoppedTyping:
        return 'user_stopped_typing';
      case WebSocketEvent.messageSent:
        return 'send_message';
      case WebSocketEvent.callInitiated:
        return 'initiate_call';
      case WebSocketEvent.callAccepted:
        return 'accept_call';
      case WebSocketEvent.callRejected:
        return 'reject_call';
      case WebSocketEvent.callEnded:
        return 'end_call';
      case WebSocketEvent.mentorAvailable:
        return 'mentor_available';
      case WebSocketEvent.mentorBusy:
        return 'mentor_busy';
      case WebSocketEvent.studentRequestHelp:
        return 'student_request_help';
      case WebSocketEvent.sessionJoined:
        return 'join_session';
      case WebSocketEvent.sessionLeft:
        return 'leave_session';
      default:
        return event.name;
    }
  }

  /// Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (isConnected) {
        debugPrint('💓 WebSocket: Sending heartbeat');
        _socket!.emit('ping', {'timestamp': DateTime.now().toIso8601String()});
      }
    });
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('🔴 WebSocket: Max reconnection attempts reached');
      _updateConnectionState(WebSocketConnectionState.error);
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_connectionState != WebSocketConnectionState.connected) {
        _reconnectAttempts++;
        debugPrint('🔄 WebSocket: Reconnection attempt $_reconnectAttempts');
        _updateConnectionState(WebSocketConnectionState.reconnecting);

        if (_currentUserId != null && _userRole != null) {
          connect(
            userId: _currentUserId!,
            userRole: _userRole!,
          );
        }
      }
    });
  }

  /// Update connection state
  void _updateConnectionState(WebSocketConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _connectionStateController.add(state);
      debugPrint('🌐 WebSocket: State changed to ${state.name}');
    }
  }

  /// Get default server URL
  String _getDefaultServerUrl() {
    // In production, this should come from environment config
    if (kDebugMode) {
      return 'http://localhost:3000'; // Local development server
    } else {
      return 'wss://your-production-server.com'; // Production server
    }
  }

  /// Disconnect WebSocket
  Future<void> disconnect() async {
    debugPrint('🌐 WebSocket: Disconnecting...');

    // Send user offline status
    _sendUserPresence(false);

    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    _updateConnectionState(WebSocketConnectionState.disconnected);

    _currentUserId = null;
    _userRole = null;
    _reconnectAttempts = 0;
  }

  /// Dispose service
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _messageController.close();
  }
}

/// Riverpod providers for WebSocket service
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService.instance;
});

final webSocketConnectionStateProvider =
    StreamProvider<WebSocketConnectionState>((ref) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  return webSocketService.connectionStateStream;
});

final webSocketMessageProvider = StreamProvider<WebSocketMessage>((ref) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  return webSocketService.messageStream;
});
