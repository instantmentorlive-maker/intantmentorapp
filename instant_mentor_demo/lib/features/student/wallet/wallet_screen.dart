import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/wallet.dart';
import '../../../core/payments/upi_payment_service.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/wallet_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final userId = user?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Balance card
            FutureBuilder<double>(
              future: userId != null
                  ? ref.watch(walletBalanceProvider(userId).future)
                  : Future.value(0.0),
              builder: (context, snapshot) {
                final balance = snapshot.data ?? 0.0;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Wallet Balance',
                                style: TextStyle(fontSize: 14)),
                            const SizedBox(height: 8),
                            Text('\u20B9${balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const _TransactionsScreen()));
                          },
                          child: const Text('Transactions'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Top-up input
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _topUp(userId),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Add Money via Google Pay'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Withdraw
            const Text('Withdraw',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _withdraw(userId),
              child: const Text('Request Withdrawal'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _topUp(String? userId) async {
    if (userId == null) return;
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter an amount to add.')));
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid number amount.')));
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amount must be greater than zero.')));
      return;
    }
    if (amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minimum top-up amount is ₹1.00.')));
      return;
    }

    setState(() => _loading = true);
    final upi = UpiPaymentService();
    final txnRef = DateTime.now().millisecondsSinceEpoch.toString();

    // Show available UPI apps and let user pick one when multiple are present.
    final apps = await upi
        .getInstalledUpiAppInfos(); // List<Map<String, String>> with keys 'id' and 'name'
    String? chosenAppId;
    if (apps.isNotEmpty) {
      chosenAppId = apps.length == 1
          ? apps.first['id']
          : await _showUpiAppPicker(context, apps);
    }

    final response = await upi.payWithUpi(
        amount: amount, note: 'Wallet top-up', appId: chosenAppId);

    if (response != null && response.status == UpiResultStatus.success) {
      final walletSvc = ref.read(walletServiceProvider);
      try {
        await walletSvc.addMoney(
            userId: userId,
            amount: amount,
            txnId: response.transactionId ?? txnRef);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Top-up successful. Txn: ${response.transactionId ?? txnRef}')));
        // Refresh balance
        ref.invalidate(walletBalanceProvider(userId));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Top-up recording failed: $e')));
      }
    } else if (response != null &&
        response.status == UpiResultStatus.submitted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Payment submitted. If debited, balance will update shortly.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('UPI payment failed or cancelled. Try again.')));
    }

    setState(() => _loading = false);
  }

  Future<String?> _showUpiAppPicker(
      BuildContext context, List<Map<String, String>> apps) async {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: apps.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final info = apps[index];
              final name = info['name']!;
              final id = info['id']!;
              return ListTile(
                leading: const Icon(Icons.payment),
                title: Text(name),
                onTap: () => Navigator.of(context).pop(id),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _withdraw(String? userId) async {
    if (userId == null) return;
    // For demo, ask amount
    final amountController = TextEditingController();
    final result = await showDialog<double?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Withdrawal'),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount (₹)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(
                  context, double.tryParse(amountController.text)),
              child: const Text('Request')),
        ],
      ),
    );

    if (result == null || result <= 0) return;
    final walletSvc = ref.read(walletServiceProvider);
    await walletSvc.requestWithdrawal(
        userId: userId, amount: result, bankAccountId: 'bank_placeholder');
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal request submitted')));
  }
}

class _TransactionsScreen extends ConsumerWidget {
  const _TransactionsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final userId = user?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: userId != null
            ? ref.watch(walletTransactionsProvider(userId).future)
            : Future.value([]),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No transactions'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item['txn_id'] ?? ''),
                subtitle: Text(item['status'] ?? ''),
                trailing: Text('\u20B9${(item['amount'] as num).toString()}'),
              );
            },
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isCredit
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        child: Icon(
          _getTransactionIcon(transaction.type),
          color: isCredit ? Colors.green : Colors.red,
        ),
      ),
      title: Text(transaction.description),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_getTransactionTypeText(transaction.type)),
          Text(
            DateFormat('MMM dd, yyyy • HH:mm').format(transaction.timestamp),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      trailing: Text(
        '${isCredit ? '+' : ''}\$${transaction.amount.abs().toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isCredit ? Colors.green : Colors.red,
          fontSize: 16,
        ),
      ),
      onTap: () => _showTransactionDetails(context, transaction),
    );
  }

  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.credit:
        return Icons.add;
      case TransactionType.sessionPayment:
        return Icons.school;
      case TransactionType.sessionEarning:
        return Icons.monetization_on;
      case TransactionType.withdrawal:
        return Icons.remove;
      case TransactionType.refund:
        return Icons.refresh;
      case TransactionType.bonus:
        return Icons.card_giftcard;
      case TransactionType.penalty:
        return Icons.warning;
      default:
        return Icons.monetization_on;
    }
  }

  String _getTransactionTypeText(TransactionType type) {
    switch (type) {
      case TransactionType.credit:
        return 'Credit';
      case TransactionType.sessionPayment:
        return 'Session Payment';
      case TransactionType.sessionEarning:
        return 'Session Earning';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.refund:
        return 'Refund';
      case TransactionType.bonus:
        return 'Bonus';
      case TransactionType.penalty:
        return 'Penalty';
      default:
        return 'Transaction';
    }
  }

  void _showTransactionDetails(BuildContext context, Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transaction Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
                'Amount', '\$${transaction.amount.abs().toStringAsFixed(2)}'),
            _DetailRow('Type', _getTransactionTypeText(transaction.type)),
            _DetailRow(
                'Date',
                DateFormat('MMM dd, yyyy • HH:mm')
                    .format(transaction.timestamp)),
            _DetailRow('Transaction ID', transaction.id),
            if (transaction.sessionId != null)
              _DetailRow('Session ID', transaction.sessionId!),
            if (transaction.metadata != null) ...[
              const SizedBox(height: 8),
              const Text('Additional Details:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...transaction.metadata!.entries.map(
                  (entry) => _DetailRow(entry.key, entry.value.toString())),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Receipt downloaded!')),
              );
            },
            child: const Text('Download Receipt'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// Payment method tiles removed (not used in simplified wallet UI)

// Insight items removed (not used in simplified wallet UI)

// Full Transaction History Screen
class TransactionHistoryScreen extends StatelessWidget {
  final List<Transaction> transactions;

  const TransactionHistoryScreen({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportTransactions(context),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: _TransactionTile(transaction: transaction),
          );
        },
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction filters coming soon!')),
    );
  }

  void _exportTransactions(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon!')),
    );
  }
}
