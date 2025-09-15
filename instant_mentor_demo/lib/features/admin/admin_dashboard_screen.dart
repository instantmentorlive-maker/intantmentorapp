import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/admin_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/models/user.dart';
import '../../core/services/websocket_service.dart';
import '../../core/providers/websocket_provider.dart';
import '../../core/providers/api_state_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    if (user?.role != UserRole.admin) {
      return const Scaffold(
        body: Center(child: Text('Admin access required')),
      );
    }

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Applications'),
              Tab(text: 'Call Logs'),
              Tab(text: 'Disputes'),
              Tab(text: 'Bans'),
              Tab(text: 'Refunds'),
              Tab(text: 'GDPR'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ApplicationsTab(),
            _CallLogsTab(),
            _DisputesTab(),
            _BansTab(),
            _RefundsTab(),
            _GdprTab(),
          ],
        ),
      ),
    );
  }
}

class _ApplicationsTab extends ConsumerWidget {
  const _ApplicationsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(mentorApplicationsStreamProvider);
    final admin = ref.read(adminServiceProvider);
    return apps.when(
      data: (rows) => ListView.builder(
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final r = rows[i];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text(r['full_name'] ?? 'Unknown'),
              subtitle: Text('${r['email']} • ${r['status']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => admin.reviewMentorApplication(
                      id: r['id'],
                      status: 'approved',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => admin.reviewMentorApplication(
                      id: r['id'],
                      status: 'rejected',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _CallLogsTab extends ConsumerWidget {
  const _CallLogsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(callLogsStreamProvider);
    final conn = ref.watch(webSocketConnectionStateProvider);
    return logs.when(
      data: (rows) {
        final total = rows.length;
        final active = rows
            .where((r) =>
                (r['status'] == 'ringing' || r['status'] == 'accepted') &&
                r['ended_at'] == null)
            .length;
        final failed = rows.where((r) => r['status'] == 'rejected').length;
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  _MetricChip(label: 'Total', value: total.toString()),
                  const SizedBox(width: 8),
                  _MetricChip(label: 'Active', value: active.toString()),
                  const SizedBox(width: 8),
                  _MetricChip(label: 'Rejected', value: failed.toString()),
                  const Spacer(),
                  Text('WS: ${conn.value?.name ?? '...'}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = rows[i];
                  final status = r['status'];
                  final duration = r['duration_seconds'] ?? 0;
                  return ListTile(
                    leading: Icon(
                      status == 'accepted' || status == 'ended'
                          ? Icons.call
                          : Icons.call_end,
                    ),
                    title:
                        Text('${r['call_type'] ?? 'video'} • ${r['status']}'),
                    subtitle: Text(
                        'caller: ${r['caller_id']} → receiver: ${r['receiver_id']}'),
                    trailing: Text('${duration}s'),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _DisputesTab extends ConsumerWidget {
  const _DisputesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputes = ref.watch(disputesStreamProvider);
    final admin = ref.read(adminServiceProvider);
    return disputes.when(
      data: (rows) => ListView.builder(
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final r = rows[i];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text(r['reason'] ?? 'Dispute'),
              subtitle: Text(
                  'status: ${r['status']} • session: ${r['session_id'] ?? '-'}'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'resolve') {
                    await admin.updateDisputeStatus(
                        id: r['id'], status: 'resolved');
                  } else if (v == 'reject') {
                    await admin.updateDisputeStatus(
                        id: r['id'], status: 'rejected');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'resolve', child: Text('Mark Resolved')),
                  PopupMenuItem(value: 'reject', child: Text('Reject')),
                ],
              ),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _BansTab extends ConsumerWidget {
  const _BansTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bans = ref.watch(activeBansStreamProvider);
    final admin = ref.read(adminServiceProvider);
    return bans.when(
      data: (rows) => ListView.builder(
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final r = rows[i];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text('User: ${r['user_id']}'),
              subtitle: Text(r['reason'] ?? 'No reason'),
              trailing: TextButton(
                onPressed: () => admin.liftBan(banId: r['id']),
                child: const Text('Lift Ban'),
              ),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _RefundsTab extends ConsumerWidget {
  const _RefundsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refunds = ref.watch(refundsStreamProvider);
    return refunds.when(
      data: (rows) => ListView.builder(
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final r = rows[i];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              leading: const Icon(Icons.refresh),
              title:
                  Text('Session: ${r['session_id'] ?? '-'} • ${r['status']}'),
              subtitle: Text(
                  'Amount: ${r['amount']} • Reason: ${r['reason'] ?? '-'}'),
              trailing: Text(r['created_at'] != null
                  ? (r['created_at'] as String).split('T').first
                  : ''),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetricChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _GdprTab extends ConsumerStatefulWidget {
  const _GdprTab();
  @override
  ConsumerState<_GdprTab> createState() => _GdprTabState();
}

class _GdprTabState extends ConsumerState<_GdprTab> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final admin = ref.read(adminServiceProvider);
    final gdprApiState = ref.watch(apiStateProvider('gdpr'));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter a userId (UUID) to export or delete user data'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'User ID',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton(
                onPressed: gdprApiState.isLoading
                    ? null
                    : () async {
                        final notifier =
                            ref.read(apiStateProvider('gdpr').notifier);
                        await notifier.execute(() async {
                          final data = await admin
                              .exportUserData(_controller.text.trim());
                          return {'result': data.toString()};
                        });
                      },
                child: const Text('Export'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: gdprApiState.isLoading
                    ? null
                    : () async {
                        final notifier =
                            ref.read(apiStateProvider('gdpr').notifier);
                        await notifier.execute(() async {
                          await admin.deleteUserData(_controller.text.trim());
                          return {'result': 'Deleted'};
                        });
                      },
                child: const Text('Delete'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Text(gdprApiState.hasError
                  ? 'Error: ${gdprApiState.errorMessage}'
                  : gdprApiState.data?['result']?.toString() ?? 'No result'),
            ),
          ),
        ],
      ),
    );
  }
}
