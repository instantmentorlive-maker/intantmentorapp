import 'dart:async';
import 'dart:developer' as developer;
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Socket.IO event data
class SocketEvent {
  final String event;
  final dynamic data;
  final DateTime timestamp;

  const SocketEvent({
    required this.event,
    required this.data,
    required this.timestamp,
  });

  factory SocketEvent.create(String event, dynamic data) => SocketEvent(
        event: event,
        data: data,
        timestamp: DateTime.now(),
      );
}

/// Socket.IO connection state
enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Socket.IO client statistics
class SocketStats {
  final int totalConnections;
  final int totalDisconnections;
  final int totalEvents;
  final int totalErrors;
  final Duration totalUptime;
  final DateTime lastConnected;
  final DateTime? lastDisconnected;
  final Map<String, int> eventCounts;
  final List<String> recentErrors;

  const SocketStats({
    required this.totalConnections,
    required this.totalDisconnections,
    required this.totalEvents,
    required this.totalErrors,
    required this.totalUptime,
    required this.lastConnected,
    this.lastDisconnected,
    required this.eventCounts,
    required this.recentErrors,
  });
}

/// Configuration for Socket.IO client
class SocketConfig {
  final Duration timeout;
  final bool enableAutoConnect;
  final bool enableReconnection;
  final int reconnectionAttempts;
  final Duration reconnectionDelay;
  final bool enableLogging;
  final Map<String, dynamic> auth;
  final Map<String, dynamic> extraHeaders;

  const SocketConfig({
    this.timeout = const Duration(seconds: 20),
    this.enableAutoConnect = false,
    this.enableReconnection = true,
    this.reconnectionAttempts = 5,
    this.reconnectionDelay = const Duration(seconds: 1),
    this.enableLogging = true,
    this.auth = const {},
    this.extraHeaders = const {},
  });
}

/// Advanced Socket.IO client for real-time communication
class SocketIOClient {
  static SocketIOClient? _instance;
  static SocketIOClient get instance => _instance ??= SocketIOClient._();
  
  SocketIOClient._();

  // Core Socket.IO components
  io.Socket? _socket;
  SocketConnectionState _connectionState = SocketConnectionState.disconnected;
  SocketConfig _config = const SocketConfig();

  // Event streaming
  final StreamController<SocketEvent> _eventController = 
      StreamController<SocketEvent>.broadcast();
  final Map<String, StreamController<dynamic>> _eventStreams = {};

  // Statistics tracking
  int _totalConnections = 0;
  int _totalDisconnections = 0;
  int _totalEvents = 0;
  int _totalErrors = 0;
  DateTime? _connectionStartTime;
  DateTime _lastConnected = DateTime.now();
  DateTime? _lastDisconnected;
  final Map<String, int> _eventCounts = {};
  final List<String> _recentErrors = [];

  /// Get current connection state
  SocketConnectionState get connectionState => _connectionState;

  /// Get all events stream
  Stream<SocketEvent> get events => _eventController.stream;

  /// Get connection statistics
  SocketStats get stats {
    final now = DateTime.now();
    final uptime = _connectionStartTime != null
        ? now.difference(_connectionStartTime!)
        : Duration.zero;

    return SocketStats(
      totalConnections: _totalConnections,
      totalDisconnections: _totalDisconnections,
      totalEvents: _totalEvents,
      totalErrors: _totalErrors,
      totalUptime: uptime,
      lastConnected: _lastConnected,
      lastDisconnected: _lastDisconnected,
      eventCounts: Map.from(_eventCounts),
      recentErrors: List.from(_recentErrors),
    );
  }

  /// Connect to Socket.IO server
  Future<bool> connect(String url, {SocketConfig? config}) async {
    if (_connectionState == SocketConnectionState.connected ||
        _connectionState == SocketConnectionState.connecting) {
      developer.log('Socket.IO already connected or connecting', name: 'SocketIOClient');
      return true;
    }

    _config = config ?? const SocketConfig();
    _connectionState = SocketConnectionState.connecting;

    try {
      developer.log('Connecting to Socket.IO: $url', name: 'SocketIOClient');

      // Configure Socket.IO options
      final options = io.OptionBuilder()
          .setTransports(['websocket'])
          .setReconnectionDelay(_config.reconnectionDelay.inMilliseconds)
          .setTimeout(_config.timeout.inMilliseconds)
          .setExtraHeaders(_config.extraHeaders);

      // Add auth if provided
      if (_config.auth.isNotEmpty) {
        options.setAuth(_config.auth);
      }

      final finalOptions = options.build();

      // Create socket connection
      _socket = io.io(url, finalOptions);

      // Set up event listeners
      _setupEventListeners();

      // Wait for connection
      final completer = Completer<bool>();
      Timer? timeoutTimer;

      void onConnect() {
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }

      void onConnectError(dynamic error) {
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      }

      _socket!.onConnect((_) => onConnect());
      _socket!.onConnectError((error) => onConnectError(error));

      // Set connection timeout
      timeoutTimer = Timer(_config.timeout, () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      // Connect socket
      _socket!.connect();

      final success = await completer.future;

      if (success) {
        _connectionState = SocketConnectionState.connected;
        _totalConnections++;
        _connectionStartTime = DateTime.now();
        _lastConnected = DateTime.now();
        developer.log('Socket.IO connected successfully', name: 'SocketIOClient');
      } else {
        _connectionState = SocketConnectionState.error;
        _addError('Connection failed or timeout');
        developer.log('Socket.IO connection failed', name: 'SocketIOClient');
      }

      return success;
    } catch (e) {
      developer.log('Socket.IO connection error: $e', name: 'SocketIOClient');
      _connectionState = SocketConnectionState.error;
      _addError('Connection error: $e');
      return false;
    }
  }

  /// Disconnect from Socket.IO server
  Future<void> disconnect() async {
    developer.log('Disconnecting Socket.IO', name: 'SocketIOClient');

    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    _connectionState = SocketConnectionState.disconnected;
    _totalDisconnections++;
    _lastDisconnected = DateTime.now();

    developer.log('Socket.IO disconnected', name: 'SocketIOClient');
  }

  /// Emit event to server
  void emit(String event, [dynamic data]) {
    if (_connectionState != SocketConnectionState.connected || _socket == null) {
      developer.log('Socket.IO not connected, cannot emit event: $event', name: 'SocketIOClient');
      return;
    }

    try {
      _socket!.emit(event, data);
      _totalEvents++;
      _incrementEventCount(event);
      developer.log('Event emitted: $event with data: $data', name: 'SocketIOClient');
    } catch (e) {
      developer.log('Failed to emit event $event: $e', name: 'SocketIOClient');
      _addError('Failed to emit event $event: $e');
    }
  }

  /// Emit event with acknowledgment
  Future<dynamic> emitWithAck(String event, [dynamic data]) async {
    if (_connectionState != SocketConnectionState.connected || _socket == null) {
      throw Exception('Socket.IO not connected');
    }

    final completer = Completer<dynamic>();

    try {
      _socket!.emitWithAck(event, data, ack: (response) {
        if (!completer.isCompleted) {
          completer.complete(response);
        }
      });

      _totalEvents++;
      _incrementEventCount(event);
      
      return await completer.future;
    } catch (e) {
      developer.log('Failed to emit event with ack $event: $e', name: 'SocketIOClient');
      _addError('Failed to emit event with ack $event: $e');
      rethrow;
    }
  }

  /// Listen to specific event
  void on(String event, Function(dynamic) callback) {
    if (_socket == null) {
      developer.log('Socket.IO not initialized, cannot listen to event: $event', name: 'SocketIOClient');
      return;
    }

    _socket!.on(event, (data) {
      _totalEvents++;
      _incrementEventCount(event);
      
      // Add to general event stream
      _eventController.add(SocketEvent.create(event, data));
      
      // Add to specific event stream
      if (_eventStreams.containsKey(event)) {
        _eventStreams[event]!.add(data);
      }

      // Call callback
      callback(data);
    });

    developer.log('Listening to event: $event', name: 'SocketIOClient');
  }

  /// Stop listening to specific event
  void off(String event) {
    if (_socket == null) {
      developer.log('Socket.IO not initialized, cannot stop listening to event: $event', name: 'SocketIOClient');
      return;
    }

    _socket!.off(event);
    
    // Close specific event stream if exists
    if (_eventStreams.containsKey(event)) {
      _eventStreams[event]!.close();
      _eventStreams.remove(event);
    }

    developer.log('Stopped listening to event: $event', name: 'SocketIOClient');
  }

  /// Get stream for specific event
  Stream<dynamic> getEventStream(String event) {
    if (!_eventStreams.containsKey(event)) {
      _eventStreams[event] = StreamController<dynamic>.broadcast();
    }
    return _eventStreams[event]!.stream;
  }

  /// Join a room
  void joinRoom(String room) {
    emit('join', {'room': room});
    developer.log('Joined room: $room', name: 'SocketIOClient');
  }

  /// Leave a room
  void leaveRoom(String room) {
    emit('leave', {'room': room});
    developer.log('Left room: $room', name: 'SocketIOClient');
  }

  /// Send message to room
  void sendToRoom(String room, String event, dynamic data) {
    emit(event, {
      'room': room,
      'data': data,
    });
    developer.log('Sent message to room $room: $event', name: 'SocketIOClient');
  }

  /// Setup default event listeners
  void _setupEventListeners() {
    if (_socket == null) return;

    // Connection events
    _socket!.onConnect((_) {
      developer.log('Socket.IO connected', name: 'SocketIOClient');
      _connectionState = SocketConnectionState.connected;
      _eventController.add(SocketEvent.create('connect', null));
    });

    _socket!.onDisconnect((reason) {
      developer.log('Socket.IO disconnected: $reason', name: 'SocketIOClient');
      _connectionState = SocketConnectionState.disconnected;
      _totalDisconnections++;
      _lastDisconnected = DateTime.now();
      _eventController.add(SocketEvent.create('disconnect', reason));
    });

    _socket!.onConnectError((error) {
      developer.log('Socket.IO connection error: $error', name: 'SocketIOClient');
      _connectionState = SocketConnectionState.error;
      _addError('Connection error: $error');
      _eventController.add(SocketEvent.create('connect_error', error));
    });

    _socket!.onReconnect((attempt) {
      developer.log('Socket.IO reconnected after $attempt attempts', name: 'SocketIOClient');
      _connectionState = SocketConnectionState.connected;
      _eventController.add(SocketEvent.create('reconnect', attempt));
    });

    _socket!.onReconnectError((error) {
      developer.log('Socket.IO reconnection error: $error', name: 'SocketIOClient');
      _addError('Reconnection error: $error');
      _eventController.add(SocketEvent.create('reconnect_error', error));
    });

    _socket!.onReconnectFailed((_) {
      developer.log('Socket.IO reconnection failed', name: 'SocketIOClient');
      _connectionState = SocketConnectionState.error;
      _addError('Reconnection failed');
      _eventController.add(SocketEvent.create('reconnect_failed', null));
    });

    // Generic message handler
    _socket!.onAny((event, data) {
      developer.log('Socket.IO event received: $event with data: $data', name: 'SocketIOClient');
      _eventController.add(SocketEvent.create(event, data));
    });
  }

  /// Increment event count for statistics
  void _incrementEventCount(String event) {
    _eventCounts[event] = (_eventCounts[event] ?? 0) + 1;
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
    _totalDisconnections = 0;
    _totalEvents = 0;
    _totalErrors = 0;
    _eventCounts.clear();
    _recentErrors.clear();
    developer.log('Socket.IO statistics cleared', name: 'SocketIOClient');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await disconnect();
    
    // Close all event streams
    for (final stream in _eventStreams.values) {
      await stream.close();
    }
    _eventStreams.clear();
    
    await _eventController.close();
    developer.log('Socket.IO client disposed', name: 'SocketIOClient');
  }
}
