import 'dart:async';
import 'dart:developer' as developer;
import 'socketio_client.dart';

/// Message types for real-time communication
enum MessageType {
  text,
  image,
  file,
  audio,
  video,
  location,
  system,
  typing,
  delivery,
  read,
}

/// Message status
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

/// Message priority levels
enum MessagePriority {
  low,
  normal,
  high,
  urgent,
}

/// Real-time message model
class RealtimeMessage {
  final String id;
  final String senderId;
  final String? recipientId;
  final String? roomId;
  final MessageType type;
  final String content;
  final Map<String, dynamic>? metadata;
  final MessageStatus status;
  final MessagePriority priority;
  final DateTime timestamp;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  const RealtimeMessage({
    required this.id,
    required this.senderId,
    this.recipientId,
    this.roomId,
    required this.type,
    required this.content,
    this.metadata,
    this.status = MessageStatus.sending,
    this.priority = MessagePriority.normal,
    required this.timestamp,
    this.deliveredAt,
    this.readAt,
  });

  RealtimeMessage copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? roomId,
    MessageType? type,
    String? content,
    Map<String, dynamic>? metadata,
    MessageStatus? status,
    MessagePriority? priority,
    DateTime? timestamp,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    return RealtimeMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      roomId: roomId ?? this.roomId,
      type: type ?? this.type,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'senderId': senderId,
      'type': type.name,
      'content': content,
      'status': status.name,
      'priority': priority.name,
      'timestamp': timestamp.toIso8601String(),
    };

    if (recipientId != null) {
      json['recipientId'] = recipientId;
    }

    if (roomId != null) {
      json['roomId'] = roomId;
    }

    if (metadata != null) {
      json['metadata'] = metadata;
    }

    if (deliveredAt != null) {
      json['deliveredAt'] = deliveredAt!.toIso8601String();
    }

    if (readAt != null) {
      json['readAt'] = readAt!.toIso8601String();
    }

    return json;
  }

  factory RealtimeMessage.fromJson(Map<String, dynamic> json) {
    return RealtimeMessage(
      id: json['id'],
      senderId: json['senderId'],
      recipientId: json['recipientId'],
      roomId: json['roomId'],
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      content: json['content'],
      metadata: json['metadata'],
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      priority: MessagePriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => MessagePriority.normal,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'])
          : null,
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
    );
  }
}

/// Typing indicator
class TypingIndicator {
  final String userId;
  final String? roomId;
  final DateTime timestamp;

  const TypingIndicator({
    required this.userId,
    this.roomId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'roomId': roomId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TypingIndicator.fromJson(Map<String, dynamic> json) {
    return TypingIndicator(
      userId: json['userId'],
      roomId: json['roomId'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// User presence status
enum PresenceStatus {
  online,
  away,
  busy,
  offline,
}

/// User presence information
class UserPresence {
  final String userId;
  final PresenceStatus status;
  final String? customStatus;
  final DateTime lastSeen;
  final Map<String, dynamic>? metadata;

  const UserPresence({
    required this.userId,
    required this.status,
    this.customStatus,
    required this.lastSeen,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'status': status.name,
      'customStatus': customStatus,
      'lastSeen': lastSeen.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory UserPresence.fromJson(Map<String, dynamic> json) {
    return UserPresence(
      userId: json['userId'],
      status: PresenceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PresenceStatus.offline,
      ),
      customStatus: json['customStatus'],
      lastSeen: DateTime.parse(json['lastSeen']),
      metadata: json['metadata'],
    );
  }
}

/// Real-time messaging service
class RealtimeMessagingService {
  static RealtimeMessagingService? _instance;
  static RealtimeMessagingService get instance =>
      _instance ??= RealtimeMessagingService._();

  RealtimeMessagingService._();

  final SocketIOClient _socketClient = SocketIOClient.instance;
  String? _currentUserId;
  final Map<String, List<String>> _roomMembers = {};
  final Map<String, UserPresence> _userPresences = {};
  final Map<String, TypingIndicator> _typingUsers = {};

  // Message streams
  final StreamController<RealtimeMessage> _messageController =
      StreamController<RealtimeMessage>.broadcast();
  final StreamController<TypingIndicator> _typingController =
      StreamController<TypingIndicator>.broadcast();
  final StreamController<UserPresence> _presenceController =
      StreamController<UserPresence>.broadcast();

  // Message cache for offline handling
  final List<RealtimeMessage> _pendingMessages = [];
  final Map<String, RealtimeMessage> _messageCache = {};

  /// Get message stream
  Stream<RealtimeMessage> get messages => _messageController.stream;

  /// Get typing indicators stream
  Stream<TypingIndicator> get typingIndicators => _typingController.stream;

  /// Get presence updates stream
  Stream<UserPresence> get presenceUpdates => _presenceController.stream;

  /// Get user presences
  Map<String, UserPresence> get userPresences => Map.from(_userPresences);

  /// Get typing users
  Map<String, TypingIndicator> get typingUsers => Map.from(_typingUsers);

  /// Initialize messaging service
  Future<bool> initialize({
    required String userId,
    required String serverUrl,
    Map<String, dynamic>? auth,
  }) async {
    _currentUserId = userId;

    // Connect to Socket.IO server
    final config = SocketConfig(
      auth: auth ?? {},
      reconnectionAttempts: 10,
    );

    final connected = await _socketClient.connect(serverUrl, config: config);
    if (!connected) {
      developer.log('Failed to connect to messaging server',
          name: 'RealtimeMessagingService');
      return false;
    }

    // Setup event listeners
    _setupEventListeners();

    // Register user
    _socketClient.emit('user:register', {'userId': userId});

    developer.log('Messaging service initialized for user: $userId',
        name: 'RealtimeMessagingService');
    return true;
  }

  /// Send message
  Future<void> sendMessage({
    required String content,
    String? recipientId,
    String? roomId,
    MessageType type = MessageType.text,
    MessagePriority priority = MessagePriority.normal,
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentUserId == null) {
      throw Exception('Messaging service not initialized');
    }

    final message = RealtimeMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: _currentUserId!,
      recipientId: recipientId,
      roomId: roomId,
      type: type,
      content: content,
      metadata: metadata,
      priority: priority,
      timestamp: DateTime.now(),
    );

    // Add to pending messages
    _pendingMessages.add(message);
    _messageCache[message.id] = message;

    // Emit to server
    try {
      _socketClient.emit('message:send', message.toJson());
      developer.log('Message sent: ${message.id}',
          name: 'RealtimeMessagingService');
    } catch (e) {
      developer.log('Failed to send message: $e',
          name: 'RealtimeMessagingService');

      // Update message status to failed
      final failedMessage = message.copyWith(status: MessageStatus.failed);
      _messageCache[message.id] = failedMessage;
      _messageController.add(failedMessage);
    }
  }

  /// Mark message as read
  void markAsRead(String messageId) {
    _socketClient.emit('message:read', {
      'messageId': messageId,
      'userId': _currentUserId,
    });
  }

  /// Start typing indicator
  void startTyping({String? recipientId, String? roomId}) {
    if (_currentUserId == null) return;

    _socketClient.emit('typing:start', {
      'userId': _currentUserId,
      'recipientId': recipientId,
      'roomId': roomId,
    });
  }

  /// Stop typing indicator
  void stopTyping({String? recipientId, String? roomId}) {
    if (_currentUserId == null) return;

    _socketClient.emit('typing:stop', {
      'userId': _currentUserId,
      'recipientId': recipientId,
      'roomId': roomId,
    });
  }

  /// Update user presence
  void updatePresence(PresenceStatus status, {String? customStatus}) {
    if (_currentUserId == null) return;

    _socketClient.emit('presence:update', {
      'userId': _currentUserId,
      'status': status.name,
      'customStatus': customStatus,
    });
  }

  /// Join room
  void joinRoom(String roomId) {
    _socketClient.joinRoom(roomId);
  }

  /// Leave room
  void leaveRoom(String roomId) {
    _socketClient.leaveRoom(roomId);
  }

  /// Get room members
  List<String> getRoomMembers(String roomId) {
    return _roomMembers[roomId] ?? [];
  }

  /// Setup event listeners
  void _setupEventListeners() {
    // Message events
    _socketClient.on('message:received', (data) {
      try {
        final message = RealtimeMessage.fromJson(data);
        _messageController.add(message);
        developer.log('Message received: ${message.id}',
            name: 'RealtimeMessagingService');
      } catch (e) {
        developer.log('Error parsing received message: $e',
            name: 'RealtimeMessagingService');
      }
    });

    _socketClient.on('message:delivered', (data) {
      try {
        final messageId = data['messageId'];
        if (_messageCache.containsKey(messageId)) {
          final message = _messageCache[messageId]!.copyWith(
            status: MessageStatus.delivered,
            deliveredAt: DateTime.now(),
          );
          _messageCache[messageId] = message;
          _messageController.add(message);
        }
      } catch (e) {
        developer.log('Error processing message delivery: $e',
            name: 'RealtimeMessagingService');
      }
    });

    _socketClient.on('message:read', (data) {
      try {
        final messageId = data['messageId'];
        if (_messageCache.containsKey(messageId)) {
          final message = _messageCache[messageId]!.copyWith(
            status: MessageStatus.read,
            readAt: DateTime.now(),
          );
          _messageCache[messageId] = message;
          _messageController.add(message);
        }
      } catch (e) {
        developer.log('Error processing message read: $e',
            name: 'RealtimeMessagingService');
      }
    });

    // Typing indicators
    _socketClient.on('typing:start', (data) {
      try {
        final typing = TypingIndicator.fromJson(data);
        if (typing.userId != _currentUserId) {
          _typingUsers[typing.userId] = typing;
          _typingController.add(typing);
        }
      } catch (e) {
        developer.log('Error processing typing start: $e',
            name: 'RealtimeMessagingService');
      }
    });

    _socketClient.on('typing:stop', (data) {
      try {
        final userId = data['userId'];
        if (_typingUsers.containsKey(userId)) {
          _typingUsers.remove(userId);
        }
      } catch (e) {
        developer.log('Error processing typing stop: $e',
            name: 'RealtimeMessagingService');
      }
    });

    // Presence updates
    _socketClient.on('presence:update', (data) {
      try {
        final presence = UserPresence.fromJson(data);
        _userPresences[presence.userId] = presence;
        _presenceController.add(presence);
        developer.log(
            'Presence updated: ${presence.userId} - ${presence.status.name}',
            name: 'RealtimeMessagingService');
      } catch (e) {
        developer.log('Error processing presence update: $e',
            name: 'RealtimeMessagingService');
      }
    });

    // Room events
    _socketClient.on('room:joined', (data) {
      try {
        final roomId = data['roomId'];
        final members = List<String>.from(data['members']);
        _roomMembers[roomId] = members;
        developer.log('Joined room: $roomId with ${members.length} members',
            name: 'RealtimeMessagingService');
      } catch (e) {
        developer.log('Error processing room join: $e',
            name: 'RealtimeMessagingService');
      }
    });

    _socketClient.on('room:member_joined', (data) {
      try {
        final roomId = data['roomId'];
        final userId = data['userId'];
        if (_roomMembers.containsKey(roomId)) {
          _roomMembers[roomId]!.add(userId);
        }
        developer.log('Member joined room: $userId -> $roomId',
            name: 'RealtimeMessagingService');
      } catch (e) {
        developer.log('Error processing member join: $e',
            name: 'RealtimeMessagingService');
      }
    });

    _socketClient.on('room:member_left', (data) {
      try {
        final roomId = data['roomId'];
        final userId = data['userId'];
        if (_roomMembers.containsKey(roomId)) {
          _roomMembers[roomId]!.remove(userId);
        }
        developer.log('Member left room: $userId <- $roomId',
            name: 'RealtimeMessagingService');
      } catch (e) {
        developer.log('Error processing member leave: $e',
            name: 'RealtimeMessagingService');
      }
    });

    // Connection events
    _socketClient.on('connect', (_) {
      // Resend pending messages
      for (final message in _pendingMessages) {
        _socketClient.emit('message:send', message.toJson());
      }
      _pendingMessages.clear();
    });
  }

  /// Get message stream for specific room
  Stream<RealtimeMessage> getMessagesForRoom(String roomId) {
    return _messageController.stream.where(
      (message) => message.roomId == roomId,
    );
  }

  /// Get message stream for specific user
  Stream<RealtimeMessage> getMessagesForUser(String userId) {
    return _messageController.stream.where(
      (message) => message.recipientId == userId || message.senderId == userId,
    );
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _messageController.close();
    await _typingController.close();
    await _presenceController.close();
    developer.log('Messaging service disposed',
        name: 'RealtimeMessagingService');
  }
}
