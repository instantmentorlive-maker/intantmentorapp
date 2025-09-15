import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat.dart';
import 'supabase_service.dart';

/// ChatService encapsulates all chat/thread/message interactions with Supabase.
/// Tables expected:
///  - chat_threads(id uuid pk, student_id uuid, mentor_id uuid, subject text, updated_at timestamptz default now())
///  - chat_messages(id uuid pk, chat_id uuid fk, sender_id uuid, sender_name text, type text, content text, created_at timestamptz default now(), is_read bool default false)
/// Recommended indexes:
///  - on chat_threads (student_id, mentor_id)
///  - on chat_messages (chat_id, created_at)
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  static ChatService get instance => _instance;

  ChatService._internal();

  // Get Supabase client
  SupabaseClient get _client => SupabaseService.instance.client;

  // Add field to store mock messages temporarily
  final Map<String, List<ChatMessage>> _mockMessages = {};

  /// Create a thread if not exists for a student/mentor pair + optional subject.
  Future<String> createOrGetThread({
    required String studentId,
    required String mentorId,
    String? subject,
  }) async {
    try {
      final existing = await _client
          .from('chat_threads')
          .select('id')
          .eq('student_id', studentId)
          .eq('mentor_id', mentorId)
          .maybeSingle();
      if (existing != null) return existing['id'] as String;

      final inserted = await _client
          .from('chat_threads')
          .insert({
            'student_id': studentId,
            'mentor_id': mentorId,
            if (subject != null) 'subject': subject,
          })
          .select('id')
          .single();
      return inserted['id'] as String;
    } catch (e) {
      debugPrint('ChatService.createOrGetThread error: $e');
      rethrow;
    }
  }

  ChatThread _rowToThread(Map<String, dynamic> row,
      {List<ChatMessage> messages = const []}) {
    return ChatThread(
      id: row['id'] as String,
      studentId: row['student_id'] as String,
      studentName: row['student_name'] as String? ?? 'Student',
      mentorId: row['mentor_id'] as String,
      mentorName: row['mentor_name'] as String? ?? 'Mentor',
      subject: row['subject'] as String?,
      lastActivity: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
          DateTime.now(),
      unreadCount: row['unread_count'] as int? ?? 0,
      messages: messages,
    );
  }

  ChatMessage _rowToMessage(Map<String, dynamic> row) {
    return ChatMessage(
      id: row['id'] as String,
      chatId: row['chat_id'] as String,
      senderId: row['sender_id'] as String,
      senderName: row['sender_name'] as String? ?? 'User',
      type: MessageType.text, // extend for other types
      content: row['content'] as String? ?? '',
      timestamp: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      isRead: row['is_read'] as bool? ?? false,
    );
  }

  Future<List<ChatThread>> fetchThreadsForUser(String userId) async {
    try {
      // Try to use materialized view first (better performance with user names and unread counts)
      final rows = await _client
          .from('chat_threads_view')
          .select()
          .or('student_id.eq.$userId,mentor_id.eq.$userId')
          .order('updated_at', ascending: false);
      return rows.map<ChatThread>(_rowToThread).toList();
    } catch (e) {
      // Fallback to base table if view doesn't exist yet
      debugPrint('chat_threads_view not available, trying base table: $e');
      try {
        final rows = await _client
            .from('chat_threads')
            .select()
            .or('student_id.eq.$userId,mentor_id.eq.$userId')
            .order('updated_at', ascending: false);
        return rows.map<ChatThread>(_rowToThread).toList();
      } catch (e2) {
        // If database tables don't exist, return mock data for demo
        debugPrint(
            'Database tables not available, returning mock chat data: $e2');
        return _getMockChatThreads(userId);
      }
    }
  }

  Stream<List<ChatThread>> watchThreads(String userId) async* {
    try {
      // Initial emit - try to fetch from database
      yield await fetchThreadsForUser(userId);

      // Try to set up real-time subscriptions
      final channel = _client.channel('public:chat_threads')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_threads',
          callback: (_) {},
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) {},
        )
        ..subscribe();

      // Simple refetch strategy (could be optimized by patching list)
      final controller = StreamController<List<ChatThread>>();
      void refetch() async {
        try {
          controller.add(await fetchThreadsForUser(userId));
        } catch (e) {
          debugPrint('watchThreads refetch error: $e');
        }
      }

      // Set up refresh channel
      _client.channel('public:chat_threads_refresh')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_threads',
          callback: (_) => refetch(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => refetch(),
        )
        ..subscribe();

      // Listen to periodic refreshes or fallback to mock data
      controller.addStream(Stream.periodic(const Duration(minutes: 5))
          .asyncMap((_) => fetchThreadsForUser(userId)));

      yield* controller.stream;
      await channel.unsubscribe();
    } catch (e) {
      debugPrint(
          'Database not available for watchThreads, using mock data: $e');
      // If database setup fails, provide mock data stream
      yield _getMockChatThreads(userId);

      // Optionally, keep trying to reconnect periodically
      await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
        try {
          yield await fetchThreadsForUser(userId);
          // If we successfully fetch from database, continue with normal flow
          break;
        } catch (e2) {
          // Still no database, keep providing mock data
          yield _getMockChatThreads(userId);
        }
      }
    }
  }

  Future<List<ChatMessage>> fetchMessages(String chatId) async {
    try {
      final rows = await _client
          .from('chat_messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: true);
      return rows.map<ChatMessage>(_rowToMessage).toList();
    } catch (e) {
      debugPrint(
          'Database not available for messages, returning mock data: $e');
      return _getMockMessages(chatId);
    }
  }

  Stream<List<ChatMessage>> watchMessages(String chatId) async* {
    yield await fetchMessages(chatId);

    final channel = _client.channel('public:chat_messages:$chatId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chat_messages',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId),
        callback: (_) {},
      )
      ..subscribe();

    final controller = StreamController<List<ChatMessage>>();
    void refetch() async {
      try {
        controller.add(await fetchMessages(chatId));
      } catch (e) {
        debugPrint('watchMessages refetch error: $e');
      }
    }

    _client.channel('public:chat_messages_refresh_$chatId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chat_messages',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId),
        callback: (_) => refetch(),
      )
      ..subscribe();
    yield* controller.stream;
    await channel.unsubscribe();
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    try {
      await _client.from('chat_messages').insert({
        'chat_id': chatId,
        'sender_id': senderId,
        'sender_name': senderName,
        'type': 'text',
        'content': content,
      });
      // bump thread updated_at
      await _client.from('chat_threads').update(
          {'updated_at': DateTime.now().toIso8601String()}).eq('id', chatId);
    } catch (e) {
      debugPrint('Failed to send message to database: $e');
      // In mock mode, actually add the message to local storage
      debugPrint(
          'Mock: Adding message "$content" from $senderName to chat $chatId');

      final newMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        type: MessageType.text,
        content: content,
        timestamp: DateTime.now(),
        isRead: false,
      );

      // Store in local mock storage
      _mockMessages[chatId] = (_mockMessages[chatId] ?? [])..add(newMessage);
    }
  }

  /// Mock chat threads for demo when database is not available
  List<ChatThread> _getMockChatThreads(String userId) {
    final now = DateTime.now();
    return [
      ChatThread(
        id: 'mock-thread-1',
        studentId: userId,
        mentorId: 'mentor-1',
        studentName: 'You (Alex)',
        mentorName: 'Dr. Sarah Smith',
        subject: 'Mathematics',
        lastActivity: now.subtract(const Duration(minutes: 30)),
        unreadCount: 2,
        messages: [
          ChatMessage(
            id: 'msg-1',
            chatId: 'mock-thread-1',
            content: 'Could you help me with quadratic equations?',
            senderId: 'mentor-1',
            senderName: 'Dr. Sarah Smith',
            type: MessageType.text,
            timestamp: now.subtract(const Duration(minutes: 30)),
            isSent: true,
          ),
        ],
      ),
      ChatThread(
        id: 'mock-thread-2',
        studentId: userId,
        mentorId: 'mentor-2',
        studentName: 'You (Alex)',
        mentorName: 'Prof. Raj Kumar',
        subject: 'Physics',
        lastActivity: now.subtract(const Duration(hours: 2)),
        unreadCount: 0,
        messages: [
          ChatMessage(
            id: 'msg-2',
            chatId: 'mock-thread-2',
            content: 'Thank you for the session today!',
            senderId: userId,
            senderName: 'You',
            type: MessageType.text,
            timestamp: now.subtract(const Duration(hours: 2)),
            isSent: true,
          ),
        ],
      ),
      ChatThread(
        id: 'mock-thread-3',
        studentId: userId,
        mentorId: 'mentor-3',
        studentName: 'You (Alex)',
        mentorName: 'Dr. Priya Sharma',
        subject: 'Chemistry',
        lastActivity: now.subtract(const Duration(days: 1)),
        unreadCount: 1,
        messages: [
          ChatMessage(
            id: 'msg-3',
            chatId: 'mock-thread-3',
            content: 'Let me know when you want to schedule the next session',
            senderId: 'mentor-3',
            senderName: 'Dr. Priya Sharma',
            type: MessageType.text,
            timestamp: now.subtract(const Duration(days: 1)),
            isSent: true,
          ),
        ],
      ),
    ];
  }

  /// Mock messages for a specific chat when database is not available
  List<ChatMessage> _getMockMessages(String chatId) {
    final now = DateTime.now();

    List<ChatMessage> predefinedMessages;

    switch (chatId) {
      case 'mock-thread-1':
        predefinedMessages = [
          ChatMessage(
            id: 'msg-1-1',
            chatId: chatId,
            content: 'Hi Dr. Sarah! I need help with quadratic equations.',
            senderId: 'student-1',
            senderName: 'You',
            type: MessageType.text,
            timestamp: now.subtract(const Duration(hours: 1)),
            isSent: true,
          ),
          ChatMessage(
            id: 'msg-1-2',
            chatId: chatId,
            content:
                'Hi Alex! I\'d be happy to help. What specific part are you struggling with?',
            senderId: 'mentor-1',
            senderName: 'Dr. Sarah Smith',
            type: MessageType.text,
            timestamp: now.subtract(const Duration(minutes: 50)),
            isSent: true,
          ),
          ChatMessage(
            id: 'msg-1-3',
            chatId: chatId,
            content: 'I\'m having trouble with the discriminant formula',
            senderId: 'student-1',
            senderName: 'You',
            type: MessageType.text,
            timestamp: now.subtract(const Duration(minutes: 45)),
            isSent: true,
          ),
          ChatMessage(
            id: 'msg-1-4',
            chatId: chatId,
            content: 'Could you help me with quadratic equations?',
            senderId: 'mentor-1',
            senderName: 'Dr. Sarah Smith',
            type: MessageType.text,
            timestamp: now.subtract(const Duration(minutes: 30)),
            isSent: true,
          ),
        ];
        break;
      case 'mock-thread-2':
        predefinedMessages = [
          ChatMessage(
            id: 'msg-2-1',
            chatId: chatId,
            content: 'Great session today on Newton\'s laws!',
            senderId: 'mentor-2',
            senderName: 'Prof. Raj Kumar',
            type: MessageType.text,
            timestamp: now.subtract(const Duration(hours: 3)),
            isSent: true,
          ),
          ChatMessage(
            id: 'msg-2-2',
            chatId: chatId,
            content: 'Thank you for the session today!',
            senderId: 'student-1',
            senderName: 'You',
            type: MessageType.text,
            timestamp: now.subtract(const Duration(hours: 2)),
            isSent: true,
          ),
        ];
        break;
      case 'mock-thread-3':
        predefinedMessages = [
          ChatMessage(
            id: 'msg-3-1',
            chatId: chatId,
            content: 'Let me know when you want to schedule the next session',
            senderId: 'mentor-3',
            senderName: 'Dr. Priya Sharma',
            type: MessageType.text,
            timestamp: now.subtract(const Duration(days: 1)),
            isSent: true,
          ),
        ];
        break;
      default:
        predefinedMessages = [];
    }

    // Combine predefined messages with any stored mock messages
    final storedMessages = _mockMessages[chatId] ?? [];
    return [...predefinedMessages, ...storedMessages];
  }
}
