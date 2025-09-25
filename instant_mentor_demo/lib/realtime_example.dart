import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/realtime/messaging_service.dart';
import '../core/realtime/notification_service.dart';
import '../core/realtime/socketio_client.dart';
import '../core/realtime/websocket_client.dart';

/// Example demonstrating real-time features usage
class RealtimeExampleApp extends ConsumerStatefulWidget {
  const RealtimeExampleApp({super.key});

  @override
  ConsumerState<RealtimeExampleApp> createState() => _RealtimeExampleAppState();
}

class _RealtimeExampleAppState extends ConsumerState<RealtimeExampleApp> {
  final TextEditingController _messageController = TextEditingController();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeRealtimeServices();
  }

  Future<void> _initializeRealtimeServices() async {
    try {
      // Initialize WebSocket client
      final webSocketClient = WebSocketClient.instance;
      await webSocketClient.connect(
        'wss://echo.websocket.org', // Example WebSocket server
        config: const WebSocketConfig(),
      );

      // Initialize Socket.IO client
      final socketIOClient = SocketIOClient.instance;
      await socketIOClient.connect(
        'http://localhost:3000', // Your Socket.IO server
        config: const SocketConfig(),
      );

      // Initialize messaging service
      final messagingService = RealtimeMessagingService.instance;
      await messagingService.initialize(
        userId: 'demo_user_123',
        serverUrl: 'http://localhost:3000',
        auth: {'token': 'demo_auth_token'},
      );

      // Initialize notification service
      final notificationService = RealtimeNotificationService.instance;
      await notificationService.initialize(
        userId: 'demo_user_123',
        preferences: const NotificationPreferences(),
      );

      setState(() {
        _isInitialized = true;
      });

      _showSnackBar('Real-time services initialized!');
    } catch (e) {
      _showSnackBar('Failed to initialize: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Real-time Services...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Features Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            onPressed: _showDashboard,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // WebSocket Demo Section
            _buildSectionCard(
              'WebSocket Demo',
              [
                ElevatedButton(
                  onPressed: _sendWebSocketPing,
                  child: const Text('Send Ping'),
                ),
                ElevatedButton(
                  onPressed: _sendWebSocketMessage,
                  child: const Text('Send Message'),
                ),
                ElevatedButton(
                  onPressed: _disconnectWebSocket,
                  child: const Text('Disconnect'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Socket.IO Demo Section
            _buildSectionCard(
              'Socket.IO Demo',
              [
                ElevatedButton(
                  onPressed: _sendSocketIOEvent,
                  child: const Text('Send Event'),
                ),
                ElevatedButton(
                  onPressed: _joinRoom,
                  child: const Text('Join Room'),
                ),
                ElevatedButton(
                  onPressed: _leaveRoom,
                  child: const Text('Leave Room'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Messaging Demo Section
            _buildSectionCard(
              'Messaging Demo',
              [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Enter message...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _sendMessage,
                      child: const Text('Send'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _startTyping,
                      child: const Text('Start Typing'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _stopTyping,
                      child: const Text('Stop Typing'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _updatePresence,
                      child: const Text('Set Online'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Notifications Demo Section
            _buildSectionCard(
              'Notifications Demo',
              [
                ElevatedButton(
                  onPressed: _sendTestNotification,
                  child: const Text('Send Test Notification'),
                ),
                ElevatedButton(
                  onPressed: _sendUrgentAlert,
                  child: const Text('Send Urgent Alert'),
                ),
                ElevatedButton(
                  onPressed: _sendAchievement,
                  child: const Text('Send Achievement'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: children,
            ),
          ],
        ),
      ),
    );
  }

  // WebSocket methods
  void _sendWebSocketPing() {
    final client = WebSocketClient.instance;
    client.ping(data: 'Hello from Flutter!');
    _showSnackBar('WebSocket ping sent');
  }

  void _sendWebSocketMessage() {
    final client = WebSocketClient.instance;
    client.send({'type': 'demo', 'message': 'Hello WebSocket!'});
    _showSnackBar('WebSocket message sent');
  }

  void _disconnectWebSocket() async {
    final client = WebSocketClient.instance;
    await client.disconnect();
    _showSnackBar('WebSocket disconnected');
  }

  // Socket.IO methods
  void _sendSocketIOEvent() {
    final client = SocketIOClient.instance;
    client.emit('demo_event', {
      'message': 'Hello Socket.IO!',
      'timestamp': DateTime.now().toIso8601String(),
    });
    _showSnackBar('Socket.IO event sent');
  }

  void _joinRoom() {
    final client = SocketIOClient.instance;
    client.joinRoom('demo_room');
    _showSnackBar('Joined demo_room');
  }

  void _leaveRoom() {
    final client = SocketIOClient.instance;
    client.leaveRoom('demo_room');
    _showSnackBar('Left demo_room');
  }

  // Messaging methods
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final service = RealtimeMessagingService.instance;
    await service.sendMessage(
      content: text,
      roomId: 'demo_room',
    );

    _messageController.clear();
    _showSnackBar('Message sent: $text');
  }

  void _startTyping() {
    final service = RealtimeMessagingService.instance;
    service.startTyping(roomId: 'demo_room');
    _showSnackBar('Started typing indicator');
  }

  void _stopTyping() {
    final service = RealtimeMessagingService.instance;
    service.stopTyping(roomId: 'demo_room');
    _showSnackBar('Stopped typing indicator');
  }

  void _updatePresence() {
    final service = RealtimeMessagingService.instance;
    service.updatePresence(
      PresenceStatus.online,
      customStatus: 'Available for demo',
    );
    _showSnackBar('Presence updated to online');
  }

  // Notification methods
  void _sendTestNotification() async {
    final service = RealtimeNotificationService.instance;
    await service.sendNotification(
      title: 'Test Notification',
      body: 'This is a test notification from the demo app',
      type: NotificationType.system,
    );
    _showSnackBar('Test notification sent');
  }

  void _sendUrgentAlert() async {
    final service = RealtimeNotificationService.instance;
    await service.sendNotification(
      title: '🚨 Urgent Alert',
      body: 'This is an urgent alert that requires immediate attention!',
      type: NotificationType.alert,
      priority: NotificationPriority.critical,
    );
    _showSnackBar('Urgent alert sent');
  }

  void _sendAchievement() async {
    final service = RealtimeNotificationService.instance;
    await service.sendNotification(
      title: '🏆 Achievement Unlocked!',
      body: 'You have successfully tested the real-time notification system!',
      type: NotificationType.achievement,
      priority: NotificationPriority.high,
    );
    _showSnackBar('Achievement notification sent');
  }

  void _showDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RealtimeDashboard(),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

/// Import the dashboard widget (this would be in a separate file in real usage)
class RealtimeDashboard extends StatelessWidget {
  const RealtimeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Dashboard'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard, size: 64),
            SizedBox(height: 16),
            Text('Dashboard UI would be implemented here'),
            SizedBox(height: 8),
            Text(
              'This would show real-time connection status,\nmessages, notifications, and controls',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// Demo app entry point
void main() {
  runApp(
    const ProviderScope(
      child: MaterialApp(
        title: 'Real-time Features Demo',
        home: RealtimeExampleApp(),
      ),
    ),
  );
}
