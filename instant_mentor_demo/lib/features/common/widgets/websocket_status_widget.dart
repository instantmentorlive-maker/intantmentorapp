import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/websocket_provider.dart';
import '../../../core/services/websocket_service.dart';

class WebSocketStatusIndicator extends ConsumerWidget {
  final bool showText;
  final bool showIcon;
  final MainAxisSize mainAxisSize;

  const WebSocketStatusIndicator({
    super.key,
    this.showText = true,
    this.showIcon = true,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(webSocketConnectionStateProvider);
    final theme = Theme.of(context);

    return connectionState.when(
      data: (state) {
        final (icon, color, text) = _getStatusInfo(state);

        return Row(
          mainAxisSize: mainAxisSize,
          children: [
            if (showIcon) ...[
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              if (showText) const SizedBox(width: 6),
            ],
            if (showText)
              Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        );
      },
      loading: () => Row(
        mainAxisSize: mainAxisSize,
        children: [
          if (showIcon) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            if (showText) const SizedBox(width: 6),
          ],
          if (showText)
            Text(
              'Connecting...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
      error: (error, _) => Row(
        mainAxisSize: mainAxisSize,
        children: [
          if (showIcon) ...[
            Icon(
              Icons.error_outline,
              size: 16,
              color: theme.colorScheme.error,
            ),
            if (showText) const SizedBox(width: 6),
          ],
          if (showText)
            Text(
              'Connection Error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }

  (IconData, Color, String) _getStatusInfo(WebSocketConnectionState state) {
    switch (state) {
      case WebSocketConnectionState.connected:
        return (Icons.wifi, Colors.green, 'Connected');
      case WebSocketConnectionState.connecting:
        return (Icons.wifi_off, Colors.orange, 'Connecting...');
      case WebSocketConnectionState.reconnecting:
        return (Icons.wifi_off, Colors.orange, 'Reconnecting...');
      case WebSocketConnectionState.disconnected:
        return (Icons.wifi_off, Colors.grey, 'Disconnected');
      case WebSocketConnectionState.error:
        return (Icons.wifi_off, Colors.red, 'Error');
    }
  }
}

class DetailedWebSocketStatus extends ConsumerWidget {
  const DetailedWebSocketStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(webSocketConnectionStateProvider);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.network_check,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Real-time Connection',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            connectionState.when(
              data: (state) {
                final (icon, color, text) = _getDetailedStatusInfo(state);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Status: $text',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getStatusDescription(state),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                );
              },
              loading: () => Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Initializing connection...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              error: (error, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Connection Failed',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to establish real-time connection. Some features may not work properly.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, String) _getDetailedStatusInfo(
      WebSocketConnectionState state) {
    switch (state) {
      case WebSocketConnectionState.connected:
        return (Icons.cloud_done, Colors.green, 'Connected');
      case WebSocketConnectionState.connecting:
        return (Icons.cloud_sync, Colors.orange, 'Connecting');
      case WebSocketConnectionState.reconnecting:
        return (Icons.cloud_sync, Colors.orange, 'Reconnecting');
      case WebSocketConnectionState.disconnected:
        return (Icons.cloud_off, Colors.grey, 'Disconnected');
      case WebSocketConnectionState.error:
        return (Icons.cloud_off, Colors.red, 'Connection Error');
    }
  }

  String _getStatusDescription(WebSocketConnectionState state) {
    switch (state) {
      case WebSocketConnectionState.connected:
        return 'Real-time features are working. You can receive instant messages, calls, and notifications.';
      case WebSocketConnectionState.connecting:
        return 'Establishing connection for real-time features...';
      case WebSocketConnectionState.reconnecting:
        return 'Attempting to restore connection for real-time features...';
      case WebSocketConnectionState.disconnected:
        return 'Real-time features are disabled. Messages and calls may be delayed.';
      case WebSocketConnectionState.error:
        return 'Failed to connect. Real-time features are unavailable. Check your internet connection.';
    }
  }
}

class WebSocketDebugPanel extends ConsumerWidget {
  const WebSocketDebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(webSocketConnectionStateProvider);
    final webSocketService = ref.watch(webSocketServiceProvider);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WebSocket Debug Info',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDebugRow(
                'User ID', webSocketService.currentUserId ?? 'Not set'),
            _buildDebugRow(
                'Connection State', connectionState.value?.name ?? 'Unknown'),
            _buildDebugRow(
                'Is Connected', webSocketService.isConnected.toString()),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final webSocketManager = ref.read(webSocketManagerProvider);
                    // Force reconnection
                    await webSocketManager.disconnectConnection();
                    await Future.delayed(const Duration(seconds: 1));
                    // Connection will be re-established automatically by auth provider
                  },
                  child: const Text('Reconnect'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    // Send test message
                    final testMessage = WebSocketMessage(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      event: WebSocketEvent.systemUpdate,
                      data: {
                        'test': 'ping',
                        'timestamp': DateTime.now().toIso8601String()
                      },
                    );

                    webSocketService.sendMessage(testMessage).catchError((e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Test failed: $e')),
                      );
                    });
                  },
                  child: const Text('Send Test'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
