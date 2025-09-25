import 'package:flutter/material.dart';

/// Simple payment confirmation bottom sheet used before invoking Stripe payment sheet.
/// Shows a read-only cost breakdown and lets user confirm or cancel.
class PaymentCheckoutSheet extends StatelessWidget {
  final String mentorName;
  final double hourlyRate;
  final int minutes;
  final double amount;
  final VoidCallback onConfirm;

  const PaymentCheckoutSheet({
    super.key,
    required this.mentorName,
    required this.hourlyRate,
    required this.minutes,
    required this.amount,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.video_call, size: 22, color: Colors.green),
                const SizedBox(width: 8),
                Text('Instant Call Payment',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Mentor: $mentorName', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            _line('Hourly Rate', '\$${hourlyRate.toStringAsFixed(2)}'),
            _line('Minutes', minutes.toString()),
            _line('Prorated Cost', '\$${amount.toStringAsFixed(2)}'),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                    child: Text('Total Due',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold))),
                Text('\$${amount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.payment),
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Pay & Start Call'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '🔒 Secure payment • Demo mode',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
