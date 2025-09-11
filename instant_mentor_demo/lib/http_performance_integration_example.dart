// HTTP Performance Optimization Integration Example
// 
// This file demonstrates how to integrate the HTTP Performance Optimization
// system into your Flutter app for maximum network performance.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

// Core imports for HTTP performance optimization
import 'core/network/enhanced_network_client.dart';
import 'core/network/http_retry.dart';
import 'core/network/offline_manager.dart';
import 'core/providers/network_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize HTTP Performance Optimization System
  await initializeHttpPerformance();
  
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

/// Initialize the HTTP Performance Optimization system
Future<void> initializeHttpPerformance() async {
  // Configure performance settings
  final config = PerformanceConfig()
    ..enableCaching = true              // HTTP response caching
    ..enableRetry = true                // Automatic request retry
    ..enableOfflineSupport = true       // Offline request queuing
    ..enableConnectionPooling = true    // Connection reuse
    ..enablePerformanceMonitoring = true // Real-time metrics
    ..maxConnections = 8                // Concurrent connections
    ..maxConnectionsPerHost = 6         // Per-host connections
    ..connectionTimeout = Duration(seconds: 15)
    ..receiveTimeout = Duration(seconds: 30)
    ..defaultCacheDuration = Duration(minutes: 10)
    ..retryConfig = RetryConfig(
      maxRetries: 3,
      baseDelay: Duration(seconds: 1),
      backoffMultiplier: 2.0,
      enableJitter: true,
      retryStatusCodes: [408, 429, 500, 502, 503, 504],
    );

  // Initialize the enhanced network client
  await EnhancedNetworkClient.initialize(config: config);
  
  print('🚀 HTTP Performance Optimization System initialized!');
  print('   ✅ HTTP Caching: ${config.enableCaching}');
  print('   ✅ Request Retry: ${config.enableRetry}');
  print('   ✅ Offline Support: ${config.enableOfflineSupport}');
  print('   ✅ Connection Pooling: ${config.enableConnectionPooling}');
  print('   ✅ Performance Monitoring: ${config.enablePerformanceMonitoring}');
}

class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'HTTP Performance Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch network connectivity status
    final connectivityState = ref.watch(networkConnectivityProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('HTTP Performance Demo'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          // Connectivity indicator
          Container(
            margin: EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  connectivityState.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: connectivityState.isOnline ? Colors.white : Colors.red[200],
                  size: 20,
                ),
                SizedBox(width: 4),
                if (connectivityState.queuedRequestsCount > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${connectivityState.queuedRequestsCount}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Performance status bar
          _buildPerformanceStatusBar(ref),
          
          // Main content
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'HTTP Performance Features',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Feature showcase
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildFeatureCard(
                          'HTTP Caching',
                          'Fast response times with intelligent caching',
                          Icons.cached,
                          Colors.green,
                        ),
                        _buildFeatureCard(
                          'Auto Retry',
                          'Reliable requests with exponential backoff',
                          Icons.refresh,
                          Colors.blue,
                        ),
                        _buildFeatureCard(
                          'Offline Queue',
                          'Never lose requests with offline support',
                          Icons.cloud_off,
                          Colors.orange,
                        ),
                        _buildFeatureCard(
                          'Monitoring',
                          'Real-time performance insights',
                          Icons.analytics,
                          Colors.purple,
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _makeTestRequest(ref),
                          icon: Icon(Icons.send),
                          label: Text('Test Request'),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showPerformanceStats(context, ref),
                          icon: Icon(Icons.analytics),
                          label: Text('View Stats'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceStatusBar(WidgetRef ref) {
    final performanceState = ref.watch(networkPerformanceProvider);
    final stats = performanceState.stats;
    
    return Container(
      padding: EdgeInsets.all(12),
      color: Colors.blue[50],
      child: Row(
        children: [
          _buildStatChip('Requests', '${stats.totalRequests}', Colors.blue),
          SizedBox(width: 8),
          _buildStatChip('Success', '${(stats.successRate * 100).toInt()}%', Colors.green),
          SizedBox(width: 8),
          _buildStatChip('Cached', '${(stats.cacheHitRate * 100).toInt()}%', Colors.purple),
          SizedBox(width: 8),
          _buildStatChip('Avg Time', '${stats.averageResponseTime.inMilliseconds}ms', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String title, String description, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makeTestRequest(WidgetRef ref) async {
    try {
      final client = ref.read(enhancedHttpClientProvider);
      
      // Make a test request with performance optimizations
      final response = await client.get('/test-endpoint');
      
      print('✅ Test request completed: ${response.statusCode}');
      print('   Cache status: ${response.statusMessage}');
    } catch (e) {
      print('❌ Test request failed: $e');
    }
  }

  void _showPerformanceStats(BuildContext context, WidgetRef ref) {
    final stats = ref.read(networkPerformanceProvider).stats;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Performance Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Requests: ${stats.totalRequests}'),
            Text('Success Rate: ${(stats.successRate * 100).toStringAsFixed(1)}%'),
            Text('Cache Hit Rate: ${(stats.cacheHitRate * 100).toStringAsFixed(1)}%'),
            Text('Average Response: ${stats.averageResponseTime.inMilliseconds}ms'),
            Text('P95 Response: ${stats.p95ResponseTime.inMilliseconds}ms'),
            Text('Failed Requests: ${stats.failedRequests}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Example usage in a service class
class ApiService {
  final Dio _client;
  
  ApiService(this._client);

  /// Get user data with caching
  Future<Map<String, dynamic>> getUserData(String userId) async {
    // This request will be automatically cached
    final response = await _client.get('/users/$userId');
    return response.data;
  }

  /// Create user with offline support
  Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
    final options = RequestOptions(
      path: '/users',
      method: 'POST',
      data: userData,
    )
      // Configure offline support
      ..setOfflinePriority(1)  // High priority for user creation
      ..setOfflineMetadata({'operation': 'create_user'});
    
    final response = await _client.fetch(options);
    return response.data;
  }

  /// Get data with custom retry policy
  Future<List<dynamic>> getDataWithRetry() async {
    final options = RequestOptions(path: '/data')
      // Use aggressive retry for critical data
      ..setRetryConfig(RetryPolicies.aggressive);
    
    final response = await _client.fetch(options);
    return response.data;
  }
}
