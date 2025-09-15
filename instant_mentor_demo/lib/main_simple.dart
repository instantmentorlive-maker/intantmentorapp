import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simple state provider
final currentIndexProvider = StateProvider<int>((ref) => 0);

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InstantMentor Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DemoScreen(),
    );
  }
}

class DemoScreen extends ConsumerWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('InstantMentor - Days 27-30 Features'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: (index) => ref.read(currentIndexProvider.notifier).state = index,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.offline_bolt), label: 'Offline'),
          BottomNavigationBarItem(
              icon: Icon(Icons.error_outline), label: 'Error Recovery'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: 'Push Notifications'),
          BottomNavigationBarItem(
              icon: Icon(Icons.speed), label: 'Database Optimization'),
        ],
      ),
    );
  }

  Widget _buildBody(int currentIndex) {
    switch (currentIndex) {
      case 0:
        return _buildOfflineScreen();
      case 1:
        return _buildErrorRecoveryScreen();
      case 2:
        return _buildPushNotificationsScreen();
      case 3:
        return _buildDatabaseOptimizationScreen();
      default:
        return _buildOfflineScreen();
    }
  }

  Widget _buildOfflineScreen() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Day 27: Offline Support',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          FeatureCard(
            title: 'Hive Local Storage',
            description:
                'Encrypted offline data storage for chat messages, user profiles, and session history.',
            icon: Icons.storage,
            status: 'Implemented',
          ),
          SizedBox(height: 8),
          FeatureCard(
            title: 'Auto Sync',
            description:
                'Automatic synchronization of offline data when connection is restored.',
            icon: Icons.sync,
            status: 'Active',
          ),
          SizedBox(height: 8),
          FeatureCard(
            title: 'Conflict Resolution',
            description:
                'Smart merge strategy for handling data conflicts during sync.',
            icon: Icons.merge_type,
            status: 'Ready',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorRecoveryScreen() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Day 28: Advanced Error Recovery',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          FeatureCard(
            title: 'Circuit Breaker Pattern',
            description:
                'Prevents cascading failures by temporarily disabling failing services.',
            icon: Icons.electrical_services,
            status: 'Active',
          ),
          SizedBox(height: 8),
          FeatureCard(
            title: 'Exponential Backoff',
            description:
                'Intelligent retry mechanism with increasing delay intervals.',
            icon: Icons.timer,
            status: 'Implemented',
          ),
          SizedBox(height: 8),
          FeatureCard(
            title: 'Fallback Strategies',
            description:
                'Alternative data sources and cached responses for resilience.',
            icon: Icons.backup,
            status: 'Ready',
          ),
        ],
      ),
    );
  }

  Widget _buildPushNotificationsScreen() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Day 29: Push Notifications',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          FeatureCard(
            title: 'Firebase Cloud Messaging',
            description:
                'Real-time push notifications for session updates and messages.',
            icon: Icons.cloud_circle,
            status: 'Connected',
          ),
          SizedBox(height: 8),
          FeatureCard(
            title: 'Deep Linking',
            description:
                'Direct navigation to specific app screens from notifications.',
            icon: Icons.link,
            status: 'Configured',
          ),
          SizedBox(height: 8),
          FeatureCard(
            title: 'User Preferences',
            description: 'Customizable notification settings and categories.',
            icon: Icons.settings_applications,
            status: 'Available',
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseOptimizationScreen() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Day 30: Database Optimization',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          FeatureCard(
            title: 'Query Caching',
            description:
                'Intelligent caching layer for frequently accessed data.',
            icon: Icons.cached,
            status: 'Optimized',
          ),
          SizedBox(height: 8),
          FeatureCard(
            title: 'Batch Operations',
            description: 'Efficient batch processing for bulk data operations.',
            icon: Icons.layers,
            status: 'Enhanced',
          ),
          SizedBox(height: 8),
          FeatureCard(
            title: 'Performance Monitoring',
            description: 'Real-time database performance metrics and alerts.',
            icon: Icons.monitor,
            status: 'Monitoring',
          ),
        ],
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String status;

  const FeatureCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = _getStatusColor(status);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'implemented':
      case 'active':
      case 'ready':
      case 'connected':
      case 'configured':
      case 'available':
      case 'optimized':
      case 'enhanced':
      case 'monitoring':
        return Colors.green;
      case 'pending':
      case 'in progress':
        return Colors.orange;
      case 'error':
      case 'failed':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
