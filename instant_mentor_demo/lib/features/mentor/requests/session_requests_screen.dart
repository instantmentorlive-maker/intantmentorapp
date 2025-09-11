import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/session_requests_provider.dart';
import '../../../core/models/session_request.dart';
import '../../../core/routing/routing.dart';

class SessionRequestsScreen extends ConsumerWidget {
  const SessionRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(sessionRequestsProvider);
    final actions = ref.watch(sessionRequestActionsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sessionRequestsProvider);
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Incoming Requests',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          requestsAsync.when(
            data: (data) {
              if (data.isEmpty) {
                return _EmptyState(
                    onRetry: () => ref.invalidate(sessionRequestsProvider));
              }
              return Column(
                children: data
                    .map((r) => _RequestTile(
                        request: r, actionsBusy: actions.isLoading))
                    .toList(),
              );
            },
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator())),
            error: (e, st) => _ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(sessionRequestsProvider)),
          ),
          if (actions.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Action failed: ${actions.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            )
        ],
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final SessionRequest request;
  final bool actionsBusy;
  const _RequestTile({required this.request, required this.actionsBusy});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Text(
              request.studentName.split(' ').map((n) => n[0]).take(2).join()),
        ),
        title: Text('${request.subject} Session'),
        subtitle: Text(
            '${request.studentName} • Requested ${_relativeTime(request.requestedAt)}'),
        trailing: request.status != 'pending'
            ? Text(
                request.status.capitalize(),
                style: TextStyle(
                  color: request.status == 'accepted'
                      ? Colors.green
                      : colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: actionsBusy
                        ? null
                        : () => _respond(ref, context, accept: false),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: actionsBusy
                        ? null
                        : () => _acceptAndJoinSession(ref, context),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _respond(WidgetRef ref, BuildContext context,
      {required bool accept}) async {
    final actions = ref.read(sessionRequestActionsProvider.notifier);
    await actions.respond(sessionId: request.id, accept: accept);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${accept ? 'Accepted' : 'Declined'} request'),
          backgroundColor: accept ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _acceptAndJoinSession(
      WidgetRef ref, BuildContext context) async {
    final actions = ref.read(sessionRequestActionsProvider.notifier);
    final sessionId = await actions.acceptAndGetSessionId(request.id);

    if (context.mounted) {
      if (sessionId != null) {
        // Navigate to video call screen
        context.go(AppRoutes.session(sessionId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request accepted! Joining session...'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text('No pending requests',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('New session requests will appear here',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Refresh')),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.error_outline,
            size: 56, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 12),
        Text('Failed to load requests',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(message, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

extension _Cap on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
