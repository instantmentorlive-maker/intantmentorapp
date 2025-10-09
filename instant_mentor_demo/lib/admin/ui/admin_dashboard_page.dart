import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_providers.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: isAdmin.when(
        data: (allowed) {
          if (!allowed) {
            return const Center(child: Text('Access denied. Admins only.'));
          }

          final balances = ref.watch(adminBalancesSummaryProvider);
          final payouts = ref.watch(adminPayoutsProvider);
          final refunds = ref.watch(adminRefundsProvider);
          final recon = ref.watch(adminReconStatsProvider);
          final alerts = ref.watch(adminAlertsProvider);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminBalancesSummaryProvider);
              ref.invalidate(adminPayoutsProvider);
              ref.invalidate(adminRefundsProvider);
              ref.invalidate(adminReconStatsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recent Alerts',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        alerts.when(
                          data: (items) => items.isEmpty
                              ? const Text('No alerts')
                              : Column(
                                  children: items.take(15).map((a) {
                                    Color chipColor;
                                    switch (a.severity) {
                                      case 'critical':
                                        chipColor = Colors.red;
                                        break;
                                      case 'error':
                                        chipColor = Colors.redAccent;
                                        break;
                                      case 'warning':
                                        chipColor = Colors.orange;
                                        break;
                                      default:
                                        chipColor = Colors.blueGrey;
                                    }
                                    return ExpansionTile(
                                      tilePadding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      title: Row(
                                        children: [
                                          Chip(
                                            label:
                                                Text(a.severity.toUpperCase()),
                                            backgroundColor:
                                                chipColor.withOpacity(0.15),
                                            labelStyle: TextStyle(
                                                color:
                                                    chipColor.withOpacity(0.9)),
                                            side: BorderSide(
                                                color:
                                                    chipColor.withOpacity(0.4)),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(
                                                  '${a.type}: ${a.message}')),
                                          Text(a.createdAt.toIso8601String(),
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                        ],
                                      ),
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceVariant
                                                .withOpacity(0.25),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(_prettyJson(a.details),
                                              style: const TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 12)),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error: $e'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: balances.when(
                      data: (b) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Balances Summary',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Wallet Available: ${b.walletAvailable}'),
                          Text('Wallet Locked: ${b.walletLocked}'),
                          Text('Earnings Available: ${b.earningsAvailable}'),
                          Text('Earnings Locked: ${b.earningsLocked}'),
                          Text(
                              'Platform Revenue (Net): ${b.platformRevenueNet}'),
                        ],
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recent Payout Requests',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        payouts.when(
                          data: (items) => items.isEmpty
                              ? const Text('No payouts')
                              : Column(
                                  children: items
                                      .take(10)
                                      .map((p) => ListTile(
                                            dense: true,
                                            title: Text(
                                                'Payout ${p.id.substring(0, 8)}…'),
                                            subtitle: Text(
                                                'Mentor: ${p.mentorId.substring(0, 8)}…  Amount: ${p.amountMinor}  Status: ${p.status}'),
                                            trailing: Text(
                                                p.createdAt.toIso8601String()),
                                          ))
                                      .toList(),
                                ),
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error: $e'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recent Refunds',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        refunds.when(
                          data: (items) => items.isEmpty
                              ? const Text('No refunds')
                              : Column(
                                  children: items
                                      .take(10)
                                      .map((r) => ListTile(
                                            dense: true,
                                            title: Text(
                                                'Refund ${r.id.substring(0, 8)}…'),
                                            subtitle: Text(
                                                'Session: ${r.sessionId.isEmpty ? '-' : r.sessionId.substring(0, 8) + '…'}  Amount: ${r.amountMinor}'),
                                            trailing: Text(
                                                r.createdAt.toIso8601String()),
                                          ))
                                      .toList(),
                                ),
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error: $e'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: recon.when(
                      data: (r) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Reconciliation Stats',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Transactions: ${r['transactions']}'),
                          Text('Refunds: ${r['refunds']}'),
                          Text('Payouts: ${r['payouts']}'),
                        ],
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

String _prettyJson(Map<String, dynamic> data) {
  try {
    return const JsonEncoder.withIndent('  ').convert(data);
  } catch (_) {
    return data.toString();
  }
}
