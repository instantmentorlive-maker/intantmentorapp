import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/payment_models.dart';
import '../../../core/services/enhanced_wallet_service.dart';
import '../../../core/providers/auth_provider.dart';

/// Enhanced wallet screen implementing the payments architecture
/// Shows available/locked balances, transaction history, and top-up functionality
class EnhancedWalletScreen extends ConsumerStatefulWidget {
  const EnhancedWalletScreen({super.key});

  @override
  ConsumerState<EnhancedWalletScreen> createState() =>
      _EnhancedWalletScreenState();
}

class _EnhancedWalletScreenState extends ConsumerState<EnhancedWalletScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isProcessing = false;
  Razorpay? _razorpay;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _onRazorpayExternalWallet);
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userId = user?.id;

    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to view your wallet'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Wallet'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0B1C49),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(enhancedWalletProvider(userId));
          ref.invalidate(transactionHistoryProvider(userId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Card
              _buildBalanceCard(userId),
              const SizedBox(height: 20),

              // Quick Actions
              _buildQuickActions(),
              const SizedBox(height: 24),

              // Transaction History
              _buildTransactionHistory(userId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(String userId) {
    return Consumer(
      builder: (context, ref, child) {
        final walletAsync = ref.watch(enhancedWalletProvider(userId));

        return walletAsync.when(
          data: (wallet) => _buildWalletCard(wallet),
          loading: () => _buildLoadingCard(),
          error: (error, stack) => _buildErrorCard(error.toString()),
        );
      },
    );
  }

  Widget _buildWalletCard(EnhancedWallet wallet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B1C49),
            Color(0xFF1E3A8A),
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
                'Wallet Balance',
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
                  wallet.currency,
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
              wallet.balanceAvailable + wallet.balanceLocked,
              currency: wallet.currency,
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
                child: _buildBalanceItem(
                  'Available',
                  CurrencyUtils.formatAmount(wallet.balanceAvailable,
                      currency: wallet.currency),
                  Colors.green,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.2),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: _buildBalanceItem(
                  'Locked',
                  CurrencyUtils.formatAmount(wallet.balanceLocked,
                      currency: wallet.currency),
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, String amount, Color color) {
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
            Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      height: 180,
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
            'Unable to load wallet',
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
                icon: Icons.add_circle_outline,
                label: 'Add Money',
                color: Colors.green,
                onTap: _showTopUpDialog,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.send_outlined,
                label: 'Send Money',
                color: Colors.blue,
                onTap: _showSendMoneyDialog,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.history,
                label: 'History',
                color: Colors.purple,
                onTap: _showFullHistory,
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

  Widget _buildTransactionHistory(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            TextButton(
              onPressed: _showFullHistory,
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Consumer(
          builder: (context, ref, child) {
            final transactionsAsync =
                ref.watch(transactionHistoryProvider(userId));

            return transactionsAsync.when(
              data: (transactions) => _buildTransactionsList(transactions),
              loading: () => _buildTransactionsLoading(),
              error: (error, stack) =>
                  _buildTransactionsError(error.toString()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTransactionsList(List<LedgerTransaction> transactions) {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your transaction history will appear here',
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
        itemCount: transactions.take(5).length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey[200],
        ),
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return _buildTransactionTile(transaction);
        },
      ),
    );
  }

  Widget _buildTransactionTile(LedgerTransaction transaction) {
    final isCredit = transaction.direction == TransactionDirection.credit;
    final icon = _getTransactionIcon(transaction.type);
    final color = isCredit ? Colors.green : Colors.red;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        _getTransactionTitle(transaction.type),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        DateFormat('MMM dd, yyyy • hh:mm a').format(transaction.createdAt),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: Text(
        '${isCredit ? '+' : '-'}${CurrencyUtils.formatAmount(transaction.amount, currency: transaction.currency)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTransactionsLoading() {
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

  Widget _buildTransactionsError(String error) {
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
            'Unable to load transactions',
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.topup:
        return Icons.add_circle_outline;
      case TransactionType.reserve:
        return Icons.lock_outline;
      case TransactionType.release:
        return Icons.lock_open_outlined;
      case TransactionType.capture:
        return Icons.payment_outlined;
      case TransactionType.refund:
        return Icons.undo_outlined;
      case TransactionType.payout:
        return Icons.account_balance_outlined;
      case TransactionType.fee:
        return Icons.receipt_outlined;
      case TransactionType.mentorLock:
        return Icons.savings_outlined;
      case TransactionType.mentorRelease:
        return Icons.account_balance_wallet_outlined;
    }
  }

  String _getTransactionTitle(TransactionType type) {
    switch (type) {
      case TransactionType.topup:
        return 'Wallet Top-up';
      case TransactionType.reserve:
        return 'Funds Reserved';
      case TransactionType.release:
        return 'Funds Released';
      case TransactionType.capture:
        return 'Session Payment';
      case TransactionType.refund:
        return 'Refund Received';
      case TransactionType.payout:
        return 'Payout';
      case TransactionType.fee:
        return 'Platform Fee';
      case TransactionType.mentorLock:
        return 'Earnings Locked';
      case TransactionType.mentorRelease:
        return 'Earnings Released';
    }
  }

  void _showTopUpDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
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
                    'Add Money to Wallet',
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
              const SizedBox(height: 24),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Enter Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                  helperText: 'Minimum ₹50, Maximum ₹1,00,000',
                ),
              ),
              const SizedBox(height: 24),
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
                      onPressed: _isProcessing ? null : _processTopUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B1C49),
                        foregroundColor: Colors.white,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Add Money'),
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

  void _showSendMoneyDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Send money feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showFullHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TransactionHistoryScreen(),
      ),
    );
  }

  void _processTopUp() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum amount is ₹50')),
      );
      return;
    }

    if (amount > 100000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum amount is ₹1,00,000')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      if (kIsWeb) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Razorpay checkout is mobile-only. Use Stripe on web.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final amountPaise = (amount * 100).round();
      final user = ref.read(authProvider).user;
      final uid = user?.id;
      if (uid == null) throw Exception('Please log in');

      // Create a top-up intent via callable function (Razorpay order)
      final callable = FirebaseFunctions.instance.httpsCallable('createTopupIntent');
      final idem = 'topup_${DateTime.now().millisecondsSinceEpoch}';
      final response = await callable.call({
        'amount': amountPaise,
        'currency': 'INR',
        'gateway': 'razorpay',
        'idempotencyKey': idem,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      final orderId = data['orderId'] as String?;
      if (orderId == null) throw Exception('Failed to create Razorpay order');

      final options = {
        'key': 'rzp_test_...', // TODO: inject from env/remote config
        'amount': amountPaise,
        'currency': 'INR',
        'name': 'Instant Mentor',
        'description': 'Wallet Top-up',
        'order_id': orderId,
        'timeout': 300,
        'prefill': {
          'email': user?.email ?? '',
        },
        'notes': {
          'uid': uid,
          'idem': idem,
        },
      };

      _razorpay!.open(options);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process payment: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _onRazorpaySuccess(PaymentSuccessResponse res) {
    if (Navigator.canPop(context)) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment successful!')),
    );
    _amountController.clear();
  }

  void _onRazorpayError(PaymentFailureResponse res) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${res.message}')),
    );
  }

  void _onRazorpayExternalWallet(ExternalWalletResponse res) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet selected: ${res.walletName}')),
    );
  }
}

/// Full transaction history screen
class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final userId = user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: const Color(0xFF0B1C49),
        foregroundColor: Colors.white,
      ),
      body: userId == null
          ? const Center(child: Text('Please log in to view transactions'))
          : Consumer(
              builder: (context, ref, child) {
                final transactionsAsync =
                    ref.watch(transactionHistoryProvider(userId));

                return transactionsAsync.when(
                  data: (transactions) => transactions.isEmpty
                      ? const Center(child: Text('No transactions found'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final transaction = transactions[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                    _getTransactionTitle(transaction.type)),
                                subtitle: Text(
                                  DateFormat('MMM dd, yyyy • hh:mm a')
                                      .format(transaction.createdAt),
                                ),
                                trailing: Text(
                                  CurrencyUtils.formatAmount(transaction.amount,
                                      currency: transaction.currency),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: transaction.direction ==
                                            TransactionDirection.credit
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Text('Error loading transactions: $error'),
                  ),
                );
              },
            ),
    );
  }

  String _getTransactionTitle(TransactionType type) {
    switch (type) {
      case TransactionType.topup:
        return 'Wallet Top-up';
      case TransactionType.reserve:
        return 'Funds Reserved';
      case TransactionType.release:
        return 'Funds Released';
      case TransactionType.capture:
        return 'Session Payment';
      case TransactionType.refund:
        return 'Refund Received';
      case TransactionType.payout:
        return 'Payout';
      case TransactionType.fee:
        return 'Platform Fee';
      case TransactionType.mentorLock:
        return 'Earnings Locked';
      case TransactionType.mentorRelease:
        return 'Earnings Released';
    }
  }
}
