import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/chat.dart';
import '../../core/providers/chat_providers.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/chat_state_provider.dart';
import '../../core/routing/routing.dart';
import 'package:go_router/go_router.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final ChatThread thread;
  const ChatDetailScreen({super.key, required this.thread});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final me = auth.user;
    final messagesAsync = ref.watch(chatMessagesFamily(widget.thread.id));
    final chatSendingState =
        ref.watch(chatSendingFamilyProvider(widget.thread.id));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.thread.mentorName),
            if (widget.thread.subject != null)
              Text(widget.thread.subject!,
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Start Session',
            icon: const Icon(Icons.videocam),
            onPressed: () {
              // TODO: Use real session id mapping when integrated
              context.go(AppRoutes.session(widget.thread.id));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hello!'),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isMe = m.senderId == me?.id;
                    return _ChatBubble(message: m, isMe: isMe);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Failed to load messages\n$e',
                      textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
          _MessageInput(
            controller: _messageController,
            sending: chatSendingState.isSending,
            onSend: () => _send(me?.id, me?.userMetadata?['name'] ?? 'Me'),
          ),
        ],
      ),
    );
  }

  Future<void> _send(String? userId, String senderName) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || userId == null) return;

    // Use provider instead of setState
    ref
        .read(chatSendingFamilyProvider(widget.thread.id).notifier)
        .setSending(true);

    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.sendTextMessage(
        chatId: widget.thread.id,
        senderId: userId,
        senderName: senderName,
        content: text,
      );
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $e')),
      );
    } finally {
      // Use provider instead of setState
      if (mounted) {
        ref
            .read(chatSendingFamilyProvider(widget.thread.id).notifier)
            .setSending(false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  const _MessageInput(
      {required this.controller, required this.onSend, required this.sending});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          sending
              ? const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: onSend,
                ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  const _ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final bg = isMe
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final fg = isMe
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.content, style: TextStyle(color: fg)),
            const SizedBox(height: 4),
            Text(_formatTime(message.timestamp),
                style: TextStyle(color: fg.withOpacity(0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
