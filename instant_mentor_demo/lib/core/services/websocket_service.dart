import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/feature_flags.dart';

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
    final json = <String, dynamic>{
      'id': id,
      'event': event.name,
      'timestamp': timestamp.toIso8601String(),
    };

    // Filter out null values from data map
    final filteredData = <String, dynamic>{};
    data.forEach((key, value) {
      if (value != null) {
        filteredData[key] = value;
      }
    });
    json['data'] = filteredData;

    if (senderId != null) {
      json['senderId'] = senderId!;
    }

    if (receiverId != null) {
      json['receiverId'] = receiverId!;
    }

    return json;
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
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  // Phase 2 Day 13: Enhanced reconnection with jitter backoff
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(minutes: 5);
  static const double _jitterFactor = 0.3; // 30% jitter

  // Phase 2 Day 13: Offline message queue
  final List<WebSocketMessage> _offlineMessageQueue = [];
  static const int _maxOfflineQueueSize = 100;

  // Phase 2 Day 13: Network connectivity monitoring
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = true;

  // Exponential backoff calculator
  Duration _calculateBackoffDelay() {
    final baseDelay = _initialReconnectDelay.inMilliseconds *
        math.pow(2, _reconnectAttempts.clamp(0, 10));
    final maxDelay = _maxReconnectDelay.inMilliseconds;
    final delay = math.min(baseDelay.toInt(), maxDelay);

    // Add jitter to prevent thundering herd
    final jitter = delay * _jitterFactor * (math.Random().nextDouble() - 0.5);
    final finalDelay = (delay + jitter).toInt().clamp(1000, maxDelay);

    return Duration(milliseconds: finalDelay);
  }

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

    // Unified gating: if realtime is disabled OR demo mode active, skip.
    if (!FeatureFlags.realtimeEnabled) {
      debugPrint('🌐 WebSocket: Realtime disabled (REALTIME_ENABLED=false)');
      _updateConnectionState(WebSocketConnectionState.disconnected);
      return;
    }

    if (FeatureFlags.demoMode) {
      debugPrint('🌐 WebSocket: Skipping connection (DEMO_MODE=true)');
      _updateConnectionState(WebSocketConnectionState.disconnected);
      return;
    }

    _currentUserId = userId;
    _userRole = userRole;

    String wsUrl = serverUrl?.trim().isNotEmpty == true
        ? serverUrl!.trim()
        : (FeatureFlags.realtimeServerUrl.isNotEmpty
            ? FeatureFlags.realtimeServerUrl
            : _getDefaultServerUrl());

    // Treat placeholder production host as "disabled" to avoid endless failing reconnects.
    if (wsUrl.contains('your-production-server.com')) {
      debugPrint(
          '🌐 WebSocket: Placeholder production URL detected -> disabling connection (demo mode)');
      wsUrl = '';
    }

    // Guard against accidental ws urls that resolve to an unsafe port or ":0" (seen in console logs)
    if (wsUrl.endsWith(':0')) {
      debugPrint(
          '🚫 WebSocket: Detected invalid :0 port in "$wsUrl" -> disabling connection');
      wsUrl = '';
    }

    // Skip connection if URL is empty (demo mode)
    if (wsUrl.isEmpty) {
      debugPrint('🌐 WebSocket: No server URL resolved; skipping connection');
      _updateConnectionState(WebSocketConnectionState.disconnected);
      return;
    }

    // Phase 2 Day 13: Setup network connectivity monitoring
    _setupNetworkMonitoring();

    debugPrint('🌐 WebSocket: Connecting to $wsUrl');

    _updateConnectionState(WebSocketConnectionState.connecting);

    try {
      _socket = IO.io(wsUrl, {
        'transports': ['websocket'],
        'autoConnect': false,
        'timeout': 20000,
        'reconnection': false, // We handle reconnection manually
        'auth': {
          'userId': userId,
          'userRole': userRole,
        },
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
      _scheduleEnhancedReconnect();
    }
  }

  /// Phase 2 Day 13: Setup network connectivity monitoring
  void _setupNetworkMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) {
        final wasOnline = _isOnline;
        _isOnline = result != ConnectivityResult.none;

        debugPrint('🌐 Network status: ${_isOnline ? 'Online' : 'Offline'}');

        if (!wasOnline && _isOnline) {
          // Network restored - attempt immediate reconnect
          debugPrint('🌐 Network restored, attempting reconnection');
          if (!isConnected) {
            _attemptReconnection();
          } else {
            // Flush offline queue if already connected
            _flushOfflineQueue();
          }
        } else if (wasOnline && !_isOnline) {
          // Network lost
          debugPrint('🔴 Network lost');
        }
      },
    );
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

      // Phase 2 Day 13: Flush offline message queue
      _flushOfflineQueue();
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

  /// Send a message through WebSocket with Phase 2 Day 13 offline queue support
  Future<void> sendMessage(WebSocketMessage message) async {
    return _sendMessage(message);
  }

  /// Internal method to send message with offline queue control
  Future<void> _sendMessage(WebSocketMessage message,
      {bool retryOffline = true}) async {
    if (!isConnected) {
      if (retryOffline && !_isOnline) {
        debugPrint('📥 WebSocket: Offline - queuing message');
        _queueOfflineMessage(message);
        return;
      } else {
        debugPrint('🔴 WebSocket: Cannot send message - not connected');
        throw Exception('WebSocket not connected');
      }
    }

    try {
      final eventName = _getEventName(message.event);
      debugPrint('📤 WebSocket: Sending ${message.event.name}');

      _socket!.emit(eventName, message.toJson());
    } catch (e) {
      debugPrint('🔴 WebSocket: Error sending message: $e');

      if (retryOffline) {
        // Queue message for retry when connection is restored
        _queueOfflineMessage(message);
      }

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

  /// Phase 2 Day 13: Enhanced reconnection with exponential backoff and jitter
  void _scheduleEnhancedReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
          '🔴 WebSocket: Max reconnection attempts reached ($_reconnectAttempts/$_maxReconnectAttempts)');
      _updateConnectionState(WebSocketConnectionState.error);
      // Reset attempts to prevent further reconnection tries
      _reconnectAttempts = 0;
      return;
    }

    if (!_isOnline) {
      debugPrint('🔴 WebSocket: Offline, skipping reconnection attempt');
      return;
    }

    // Cancel any existing reconnection timer
    _reconnectTimer?.cancel();

    final backoffDelay = _calculateBackoffDelay();

    debugPrint(
        '🔄 WebSocket: Scheduling reconnection attempt ${_reconnectAttempts + 1} '
        'in ${backoffDelay.inSeconds}s');

    _reconnectTimer = Timer(backoffDelay, () {
      _attemptReconnection();
    });
  }

  /// Phase 2 Day 13: Attempt reconnection
  void _attemptReconnection() {
    if (_connectionState == WebSocketConnectionState.connected) {
      return; // Already connected
    }

    // Check if we've reached max attempts before incrementing
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
          '🔴 WebSocket: Max reconnection attempts already reached, stopping');
      return;
    }

    _reconnectAttempts++;
    debugPrint('🔄 WebSocket: Reconnection attempt $_reconnectAttempts');
    _updateConnectionState(WebSocketConnectionState.reconnecting);

    if (_currentUserId != null && _userRole != null) {
      connect(
        userId: _currentUserId!,
        userRole: _userRole!,
      );
    } else {
      debugPrint('🔴 WebSocket: Cannot reconnect - missing user credentials');
    }
  }

  /// Legacy reconnect method - now uses enhanced version
  void _scheduleReconnect() {
    _scheduleEnhancedReconnect();
  }

  /// Phase 2 Day 13: Flush offline message queue
  void _flushOfflineQueue() {
    if (_offlineMessageQueue.isEmpty || !isConnected) {
      return;
    }

    debugPrint(
        '📤 WebSocket: Flushing ${_offlineMessageQueue.length} offline messages');

    final messagesToSend = List<WebSocketMessage>.from(_offlineMessageQueue);
    _offlineMessageQueue.clear();

    for (final message in messagesToSend) {
      _sendMessage(message, retryOffline: false);
    }

    debugPrint('✅ WebSocket: Offline queue flushed');
  }

  /// Phase 2 Day 13: Queue message for offline sending
  void _queueOfflineMessage(WebSocketMessage message) {
    if (_offlineMessageQueue.length >= _maxOfflineQueueSize) {
      // Remove oldest message to make room
      _offlineMessageQueue.removeAt(0);
      debugPrint('⚠️ WebSocket: Offline queue full, removed oldest message');
    }

    _offlineMessageQueue.add(message);
    debugPrint(
        '📥 WebSocket: Queued message for offline sending (${_offlineMessageQueue.length} in queue)');
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
    // If feature flags specify an override, it is handled earlier.
    if (kDebugMode) {
      return 'http://localhost:3000';
    }
    return '';
  }

  /// Disconnect WebSocket
  Future<void> disconnect() async {
    debugPrint('🌐 WebSocket: Disconnecting...');

    // Send user offline status
    _sendUserPresence(false);

    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    // Phase 2 Day 13: Cancel network monitoring
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    _updateConnectionState(WebSocketConnectionState.disconnected);

    _currentUserId = null;
    _userRole = null;
    _reconnectAttempts = 0;

    // Clear offline queue on disconnect
    _offlineMessageQueue.clear();
  }

  /// Dispose service
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _messageController.close();
    _connectivitySubscription?.cancel();
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
