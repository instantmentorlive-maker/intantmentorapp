import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/network/http_retry.dart';
import '../core/network/offline_manager.dart';
import '../core/providers/network_providers.dart';
import '../features/common/widgets/network_performance_dashboard.dart';

/// Example of using HTTP Performance Optimization features
class HttpPerformanceExample extends ConsumerWidget {
  const HttpPerformanceExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HTTP Performance Example'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NetworkPerformanceDashboard(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HTTP Performance Features',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Test Operations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTestCard(
                      'HTTP Caching',
                      'Test request caching with various cache control strategies',
                      Icons.cached,
                      Colors.green,
                      () => _testHttpCaching(context, ref),
                    ),
                    _buildTestCard(
                      'Request Retry',
                      'Test automatic retry with exponential backoff',
                      Icons.refresh,
                      Colors.blue,
                      () => _testRequestRetry(context, ref),
                    ),
                    _buildTestCard(
                      'Offline Support',
                      'Test offline request queuing and synchronization',
                      Icons.cloud_off,
                      Colors.orange,
                      () => _testOfflineSupport(context, ref),
                    ),
                    _buildTestCard(
                      'Connection Pooling',
                      'Test connection reuse and performance optimization',
                      Icons.link,
                      Colors.purple,
                      () => _testConnectionPooling(context, ref),
                    ),
                    _buildTestCard(
                      'Performance Monitoring',
                      'View real-time performance metrics and statistics',
                      Icons.analytics,
                      Colors.red,
                      () => _showPerformanceDashboard(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureList() {
    const features = [
      'HTTP Response Caching (Memory + Disk)',
      'Automatic Request Retry with Exponential Backoff',
      'Offline Request Queuing and Sync',
      'Connection Pooling and Keep-Alive',
      'Real-time Performance Monitoring',
      'Request/Response Compression',
      'ETag and Conditional Request Support',
    ];

    return Column(
      children: features
          .map((feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildTestCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Future<void> _testHttpCaching(BuildContext context, WidgetRef ref) async {
    try {
      _showProgressDialog(context, 'Testing HTTP Caching...');
      
      final client = ref.read(enhancedHttpClientProvider);
      
      // First request - should hit the server
      final response1 = await client.get('/test-endpoint');
      
      // Second request - should use cache
      final response2 = await client.get('/test-endpoint');
      
      Navigator.pop(context); // Close progress dialog
      
      _showResultDialog(
        context,
        'HTTP Caching Test',
        'First request: ${response1.statusMessage}\n'
        'Second request: ${response2.statusMessage}\n'
        'Cache likely used for second request!',
      );
    } catch (e) {
      Navigator.pop(context); // Close progress dialog
      _showErrorDialog(context, 'Caching test failed: $e');
    }
  }

  Future<void> _testRequestRetry(BuildContext context, WidgetRef ref) async {
    try {
      _showProgressDialog(context, 'Testing Request Retry...');
      
      final client = ref.read(enhancedHttpClientProvider);
      
      // Configure request with retry options
      final options = RequestOptions(path: '/failing-endpoint')
        ..setRetryConfig(RetryPolicies.aggressive);
      
      final response = await client.fetch(options);
      
      Navigator.pop(context); // Close progress dialog
      
      _showResultDialog(
        context,
        'Request Retry Test',
        'Request completed after potential retries!\n'
        'Status: ${response.statusCode}\n'
        'Retry attempts: ${options.retryAttempt}',
      );
    } catch (e) {
      Navigator.pop(context); // Close progress dialog
      _showResultDialog(
        context,
        'Request Retry Test',
        'Request failed after retries: $e\n'
        'This demonstrates the retry mechanism working!',
      );
    }
  }

  Future<void> _testOfflineSupport(BuildContext context, WidgetRef ref) async {
    try {
      _showProgressDialog(context, 'Testing Offline Support...');
      
      final client = ref.read(enhancedHttpClientProvider);
      final connectivityNotifier = ref.read(networkConnectivityProvider.notifier);
      
      // Get current offline queue size
      final initialQueueSize = ref.read(networkConnectivityProvider).queuedRequestsCount;
      
      // Make a request that might be queued if offline
      final options = RequestOptions(
        path: '/offline-test',
        method: 'POST',
        data: {'test': 'offline support'},
      )
        ..setOfflinePriority(1)
        ..setOfflineMetadata({'test': true});
      
      await client.fetch(options);
      
      // Check if queue size changed
      await connectivityNotifier.checkConnectivity();
      final finalQueueSize = ref.read(networkConnectivityProvider).queuedRequestsCount;
      
      Navigator.pop(context); // Close progress dialog
      
      _showResultDialog(
        context,
        'Offline Support Test',
        'Initial queue size: $initialQueueSize\n'
        'Final queue size: $finalQueueSize\n'
        'Request handling completed!',
      );
    } catch (e) {
      Navigator.pop(context); // Close progress dialog
      _showErrorDialog(context, 'Offline test failed: $e');
    }
  }

  Future<void> _testConnectionPooling(BuildContext context, WidgetRef ref) async {
    try {
      _showProgressDialog(context, 'Testing Connection Pooling...');
      
      final client = ref.read(enhancedHttpClientProvider);
      
      // Make multiple concurrent requests
      final futures = List.generate(5, (index) => 
        client.get('/test-endpoint?request=$index')
      );
      
      final responses = await Future.wait(futures);
      
      Navigator.pop(context); // Close progress dialog
      
      _showResultDialog(
        context,
        'Connection Pooling Test',
        'Completed ${responses.length} concurrent requests!\n'
        'Connection pooling optimizes reuse of TCP connections.\n'
        'Check performance dashboard for detailed metrics.',
      );
    } catch (e) {
      Navigator.pop(context); // Close progress dialog
      _showErrorDialog(context, 'Connection pooling test failed: $e');
    }
  }

  void _showPerformanceDashboard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NetworkPerformanceDashboard(),
      ),
    );
  }

  void _showProgressDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showResultDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
