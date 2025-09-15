import 'package:flutter/material.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Earnings Overview
          const Row(
            children: [
              Expanded(child: _EarningsCard('Today', '\$250', Colors.green)),
              SizedBox(width: 12),
              Expanded(child: _EarningsCard('This Week', '\$1,250', Colors.blue)),
              SizedBox(width: 12),
              Expanded(child: _EarningsCard('This Month', '\$4,800', Colors.purple)),
            ],
          ),
          
          const SizedBox(height: 24),
          Text(
            'Recent Earnings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          const Card(
            child: Column(
              children: [
                _EarningsTile('Alex Johnson', 'Mathematics', 50.0, 'Today, 2:00 PM'),
                Divider(height: 1),
                _EarningsTile('Maria Garcia', 'Mathematics', 37.5, 'Today, 10:00 AM'),
                Divider(height: 1),
                _EarningsTile('James Wilson', 'Physics', 50.0, 'Yesterday, 4:00 PM'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showWithdrawDialog(context),
              icon: const Icon(Icons.account_balance),
              label: const Text('Withdraw Earnings'),
            ),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Withdrawal feature coming soon!')),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;

  const _EarningsCard(this.title, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(amount, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _EarningsTile extends StatelessWidget {
  final String studentName;
  final String subject;
  final double amount;
  final String date;

  const _EarningsTile(this.studentName, this.subject, this.amount, this.date);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.withOpacity(0.1),
        child: const Icon(Icons.monetization_on, color: Colors.green),
      ),
      title: Text('Session with $studentName'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$subject • 1 hour'),
          Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      trailing: Text(
        '+\$${amount.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
      ),
    );
  }
}
