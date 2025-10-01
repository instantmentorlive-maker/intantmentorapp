import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/core/models/chat.dart';
import 'package:instant_mentor_demo/core/providers/realtime_chat_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealtimeChatProvider Persistence Tests', () {
    late ProviderContainer container;
    const testReceiverId = 'test_receiver_123';

    setUp(() async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});

      container = ProviderContainer(
        overrides: [
          // Override any dependencies if needed
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should persist messages to SharedPreferences', () async {
      final chatNotifier =
          container.read(realtimeChatProvider(testReceiverId).notifier);

      // Create a test message
      final testMessage = ChatMessage(
        id: 'test_msg_1',
        chatId: 'test_chat_123',
        senderId: 'current_user',
        senderName: 'Current User',
        type: MessageType.text,
        content: 'Hello, this is a test message!',
        timestamp: DateTime.now(),
        isSent: true,
      );

      // Add message to provider
      chatNotifier.addMessage(testMessage);

      // Wait for persistence
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify message is in provider state
      final state = container.read(realtimeChatProvider(testReceiverId));
      expect(state.messages.length, 1);
      expect(state.messages.first.content, 'Hello, this is a test message!');

      // Verify message is persisted in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final persistedData = prefs.getString('chat_messages_$testReceiverId');
      expect(persistedData, isNotNull);

      // Parse and verify persisted data
      final List<dynamic> decoded = jsonDecode(persistedData!) as List<dynamic>;
      final persistedMessages = decoded
          .map((e) => ChatMessage.fromJson(
              Map<String, dynamic>.from(e as Map<String, dynamic>)))
          .toList();
      expect(persistedMessages.length, 1);
      expect(persistedMessages.first.content, 'Hello, this is a test message!');
    });

    test('should load persisted messages on provider creation', () async {
      // First, manually persist some messages
      final prefs = await SharedPreferences.getInstance();
      final messages = [
        ChatMessage(
          id: 'persisted_msg_1',
          chatId: 'test_chat_123',
          senderId: 'user1',
          senderName: 'User 1',
          type: MessageType.text,
          content: 'Persisted message 1',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          isSent: true,
        ),
        ChatMessage(
          id: 'persisted_msg_2',
          chatId: 'test_chat_123',
          senderId: 'user2',
          senderName: 'User 2',
          type: MessageType.text,
          content: 'Persisted message 2',
          timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
          isSent: true,
        ),
      ];

      final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
      await prefs.setString('chat_messages_$testReceiverId', encoded);

      // Create a new notifier directly to test loading
      final chatNotifier = RealtimeChatNotifier(testReceiverId);

      // Wait for the async loading to complete
      await Future.delayed(const Duration(milliseconds: 200));

      final state = chatNotifier.state;

      // Verify messages were loaded
      expect(state.messages.length, 2);
      expect(state.messages[0].content, 'Persisted message 1');
      expect(state.messages[1].content, 'Persisted message 2');
    });

    test('should handle empty persistence gracefully', () async {
      final state = container.read(realtimeChatProvider(testReceiverId));

      // Should have empty messages list
      expect(state.messages, isEmpty);
    });

    test('should clear messages when requested', () async {
      final chatNotifier =
          container.read(realtimeChatProvider(testReceiverId).notifier);

      // Add a message
      final testMessage = ChatMessage(
        id: 'test_msg_clear',
        chatId: 'test_chat_123',
        senderId: 'current_user',
        senderName: 'Current User',
        type: MessageType.text,
        content: 'Message to be cleared',
        timestamp: DateTime.now(),
        isSent: true,
      );

      chatNotifier.addMessage(testMessage);

      // Verify message exists
      var state = container.read(realtimeChatProvider(testReceiverId));
      expect(state.messages.length, 1);

      // Clear messages
      chatNotifier.clearMessages();

      // Verify messages are cleared
      state = container.read(realtimeChatProvider(testReceiverId));
      expect(state.messages, isEmpty);

      // Verify SharedPreferences is also cleared
      final prefs = await SharedPreferences.getInstance();
      final persistedData = prefs.getString('chat_messages_$testReceiverId');
      expect(persistedData, isNull);
    });
  });
}
