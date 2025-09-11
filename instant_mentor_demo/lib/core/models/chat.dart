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
