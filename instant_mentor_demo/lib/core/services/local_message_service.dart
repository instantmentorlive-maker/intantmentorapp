import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/chat.dart';
import 'supabase_service.dart';
import 'websocket_service.dart';

/// Phase 2 Day 14: Local message persistence service with sync logic
/// Provides offline-first messaging with automatic sync when online
class LocalMessageService {
  static LocalMessageService? _instance;
  static LocalMessageService get instance =>
      _instance ??= LocalMessageService._();

  LocalMessageService._();

  Database? _database;
  Box<String>? _messageBox;
  Box<int>? _syncBox;

  bool _isInitialized = false;
  final StreamController<List<ChatMessage>> _messagesStreamController =
      StreamController<List<ChatMessage>>.broadcast();
  final StreamController<ChatMessage> _newMessageStreamController =
      StreamController<ChatMessage>.broadcast();

  // Sync status tracking
  Timer? _syncTimer;
  bool _isSyncing = false;
  static const Duration _syncInterval = Duration(minutes: 2);

  /// Initialize local storage databases
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive for quick access to recent messages
      await Hive.initFlutter();
      _messageBox = await Hive.openBox<String>('cached_messages');
      _syncBox = await Hive.openBox<int>('sync_timestamps');

      // Initialize SQLite for comprehensive message storage
      await _initSQLiteDatabase();

      // Start periodic sync
      _startPeriodicSync();

      _isInitialized = true;
      debugPrint('✅ LocalMessageService initialized successfully');
    } catch (e) {
      debugPrint('❌ LocalMessageService initialization failed: $e');
      rethrow;
    }
  }

  /// Initialize SQLite database with message schema
  Future<void> _initSQLiteDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = '${documentsDirectory.path}/instant_mentor_messages.db';

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create messages table
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            chat_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            sender_name TEXT NOT NULL,
            type TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            is_read INTEGER DEFAULT 0,
            is_sent INTEGER DEFAULT 0,
            local_timestamp INTEGER NOT NULL,
            sync_status TEXT DEFAULT 'pending',
            retry_count INTEGER DEFAULT 0
          )
        ''');

        // Create threads table
        await db.execute('''
          CREATE TABLE chat_threads (
            id TEXT PRIMARY KEY,
            student_id TEXT NOT NULL,
            student_name TEXT NOT NULL,
            mentor_id TEXT NOT NULL,
            mentor_name TEXT NOT NULL,
            subject TEXT,
            last_activity INTEGER NOT NULL,
            unread_count INTEGER DEFAULT 0,
            sync_status TEXT DEFAULT 'synced'
          )
        ''');

        // Create indexes for better query performance
        await db
            .execute('CREATE INDEX idx_messages_chat_id ON messages(chat_id)');
        await db.execute(
            'CREATE INDEX idx_messages_timestamp ON messages(timestamp DESC)');
        await db.execute(
            'CREATE INDEX idx_messages_sync_status ON messages(sync_status)');
        await db.execute(
            'CREATE INDEX idx_threads_user_ids ON chat_threads(student_id, mentor_id)');

        debugPrint('📱 SQLite database schema created successfully');
      },
    );
  }

  /// Start periodic sync with remote server
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      if (WebSocketService.instance.isConnected) {
        _performSync().catchError((e) {
          debugPrint('🔄 Periodic sync failed: $e');
        });
      }
    });
  }

  /// Save message locally with pending sync status
  Future<void> saveMessageLocally(ChatMessage message,
      {bool markForSync = true}) async {
    if (!_isInitialized) await initialize();

    try {
      // Save to SQLite for persistence
      await _database!.insert(
        'messages',
        {
          'id': message.id,
          'chat_id': message.chatId,
          'sender_id': message.senderId,
          'sender_name': message.senderName,
          'type': message.type.name,
          'content': message.content,
          'timestamp': message.timestamp.millisecondsSinceEpoch,
          'is_read': message.isRead ? 1 : 0,
          'is_sent': message.isSent ? 1 : 0,
          'local_timestamp': DateTime.now().millisecondsSinceEpoch,
          'sync_status': markForSync ? 'pending' : 'synced',
          'retry_count': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Cache in Hive for quick access
      await _messageBox!.put(message.id, jsonEncode(message.toJson()));

      // Emit new message to streams
      _newMessageStreamController.add(message);

      // Refresh messages for the chat
      final messages = await getMessagesForChat(message.chatId);
      _messagesStreamController.add(messages);

      debugPrint('💾 Message saved locally: ${message.id}');

      // Attempt immediate sync if online
      if (WebSocketService.instance.isConnected && markForSync) {
        _syncSingleMessage(message).catchError((e) {
          debugPrint('🔄 Immediate sync failed for message ${message.id}: $e');
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to save message locally: $e');
      rethrow;
    }
  }

  /// Get messages for a chat thread with pagination
  Future<List<ChatMessage>> getMessagesForChat(
    String chatId, {
    int limit = 50,
    int offset = 0,
    bool includeUnsent = true,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      String whereClause = 'chat_id = ?';
      List<dynamic> whereArgs = [chatId];

      if (!includeUnsent) {
        whereClause += ' AND (sync_status = ? OR sync_status = ?)';
        whereArgs.addAll(['synced', 'sent']);
      }

      final List<Map<String, dynamic>> maps = await _database!.query(
        'messages',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'timestamp DESC',
        limit: limit,
        offset: offset,
      );

      final messages = maps.map((map) => _mapToMessage(map)).toList();
      debugPrint(
          '📱 Retrieved ${messages.length} local messages for chat $chatId');

      return messages.reversed.toList(); // Return in chronological order
    } catch (e) {
      debugPrint('❌ Failed to get local messages: $e');
      return [];
    }
  }

  /// Get unsynced messages that need to be sent to server
  Future<List<ChatMessage>> getUnsyncedMessages() async {
    if (!_isInitialized) await initialize();

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'messages',
        where: 'sync_status IN (?, ?) AND retry_count < ?',
        whereArgs: ['pending', 'failed', 5], // Max 5 retries
        orderBy: 'local_timestamp ASC',
      );

      return maps.map((map) => _mapToMessage(map)).toList();
    } catch (e) {
      debugPrint('❌ Failed to get unsynced messages: $e');
      return [];
    }
  }

  /// Sync messages with remote server
  Future<void> _performSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      debugPrint('🔄 Starting message sync...');

      // 1. Send unsynced local messages to server
      final unsyncedMessages = await getUnsyncedMessages();
      for (final message in unsyncedMessages) {
        await _syncSingleMessage(message);
        await Future.delayed(
            const Duration(milliseconds: 100)); // Rate limiting
      }

      // 2. Fetch new messages from server
      await _fetchRecentMessagesFromServer();

      debugPrint('✅ Message sync completed');
    } catch (e) {
      debugPrint('❌ Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single message with server
  Future<void> _syncSingleMessage(ChatMessage message) async {
    try {
      final supabase = SupabaseService.instance;

      // Check if message already exists on server
      final existingMessage = await supabase.client
          .from('chat_messages')
          .select('id')
          .eq('id', message.id)
          .maybeSingle();

      if (existingMessage == null) {
        // Insert new message
        await supabase.client.from('chat_messages').insert({
          'id': message.id,
          'chat_id': message.chatId,
          'sender_id': message.senderId,
          'sender_name': message.senderName,
          'type': message.type.name,
          'content': message.content,
          'created_at': message.timestamp.toIso8601String(),
          'is_read': message.isRead,
        });
      }

      // Update local sync status
      await _database!.update(
        'messages',
        {'sync_status': 'synced'},
        where: 'id = ?',
        whereArgs: [message.id],
      );

      debugPrint('✅ Message synced: ${message.id}');
    } catch (e) {
      // Mark as failed and increment retry count
      await _database!.update(
        'messages',
        {
          'sync_status': 'failed',
          'retry_count': '(retry_count + 1)',
        },
        where: 'id = ?',
        whereArgs: [message.id],
      );

      debugPrint('❌ Failed to sync message ${message.id}: $e');
      rethrow;
    }
  }

  /// Fetch recent messages from server and merge with local storage
  Future<void> _fetchRecentMessagesFromServer() async {
    try {
      final supabase = SupabaseService.instance;
      final lastSyncTime =
          _syncBox!.get('last_message_sync', defaultValue: 0) ?? 0;

      final serverMessages = await supabase.client
          .from('chat_messages')
          .select('*')
          .gte(
              'created_at',
              DateTime.fromMillisecondsSinceEpoch(lastSyncTime)
                  .toIso8601String())
          .order('created_at', ascending: false)
          .limit(100);

      for (final messageData in serverMessages) {
        final message = ChatMessage(
          id: messageData['id'],
          chatId: messageData['chat_id'],
          senderId: messageData['sender_id'],
          senderName: messageData['sender_name'] ?? 'User',
          type: MessageType.values.firstWhere(
            (t) => t.name == messageData['type'],
            orElse: () => MessageType.text,
          ),
          content: messageData['content'] ?? '',
          timestamp: DateTime.parse(messageData['created_at']),
          isRead: messageData['is_read'] ?? false,
          isSent: true,
        );

        // Save without marking for sync (already on server)
        await saveMessageLocally(message, markForSync: false);
      }

      // Update last sync timestamp
      await _syncBox!
          .put('last_message_sync', DateTime.now().millisecondsSinceEpoch);

      debugPrint('📥 Fetched ${serverMessages.length} messages from server');
    } catch (e) {
      debugPrint('❌ Failed to fetch messages from server: $e');
    }
  }

  /// Convert database map to ChatMessage
  ChatMessage _mapToMessage(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      chatId: map['chat_id'],
      senderId: map['sender_id'],
      senderName: map['sender_name'],
      type: MessageType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MessageType.text,
      ),
      content: map['content'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      isRead: map['is_read'] == 1,
      isSent: map['is_sent'] == 1,
    );
  }

  /// Mark message as read locally and sync
  Future<void> markMessageAsRead(String messageId) async {
    if (!_isInitialized) await initialize();

    try {
      await _database!.update(
        'messages',
        {
          'is_read': 1,
          'sync_status': 'pending', // Mark for sync
        },
        where: 'id = ?',
        whereArgs: [messageId],
      );

      debugPrint('✅ Message marked as read: $messageId');

      // Sync read status to server if online
      if (WebSocketService.instance.isConnected) {
        _syncReadStatus(messageId).catchError((e) {
          debugPrint('❌ Failed to sync read status: $e');
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to mark message as read: $e');
    }
  }

  /// Sync read status to server
  Future<void> _syncReadStatus(String messageId) async {
    try {
      await SupabaseService.instance.client
          .from('chat_messages')
          .update({'is_read': true}).eq('id', messageId);

      // Update local sync status
      await _database!.update(
        'messages',
        {'sync_status': 'synced'},
        where: 'id = ?',
        whereArgs: [messageId],
      );

      debugPrint('✅ Read status synced for message: $messageId');
    } catch (e) {
      debugPrint('❌ Failed to sync read status: $e');
    }
  }

  /// Clear old messages to manage storage space
  Future<void> clearOldMessages({int daysToKeep = 30}) async {
    if (!_isInitialized) await initialize();

    try {
      final cutoffTime = DateTime.now()
          .subtract(Duration(days: daysToKeep))
          .millisecondsSinceEpoch;

      final deletedCount = await _database!.delete(
        'messages',
        where: 'timestamp < ? AND sync_status = ?',
        whereArgs: [cutoffTime, 'synced'],
      );

      debugPrint('🧹 Cleared $deletedCount old messages');
    } catch (e) {
      debugPrint('❌ Failed to clear old messages: $e');
    }
  }

  /// Get message streams for real-time updates
  Stream<List<ChatMessage>> get messagesStream =>
      _messagesStreamController.stream;
  Stream<ChatMessage> get newMessageStream =>
      _newMessageStreamController.stream;

  /// Force sync now (useful for manual sync triggers)
  Future<void> forceSyncNow() async {
    if (!WebSocketService.instance.isConnected) {
      throw Exception('Cannot sync while offline');
    }

    await _performSync();
  }

  /// Get sync statistics
  Future<Map<String, int>> getSyncStats() async {
    if (!_isInitialized) await initialize();

    try {
      final pending = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM messages WHERE sync_status = ?',
        ['pending'],
      );

      final failed = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM messages WHERE sync_status = ?',
        ['failed'],
      );

      final synced = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM messages WHERE sync_status = ?',
        ['synced'],
      );

      return {
        'pending': pending.first['count'] as int,
        'failed': failed.first['count'] as int,
        'synced': synced.first['count'] as int,
      };
    } catch (e) {
      debugPrint('❌ Failed to get sync stats: $e');
      return {'pending': 0, 'failed': 0, 'synced': 0};
    }
  }

  /// Dispose service and clean up resources
  void dispose() {
    _syncTimer?.cancel();
    _messagesStreamController.close();
    _newMessageStreamController.close();
    _database?.close();
    _messageBox?.close();
    _syncBox?.close();
  }
}
