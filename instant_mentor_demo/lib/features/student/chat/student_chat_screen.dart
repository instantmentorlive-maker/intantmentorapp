import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/chat.dart';
import '../../../core/providers/chat_providers.dart';
import '../../chat/chat_detail_screen.dart';

class StudentChatScreen extends ConsumerWidget {
  const StudentChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(chatThreadsProvider);

    return Column(
      children: [
        // Quick Connect Section
        Container(
          margin: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.flash_on,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Quick Connect',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Need urgent help? Connect with available mentors instantly!',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showQuickConnectDialog(context),
                      icon: const Icon(Icons.connect_without_contact),
                      label: const Text('Find Available Mentors'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: threadsAsync.when(
            data: (threads) {
              if (threads.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No conversations yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Start a conversation with a mentor!',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: threads.length,
                itemBuilder: (context, index) =>
                    _ChatThreadTile(thread: threads[index]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.redAccent),
                  const SizedBox(height: 8),
                  Text('Failed to load chats',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(e.toString(),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(chatThreadsProvider),
                    child: const Text('Retry'),
                  )
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  void _showQuickConnectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Connect'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Available mentors right now:'),
            const SizedBox(height: 16),
            _AvailableMentorTile(
              name: 'Dr. Sarah Smith',
              subject: 'Mathematics',
              rating: 4.8,
              onConnect: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connected to Dr. Sarah Smith!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
            _AvailableMentorTile(
              name: 'Prof. Raj Kumar',
              subject: 'Physics',
              rating: 4.9,
              onConnect: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connected to Prof. Raj Kumar!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _ChatThreadTile extends StatelessWidget {
  final ChatThread thread;
  const _ChatThreadTile({required this.thread});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(thread.mentorName.split(' ').map((n) => n[0]).join()),
            ),
            if (thread.unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text('${thread.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
        title: Text(
          thread.mentorName,
          style: TextStyle(
              fontWeight:
                  thread.unreadCount > 0 ? FontWeight.bold : FontWeight.normal),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thread.subject != null)
              Text(thread.subject!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12)),
            Text(
              thread.lastMessage?.content ?? 'Tap to open conversation',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: thread.unreadCount > 0
                      ? FontWeight.w500
                      : FontWeight.normal),
            ),
          ],
        ),
        trailing: Text(_formatTime(thread.lastActivity),
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        onTap: () => _openChatThread(context, thread),
      ),
    );
  }

  void _openChatThread(BuildContext context, ChatThread thread) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatDetailScreen(thread: thread)));
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }
}

class _AvailableMentorTile extends StatelessWidget {
  final String name;
  final String subject;
  final double rating;
  final VoidCallback onConnect;

  const _AvailableMentorTile({
    required this.name,
    required this.subject,
    required this.rating,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(name.split(' ').map((n) => n[0]).join()),
      ),
      title: Text(name),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              subject,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.star, size: 14, color: Colors.amber[600]),
          Text(' $rating'),
        ],
      ),
      trailing: ElevatedButton(
        onPressed: onConnect,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(60, 32),
        ),
        child: const Text('Connect', style: TextStyle(fontSize: 12)),
      ),
    );
  }
}
