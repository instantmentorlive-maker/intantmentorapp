import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/network_providers.dart';
import '../../../core/network/enhanced_network_client.dart';

/// Network performance monitoring dashboard
class NetworkPerformanceDashboard extends ConsumerWidget {
  const NetworkPerformanceDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Network Performance'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              ref.read(networkPerformanceProvider.notifier).updateStats();
              ref.read(networkConnectivityProvider.notifier).checkConnectivity();
              ref.read(httpCacheProvider.notifier).refreshStats();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectivitySection(context, ref),
            SizedBox(height: 24),
            _buildPerformanceSection(context, ref),
            SizedBox(height: 24),
            _buildCacheSection(context, ref),
            SizedBox(height: 24),
            _buildOfflineSection(context, ref),
            SizedBox(height: 24),
            _buildActionsSection(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectivitySection(BuildContext context, WidgetRef ref) {
    final connectivityState = ref.watch(networkConnectivityProvider);
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  connectivityState.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: connectivityState.isOnline ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  'Connectivity Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildStatusTile(
              'Status',
              connectivityState.isOnline ? 'Online' : 'Offline',
              connectivityState.isOnline ? Colors.green : Colors.red,
            ),
            _buildStatusTile(
              'Last Checked',
              _formatDateTime(connectivityState.lastChecked),
              Colors.grey[600],
            ),
            _buildStatusTile(
              'Queued Requests',
              '${connectivityState.queuedRequestsCount}',
              connectivityState.queuedRequestsCount > 0 ? Colors.orange : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSection(BuildContext context, WidgetRef ref) {
    final performanceState = ref.watch(networkPerformanceProvider);
    final stats = performanceState.stats;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Performance Metrics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                Switch(
                  value: performanceState.isMonitoring,
                  onChanged: (value) {
                    if (value) {
                      ref.read(networkPerformanceProvider.notifier).enableMonitoring();
                    } else {
                      ref.read(networkPerformanceProvider.notifier).disableMonitoring();
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Requests',
                    '${stats.totalRequests}',
                    Icons.send,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Success Rate',
                    '${(stats.successRate * 100).toStringAsFixed(1)}%',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Avg Response',
                    '${stats.averageResponseTime.inMilliseconds}ms',
                    Icons.timer,
                    Colors.orange,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Cache Hit Rate',
                    '${(stats.cacheHitRate * 100).toStringAsFixed(1)}%',
                    Icons.cached,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            if (stats.totalRequests > 0) ...[
              SizedBox(height: 12),
              Text('Response Time Percentiles', 
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: _buildPercentileTile('P50', stats.p50ResponseTime)),
                  Expanded(child: _buildPercentileTile('P95', stats.p95ResponseTime)),
                  Expanded(child: _buildPercentileTile('P99', stats.p99ResponseTime)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCacheSection(BuildContext context, WidgetRef ref) {
    final cacheState = ref.watch(httpCacheProvider);
    final stats = cacheState.stats;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'HTTP Cache',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(httpCacheProvider.notifier).clearCache();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cache cleared')),
                    );
                  },
                  icon: Icon(Icons.clear_all),
                  label: Text('Clear'),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (stats.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Memory Entries',
                      '${stats['memoryEntries'] ?? 0}',
                      Icons.memory,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      'Disk Entries',
                      '${stats['diskEntries'] ?? 0}',
                      Icons.sd_storage,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              if ((stats['expiredEntries'] as int? ?? 0) > 0) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '${stats['expiredEntries']} expired entries need cleanup',
                        style: TextStyle(color: Colors.orange[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ] else
              Text('No cache statistics available'),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineSection(BuildContext context, WidgetRef ref) {
    final offlineStats = ref.watch(offlineStatsProvider);
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Offline Support',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Queue Size',
                    '${offlineStats['queueSize'] ?? 0}',
                    Icons.queue,
                    Colors.orange,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Processing',
                    '${offlineStats['processingCount'] ?? 0}',
                    Icons.sync,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            if ((offlineStats['queueSize'] as int? ?? 0) > 0) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref.read(networkConnectivityProvider.notifier).processOfflineQueue();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Processing offline queue...')),
                        );
                      },
                      icon: Icon(Icons.play_arrow),
                      label: Text('Process Queue'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(networkConnectivityProvider.notifier).clearOfflineQueue();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Queue cleared')),
                        );
                      },
                      icon: Icon(Icons.clear),
                      label: Text('Clear Queue'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await EnhancedNetworkClient.clearCaches();
                    ref.read(networkPerformanceProvider.notifier).resetMetrics();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('All caches and metrics cleared')),
                    );
                  },
                  icon: Icon(Icons.cleaning_services),
                  label: Text('Clear All'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(networkPerformanceProvider.notifier).resetMetrics();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Performance metrics reset')),
                    );
                  },
                  icon: Icon(Icons.restart_alt),
                  label: Text('Reset Metrics'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _showDetailedStats(context, ref);
                  },
                  icon: Icon(Icons.info_outline),
                  label: Text('Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile(String label, String value, Color? color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPercentileTile(String label, Duration duration) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 2),
          Text(
            '${duration.inMilliseconds}ms',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  void _showDetailedStats(BuildContext context, WidgetRef ref) {
    final stats = EnhancedNetworkClient.getPerformanceStats();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detailed Network Statistics'),
        content: SingleChildScrollView(
          child: Container(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final category in stats.entries)
                  ExpansionTile(
                    title: Text(category.key.toUpperCase()),
                    children: [
                      if (category.value is Map<String, dynamic>)
                        for (final entry in (category.value as Map<String, dynamic>).entries)
                          ListTile(
                            dense: true,
                            title: Text(entry.key),
                            trailing: Text('${entry.value}'),
                          ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
