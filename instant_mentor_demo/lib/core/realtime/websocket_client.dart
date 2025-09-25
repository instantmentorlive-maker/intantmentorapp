import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Connection states for WebSocket
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// WebSocket event types
enum WebSocketEventType {
  message,
  error,
  connect,
  disconnect,
  reconnect,
}

/// WebSocket event data
class WebSocketEvent {
  final WebSocketEventType type;
  final dynamic data;
  final DateTime timestamp;
  final String? error;

  const WebSocketEvent({
    required this.type,
    this.data,
    required this.timestamp,
    this.error,
  });

  factory WebSocketEvent.message(dynamic data) => WebSocketEvent(
        type: WebSocketEventType.message,
        data: data,
        timestamp: DateTime.now(),
      );

  factory WebSocketEvent.error(String error) => WebSocketEvent(
        type: WebSocketEventType.error,
        error: error,
        timestamp: DateTime.now(),
      );

  factory WebSocketEvent.connect() => WebSocketEvent(
        type: WebSocketEventType.connect,
        timestamp: DateTime.now(),
      );

  factory WebSocketEvent.disconnect() => WebSocketEvent(
        type: WebSocketEventType.disconnect,
        timestamp: DateTime.now(),
      );

  factory WebSocketEvent.reconnect() => WebSocketEvent(
        type: WebSocketEventType.reconnect,
        timestamp: DateTime.now(),
      );
}

/// WebSocket connection statistics
class WebSocketStats {
  final int totalConnections;
  final int totalReconnections;
  final int totalMessages;
  final int totalErrors;
  final Duration totalUptime;
  final DateTime lastConnected;
  final DateTime? lastDisconnected;
  final List<String> recentErrors;

  const WebSocketStats({
    required this.totalConnections,
    required this.totalReconnections,
    required this.totalMessages,
    required this.totalErrors,
    required this.totalUptime,
    required this.lastConnected,
    this.lastDisconnected,
    required this.recentErrors,
  });

  WebSocketStats copyWith({
    int? totalConnections,
    int? totalReconnections,
    int? totalMessages,
    int? totalErrors,
    Duration? totalUptime,
    DateTime? lastConnected,
    DateTime? lastDisconnected,
    List<String>? recentErrors,
  }) {
    return WebSocketStats(
      totalConnections: totalConnections ?? this.totalConnections,
      totalReconnections: totalReconnections ?? this.totalReconnections,
      totalMessages: totalMessages ?? this.totalMessages,
      totalErrors: totalErrors ?? this.totalErrors,
      totalUptime: totalUptime ?? this.totalUptime,
      lastConnected: lastConnected ?? this.lastConnected,
      lastDisconnected: lastDisconnected ?? this.lastDisconnected,
      recentErrors: recentErrors ?? this.recentErrors,
    );
  }
}

/// Configuration for WebSocket client
class WebSocketConfig {
  final Duration heartbeatInterval;
  final Duration reconnectDelay;
  final int maxReconnectAttempts;
  final Duration connectionTimeout;
  final bool enableHeartbeat;
  final bool enableReconnect;
  final Map<String, String> headers;
  final List<String> protocols;

  const WebSocketConfig({
    this.heartbeatInterval = const Duration(seconds: 30),
    this.reconnectDelay = const Duration(seconds: 5),
    this.maxReconnectAttempts = 10,
    this.connectionTimeout = const Duration(seconds: 10),
    this.enableHeartbeat = true,
    this.enableReconnect = true,
    this.headers = const {},
    this.protocols = const [],
  });
}

/// Advanced WebSocket client with auto-reconnect and heartbeat
class WebSocketClient {
  static WebSocketClient? _instance;
  static WebSocketClient get instance => _instance ??= WebSocketClient._();

  WebSocketClient._();

  // Core WebSocket components
  WebSocketChannel? _channel;
  StreamSubscription? _messageSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  // Connection state
  WebSocketConnectionState _connectionState =
      WebSocketConnectionState.disconnected;
  String? _currentUrl;
  WebSocketConfig _config = const WebSocketConfig();

  // Event streaming
  final StreamController<WebSocketEvent> _eventController =
      StreamController<WebSocketEvent>.broadcast();

  // Statistics tracking
  int _totalConnections = 0;
  int _totalReconnections = 0;
  int _totalMessages = 0;
  int _totalErrors = 0;
  int _reconnectAttempts = 0;
  DateTime? _connectionStartTime;
  DateTime _lastConnected = DateTime.now();
  DateTime? _lastDisconnected;
  final List<String> _recentErrors = [];

  // Message queue for offline messages
  final List<dynamic> _messageQueue = [];

  /// Get current connection state
  WebSocketConnectionState get connectionState => _connectionState;

  /// Get event stream
  Stream<WebSocketEvent> get events => _eventController.stream;

  /// Get connection statistics
  WebSocketStats get stats {
    final now = DateTime.now();
    final uptime = _connectionStartTime != null
        ? now.difference(_connectionStartTime!)
        : Duration.zero;

    return WebSocketStats(
      totalConnections: _totalConnections,
      totalReconnections: _totalReconnections,
      totalMessages: _totalMessages,
      totalErrors: _totalErrors,
      totalUptime: uptime,
      lastConnected: _lastConnected,
      lastDisconnected: _lastDisconnected,
      recentErrors: List.from(_recentErrors),
    );
  }

  /// Connect to WebSocket server
  Future<bool> connect(String url, {WebSocketConfig? config}) async {
    if (_connectionState == WebSocketConnectionState.connected ||
        _connectionState == WebSocketConnectionState.connecting) {
      developer.log('WebSocket already connected or connecting',
          name: 'WebSocketClient');
      return true;
    }

    _currentUrl = url;
    _config = config ?? const WebSocketConfig();
    _connectionState = WebSocketConnectionState.connecting;

    try {
      developer.log('Connecting to WebSocket: $url', name: 'WebSocketClient');

      // Create WebSocket connection with timeout
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(
        uri,
        protocols: _config.protocols.isNotEmpty ? _config.protocols : null,
      );

      // Wait for connection with timeout
      await Future.any([
        _channel!.ready,
        Future.delayed(_config.connectionTimeout)
            .then((_) => throw const TimeoutException('Connection timeout')),
      ]);

      _connectionState = WebSocketConnectionState.connected;
      _totalConnections++;
      _reconnectAttempts = 0;
      _connectionStartTime = DateTime.now();
      _lastConnected = DateTime.now();

      developer.log('WebSocket connected successfully',
          name: 'WebSocketClient');

      // Start listening to messages
      _listenToMessages();

      // Start heartbeat if enabled
      if (_config.enableHeartbeat) {
        _startHeartbeat();
      }

      // Process queued messages
      _processMessageQueue();

      // Emit connect event
      _eventController.add(WebSocketEvent.connect());

      return true;
    } catch (e) {
      developer.log('WebSocket connection failed: $e', name: 'WebSocketClient');
      _connectionState = WebSocketConnectionState.error;
      _addError('Connection failed: $e');
      _eventController.add(WebSocketEvent.error('Connection failed: $e'));

      if (_config.enableReconnect) {
        _scheduleReconnect();
      }

      return false;
    }
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect({int? closeCode, String? closeReason}) async {
    developer.log('Disconnecting WebSocket', name: 'WebSocketClient');

    _connectionState = WebSocketConnectionState.disconnected;
    _lastDisconnected = DateTime.now();

    // Cancel timers
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Cancel message subscription
    await _messageSubscription?.cancel();
    _messageSubscription = null;

    // Close channel
    await _channel?.sink.close(closeCode ?? status.normalClosure, closeReason);
    _channel = null;

    // Emit disconnect event
    _eventController.add(WebSocketEvent.disconnect());

    developer.log('WebSocket disconnected', name: 'WebSocketClient');
  }

  /// Send message to WebSocket server
  void send(dynamic message) {
    if (_connectionState != WebSocketConnectionState.connected) {
      developer.log('WebSocket not connected, queueing message',
          name: 'WebSocketClient');
      _messageQueue.add(message);
      return;
    }

    try {
      final data = message is String ? message : jsonEncode(message);
      _channel?.sink.add(data);
      _totalMessages++;
      developer.log('Message sent: $data', name: 'WebSocketClient');
    } catch (e) {
      developer.log('Failed to send message: $e', name: 'WebSocketClient');
      _addError('Failed to send message: $e');
      _eventController.add(WebSocketEvent.error('Failed to send message: $e'));
    }
  }

  /// Send JSON message
  void sendJson(Map<String, dynamic> message) {
    send(jsonEncode(message));
  }

  /// Send ping message
  void ping({String? data}) {
    send({'type': 'ping', 'data': data ?? 'ping'});
  }

  /// Reconnect to WebSocket server
  Future<bool> reconnect() async {
    if (_currentUrl == null) {
      developer.log('No previous URL to reconnect to', name: 'WebSocketClient');
      return false;
    }

    await disconnect();
    return await connect(_currentUrl!, config: _config);
  }

  /// Listen to incoming messages
  void _listenToMessages() {
    _messageSubscription = _channel?.stream.listen(
      (message) {
        _totalMessages++;
        developer.log('Message received: $message', name: 'WebSocketClient');

        try {
          dynamic data = message;
          if (message is String) {
            try {
              data = jsonDecode(message);
            } catch (_) {
              // Keep as string if not valid JSON
            }
          }

          _eventController.add(WebSocketEvent.message(data));
        } catch (e) {
          developer.log('Error processing message: $e',
              name: 'WebSocketClient');
          _addError('Error processing message: $e');
        }
      },
      onError: (error) {
        developer.log('WebSocket error: $error', name: 'WebSocketClient');
        _connectionState = WebSocketConnectionState.error;
        _addError('WebSocket error: $error');
        _eventController.add(WebSocketEvent.error('WebSocket error: $error'));

        if (_config.enableReconnect) {
          _scheduleReconnect();
        }
      },
      onDone: () {
        developer.log('WebSocket connection closed', name: 'WebSocketClient');
        _connectionState = WebSocketConnectionState.disconnected;
        _lastDisconnected = DateTime.now();
        _eventController.add(WebSocketEvent.disconnect());

        if (_config.enableReconnect &&
            _reconnectAttempts < _config.maxReconnectAttempts) {
          _scheduleReconnect();
        }
      },
    );
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_config.heartbeatInterval, (timer) {
      if (_connectionState == WebSocketConnectionState.connected) {
        ping();
      } else {
        timer.cancel();
      }
    });
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _config.maxReconnectAttempts) {
      developer.log('Max reconnect attempts reached', name: 'WebSocketClient');
      return;
    }

    _reconnectAttempts++;
    _connectionState = WebSocketConnectionState.reconnecting;
    _eventController.add(WebSocketEvent.reconnect());

    developer.log(
        'Scheduling reconnect attempt $_reconnectAttempts/${_config.maxReconnectAttempts}',
        name: 'WebSocketClient');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_config.reconnectDelay, () async {
      if (_currentUrl != null) {
        _totalReconnections++;
        final success = await connect(_currentUrl!, config: _config);
        if (!success) {
          _scheduleReconnect();
        }
      }
    });
  }

  /// Process queued messages
  void _processMessageQueue() {
    if (_messageQueue.isEmpty) return;

    developer.log('Processing ${_messageQueue.length} queued messages',
        name: 'WebSocketClient');

    final messagesToSend = List.from(_messageQueue);
    _messageQueue.clear();

    for (final message in messagesToSend) {
      send(message);
    }
  }

  /// Add error to recent errors list
  void _addError(String error) {
    _totalErrors++;
    _recentErrors.add(error);

    // Keep only last 10 errors
    if (_recentErrors.length > 10) {
      _recentErrors.removeAt(0);
    }
  }

  /// Clear statistics
  void clearStats() {
    _totalConnections = 0;
    _totalReconnections = 0;
    _totalMessages = 0;
    _totalErrors = 0;
    _reconnectAttempts = 0;
    _recentErrors.clear();
    developer.log('WebSocket statistics cleared', name: 'WebSocketClient');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await disconnect();
    await _eventController.close();
    developer.log('WebSocket client disposed', name: 'WebSocketClient');
  }
}

/// Timeout exception for WebSocket connections
class TimeoutException implements Exception {
  final String message;
  const TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
