import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/student/wallet/enhanced_wallet_screen.dart';
import 'core/providers/upi_providers.dart';

void main() {
  runApp(
    ProviderScope(
      child: MaterialApp(
        title: 'UPI Wallet Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const UpiWalletDemo(),
      ),
    ),
  );
}

class UpiWalletDemo extends ConsumerWidget {
  const UpiWalletDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Payment Integration'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Demo Header
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🚀 UPI Payment Integration Demo',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Complete Google Pay, PhonePe, Paytm & BHIM UPI integration for your InstantMentor wallet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Features List
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✨ Features Implemented:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    _FeatureTile(
                      icon: Icons.payment,
                      title: 'Multiple UPI Apps',
                      subtitle: 'Google Pay, PhonePe, Paytm, BHIM support',
                    ),
                    _FeatureTile(
                      icon: Icons.security,
                      title: 'Secure Deep Linking',
                      subtitle: 'Safe UPI URL scheme integration',
                    ),
                    _FeatureTile(
                      icon: Icons.track_changes,
                      title: 'Transaction Tracking',
                      subtitle: 'Real-time payment verification',
                    ),
                    _FeatureTile(
                      icon: Icons.insights,
                      title: 'Spending Analytics',
                      subtitle: 'Detailed transaction insights',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // UPI Apps Status
            _buildUpiAppsStatus(context, ref),
            const SizedBox(height: 20),

            // Launch Wallet Button
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EnhancedWalletScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.account_balance_wallet, size: 24),
                      label: const Text(
                        'Open Enhanced Wallet',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Experience the complete UPI payment integration',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpiAppsStatus(BuildContext context, WidgetRef ref) {
    final upiAppsAsync = ref.watch(availableUpiAppsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📱 Available UPI Apps:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            upiAppsAsync.when(
              data: (apps) {
                if (apps.isEmpty) {
                  return const Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'No UPI apps found',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Install Google Pay, PhonePe, Paytm, or BHIM to test payments',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }

                return Column(
                  children: apps
                      .map((app) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: _getAppColor(app.name),
                                  child: Text(
                                    (app.name.isNotEmpty ? app.name[0] : '?'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    app.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                );
              },
              loading: () => const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Checking installed UPI apps...'),
                ],
              ),
              error: (error, _) => Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAppColor(String appName) {
    switch (appName.toLowerCase()) {
      case 'google pay':
        return Colors.blue;
      case 'phonepe':
        return Colors.purple;
      case 'paytm':
        return Colors.indigo;
      case 'bhim':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
