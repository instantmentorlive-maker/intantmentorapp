enum MessageType { text, image, file, voice, system }

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String content;
  final List<String> attachments;
  final DateTime timestamp;
  final bool isRead;
  final String? replyToId;
  final bool isSent; // Phase 2 Day 14: Track if message was successfully sent

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    this.attachments = const [],
    required this.timestamp,
    this.isRead = false,
    this.replyToId,
    this.isSent = false, // Phase 2 Day 14: Default to unsent
  });

  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    MessageType? type,
    String? content,
    List<String>? attachments,
    DateTime? timestamp,
    bool? isRead,
    String? replyToId,
    bool? isSent,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      type: type ?? this.type,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      replyToId: replyToId ?? this.replyToId,
      isSent: isSent ?? this.isSent,
    );
  }

  // Phase 2 Day 14: JSON serialization for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name,
      'content': content,
      'attachments': attachments,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'replyToId': replyToId,
      'isSent': isSent,
    };
  }

  // Phase 2 Day 14: JSON deserialization for local storage
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      chatId: json['chatId'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      type: MessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MessageType.text,
      ),
      content: json['content'],
      attachments: List<String>.from(json['attachments'] ?? []),
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
      replyToId: json['replyToId'],
      isSent: json['isSent'] ?? false,
    );
  }
}

class ChatThread {
  final String id;
  final String studentId;
  final String studentName;
  final String mentorId;
  final String mentorName;
  final List<ChatMessage> messages;
  final DateTime lastActivity;
  final int unreadCount;
  final String? subject;

  const ChatThread({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.mentorId,
    required this.mentorName,
    this.messages = const [],
    required this.lastActivity,
    this.unreadCount = 0,
    this.subject,
  });

  ChatThread copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? mentorId,
    String? mentorName,
    List<ChatMessage>? messages,
    DateTime? lastActivity,
    int? unreadCount,
    String? subject,
  }) {
    return ChatThread(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      mentorId: mentorId ?? this.mentorId,
      mentorName: mentorName ?? this.mentorName,
      messages: messages ?? this.messages,
      lastActivity: lastActivity ?? this.lastActivity,
      unreadCount: unreadCount ?? this.unreadCount,
      subject: subject ?? this.subject,
    );
  }

  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;

  // JSON serialization for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'mentorId': mentorId,
      'mentorName': mentorName,
      'messages': messages.map((m) => m.toJson()).toList(),
      'lastActivity': lastActivity.toIso8601String(),
      'unreadCount': unreadCount,
      'subject': subject,
    };
  }

  // JSON deserialization for local storage
  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id'],
      studentId: json['studentId'],
      studentName: json['studentName'],
      mentorId: json['mentorId'],
      mentorName: json['mentorName'],
      messages: (json['messages'] as List?)
              ?.map((m) => ChatMessage.fromJson(m))
              .toList() ??
          [],
      lastActivity: DateTime.parse(json['lastActivity']),
      unreadCount: json['unreadCount'] ?? 0,
      subject: json['subject'],
    );
  }
}

class ResourceTemplate {
  final String id;
  final String mentorId;
  final String title;
  final String content;
  final String subject;
  final List<String> tags;
  final List<String> attachments;
  final DateTime createdAt;
  final int usageCount;

  const ResourceTemplate({
    required this.id,
    required this.mentorId,
    required this.title,
    required this.content,
    required this.subject,
    this.tags = const [],
    this.attachments = const [],
    required this.createdAt,
    this.usageCount = 0,
  });
}
