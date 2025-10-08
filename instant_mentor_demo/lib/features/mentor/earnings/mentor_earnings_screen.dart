import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/payment_models.dart';
import '../../../core/services/enhanced_wallet_service.dart';
import '../../../core/providers/payment_providers.dart';
import '../../../core/providers/auth_provider.dart';

/// Enhanced earnings screen for mentors
/// Shows earnings, payout history, and payout functionality
class MentorEarningsScreen extends ConsumerStatefulWidget {
  const MentorEarningsScreen({super.key});

  @override
  ConsumerState<MentorEarningsScreen> createState() =>
      _MentorEarningsScreenState();
}

class _MentorEarningsScreenState extends ConsumerState<MentorEarningsScreen> {
  final TextEditingController _payoutAmountController = TextEditingController();
  bool _isProcessingPayout = false;

  @override
  void dispose() {
    _payoutAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userId = user?.id;

    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to view your earnings'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My Earnings'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0B1C49),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showEarningsInfo,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mentorEarningsProvider(userId));
          ref.invalidate(transactionHistoryProvider(userId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Earnings Card
              _buildEarningsCard(userId),
              const SizedBox(height: 20),

              // Quick Actions
              _buildQuickActions(),
              const SizedBox(height: 24),

              // Payout History
              _buildPayoutHistory(userId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsCard(String userId) {
    return Consumer(
      builder: (context, ref, child) {
        final earningsAsync = ref.watch(mentorEarningsProvider(userId));

        return earningsAsync.when(
          data: (earnings) => _buildEarningsCardContent(earnings),
          loading: () => _buildLoadingCard(),
          error: (error, stack) => _buildErrorCard(error.toString()),
        );
      },
    );
  }

  Widget _buildEarningsCardContent(MentorEarnings earnings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF059669),
            Color(0xFF10B981),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Earnings',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  earnings.currency,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyUtils.formatAmount(
              earnings.earningsAvailable + earnings.earningsLocked,
              currency: earnings.currency,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildEarningsItem(
                  'Available',
                  CurrencyUtils.formatAmount(earnings.earningsAvailable,
                      currency: earnings.currency),
                  Colors.lightGreen,
                  'Ready for payout',
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.2),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: _buildEarningsItem(
                  'In Progress',
                  CurrencyUtils.formatAmount(earnings.earningsLocked,
                      currency: earnings.currency),
                  Colors.amber,
                  'From ongoing sessions',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Paid Out',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '₹0.00', // This would need to be tracked separately
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '0 sessions', // This would need to be tracked separately
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsItem(
      String label, String amount, Color color, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                amount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red[200]!),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 32),
          const SizedBox(height: 8),
          Text(
            'Unable to load earnings',
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: TextStyle(
              color: Colors.red[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Request Payout',
                color: Colors.green,
                onTap: _showPayoutDialog,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.analytics_outlined,
                label: 'Analytics',
                color: Colors.blue,
                onTap: _showAnalytics,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.history,
                label: 'History',
                color: Colors.purple,
                onTap: _showFullPayoutHistory,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutHistory(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Payouts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            TextButton(
              onPressed: _showFullPayoutHistory,
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Consumer(
          builder: (context, ref, child) {
            // Using transaction history as payout history for now
            final payoutsAsync = ref.watch(transactionHistoryProvider(userId));

            return payoutsAsync.when(
              data: (transactions) => _buildPayoutsList(
                  []), // Convert transactions to payouts if needed
              loading: () => _buildPayoutsLoading(),
              error: (error, stack) => _buildPayoutsError(error.toString()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPayoutsList(List<PayoutRequest> payouts) {
    if (payouts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No payouts yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your payout history will appear here',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: payouts.take(5).length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey[200],
        ),
        itemBuilder: (context, index) {
          final payout = payouts[index];
          return _buildPayoutTile(payout);
        },
      ),
    );
  }

  Widget _buildPayoutTile(PayoutRequest payout) {
    final statusColor = _getPayoutStatusColor(payout.status);
    final statusIcon = _getPayoutStatusIcon(payout.status);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          statusIcon,
          color: statusColor,
          size: 20,
        ),
      ),
      title: Text(
        CurrencyUtils.formatAmount(payout.amount, currency: payout.currency),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMM dd, yyyy • hh:mm a').format(payout.createdAt),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getPayoutStatusLabel(payout.status),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      trailing: payout.status == PayoutStatus.failed
          ? IconButton(
              icon: Icon(Icons.refresh, color: Colors.grey[600]),
              onPressed: () => _retryPayout(payout),
            )
          : null,
    );
  }

  Widget _buildPayoutsLoading() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildPayoutsError(String error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 32),
          const SizedBox(height: 8),
          Text(
            'Unable to load payout history',
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPayoutStatusColor(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.pending:
        return Colors.orange;
      case PayoutStatus.created:
        return Colors.blue;
      case PayoutStatus.paid:
        return Colors.green;
      case PayoutStatus.failed:
        return Colors.red;
    }
  }

  IconData _getPayoutStatusIcon(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.pending:
        return Icons.schedule;
      case PayoutStatus.created:
        return Icons.sync;
      case PayoutStatus.paid:
        return Icons.check_circle;
      case PayoutStatus.failed:
        return Icons.error;
    }
  }

  String _getPayoutStatusLabel(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.pending:
        return 'PENDING';
      case PayoutStatus.created:
        return 'PROCESSING';
      case PayoutStatus.paid:
        return 'COMPLETED';
      case PayoutStatus.failed:
        return 'FAILED';
    }
  }

  void _showPayoutDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Request Payout',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available for Payout',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹5,280.00', // This would come from the earnings data
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _payoutAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Payout Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                  helperText: 'Minimum ₹100 required for payout',
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Processing Fee (2%)'),
                        Text('₹10.56'),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'You will receive',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '₹517.44',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Payout Method',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bank Account',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'HDFC Bank •••• 1234',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text('Change'),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessingPayout ? null : _processPayout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                      ),
                      child: _isProcessingPayout
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Request Payout'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnalytics() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Analytics feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showFullPayoutHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PayoutHistoryScreen(),
      ),
    );
  }

  void _showEarningsInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Earnings Information'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Available Balance: Ready for immediate payout'),
            SizedBox(height: 8),
            Text(
                '• Locked Balance: From ongoing sessions, released after completion'),
            SizedBox(height: 8),
            Text('• Minimum payout amount: ₹100'),
            SizedBox(height: 8),
            Text('• Processing fee: 2% per payout'),
            SizedBox(height: 8),
            Text('• Payout processing time: 1-3 business days'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _processPayout() async {
    final amountText = _payoutAmountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter payout amount')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum payout amount is ₹100')),
      );
      return;
    }

    setState(() {
      _isProcessingPayout = true;
    });

    try {
      // In a real app, process the payout request here
      await Future.delayed(const Duration(seconds: 2)); // Simulate processing

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payout request submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _payoutAmountController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process payout: $e')),
      );
    } finally {
      setState(() {
        _isProcessingPayout = false;
      });
    }
  }

  void _retryPayout(PayoutRequest payout) {
    // In a real app, retry the failed payout
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Retrying payout...'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

/// Full payout history screen
class PayoutHistoryScreen extends ConsumerWidget {
  const PayoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final userId = user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout History'),
        backgroundColor: const Color(0xFF0B1C49),
        foregroundColor: Colors.white,
      ),
      body: userId == null
          ? const Center(child: Text('Please log in to view payout history'))
          : Consumer(
              builder: (context, ref, child) {
                final payoutsAsync =
                    ref.watch(mentorPayoutRequestsProvider(userId));
                return payoutsAsync.when(
                  data: (payouts) => payouts.isEmpty
                      ? const Center(child: Text('No payouts found'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: payouts.length,
                          itemBuilder: (context, index) {
                            final payout = payouts[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  CurrencyUtils.formatAmount(payout.amount,
                                      currency: payout.currency),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  DateFormat('MMM dd, yyyy • hh:mm a')
                                      .format(payout.createdAt),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getPayoutStatusColor(payout.status)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _getPayoutStatusLabel(payout.status),
                                    style: TextStyle(
                                        color: _getPayoutStatusColor(
                                            payout.status),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Text('Error loading payout history: $error'),
                  ),
                );
              },
            ),
    );
  }

  Color _getPayoutStatusColor(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.pending:
        return Colors.orange;
      case PayoutStatus.created:
        return Colors.blue;
      case PayoutStatus.paid:
        return Colors.green;
      case PayoutStatus.failed:
        return Colors.red;
    }
  }

  String _getPayoutStatusLabel(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.pending:
        return 'PENDING';
      case PayoutStatus.created:
        return 'PROCESSING';
      case PayoutStatus.paid:
        return 'COMPLETED';
      case PayoutStatus.failed:
        return 'FAILED';
    }
  }
}
