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
  ChatService._();
  static final ChatService instance = ChatService._();
  final _client = SupabaseService.instance.client;

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
          .select('*')
          .or('student_id.eq.$userId,mentor_id.eq.$userId')
          .order('updated_at', ascending: false);
      return rows.map<ChatThread>(_rowToThread).toList();
    } catch (e) {
      // Fallback to base table if view doesn't exist yet
      debugPrint('chat_threads_view not available, using base table: $e');
      final rows = await _client
          .from('chat_threads')
          .select('*')
          .or('student_id.eq.$userId,mentor_id.eq.$userId')
          .order('updated_at', ascending: false);
      return rows.map<ChatThread>(_rowToThread).toList();
    }
  }

  Stream<List<ChatThread>> watchThreads(String userId) async* {
    // Initial emit
    yield await fetchThreadsForUser(userId);

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

    // Supabase realtime uses the callbacks passed in onPostgresChanges; here we piggyback by refetching inside those callbacks.
    // Already added callbacks above (currently empty). We'll re-register with refetch side effects:
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
    controller.addStream(Stream.periodic(const Duration(minutes: 5))
        .asyncMap((_) => fetchThreadsForUser(userId)));

    yield* controller.stream;
    await channel.unsubscribe();
  }

  Future<List<ChatMessage>> fetchMessages(String chatId) async {
    final rows = await _client
        .from('chat_messages')
        .select('*')
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);
    return rows.map<ChatMessage>(_rowToMessage).toList();
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
  }
}
