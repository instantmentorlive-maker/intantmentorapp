import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/chat.dart';
import '../../../core/providers/chat_providers.dart';
import '../../chat/chat_detail_screen.dart';

class MentorChatScreen extends ConsumerWidget {
  const MentorChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(chatThreadsProvider);
    return Column(
      children: [
        // Templates Section
        Container(
          margin: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder_special,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Resource Templates',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Quickly share reusable resources with students'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showTemplatesDialog(context),
                      icon: const Icon(Icons.folder),
                      label: const Text('Manage Templates'),
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
                return const Center(child: Text('No conversations yet'));
              }
              return ListView.builder(
                itemCount: threads.length,
                itemBuilder: (context, index) =>
                    _ThreadTile(thread: threads[index]),
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
                      child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTemplatesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resource Templates'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: const [
              _TemplateItem('Quadratic Equations Formula', 'Mathematics', 15),
              _TemplateItem('Newton\'s Laws Summary', 'Physics', 8),
              _TemplateItem('Organic Chemistry Basics', 'Chemistry', 12),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final ChatThread thread;
  const _ThreadTile({required this.thread});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(thread.studentName.split(' ').map((e) => e[0]).join()),
        ),
        title: Text(thread.studentName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thread.subject != null)
              Text(thread.subject!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12)),
            Text(thread.lastMessage?.content ?? 'Tap to open conversation',
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Text(_formatTime(thread.lastActivity),
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChatDetailScreen(thread: thread))),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _TemplateItem extends StatelessWidget {
  final String title;
  final String subject;
  final int usageCount;

  const _TemplateItem(this.title, this.subject, this.usageCount);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text('$subject • Used $usageCount times'),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {},
    );
  }
}
