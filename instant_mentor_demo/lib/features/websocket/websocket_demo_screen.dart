import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/websocket_service.dart';
import '../../core/providers/websocket_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../common/widgets/websocket_status_widget.dart';
import '../common/widgets/realtime_chat_widget.dart';
import '../common/widgets/video_call_widget.dart';

class WebSocketDemoScreen extends ConsumerStatefulWidget {
  const WebSocketDemoScreen({super.key});

  @override
  ConsumerState<WebSocketDemoScreen> createState() =>
      _WebSocketDemoScreenState();
}

class _WebSocketDemoScreenState extends ConsumerState<WebSocketDemoScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final List<WebSocketMessage> _recentMessages = [];
  String _testReceiverId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _setupMessageListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setupMessageListener() {
    ref.listen(webSocketMessageProvider, (previous, next) {
      next.whenData((message) {
        setState(() {
          _recentMessages.insert(0, message);
          if (_recentMessages.length > 50) {
            _recentMessages.removeRange(50, _recentMessages.length);
          }
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebSocket Real-time Demo'),
        actions: [
          IconButton(
            onPressed: _showWebSocketSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Status', icon: Icon(Icons.network_check)),
            Tab(text: 'Chat', icon: Icon(Icons.chat)),
            Tab(text: 'Calls', icon: Icon(Icons.videocam)),
            Tab(text: 'Events', icon: Icon(Icons.event)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatusTab(),
          _buildChatTab(),
          _buildCallsTab(),
          _buildEventsTab(),
        ],
      ),
    );
  }

  Widget _buildStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailedWebSocketStatus(),
          const SizedBox(height: 16),
          const WebSocketDebugPanel(),
          const SizedBox(height: 16),
          _buildConnectionActions(),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        // Test user selector
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Test Receiver ID',
                    hintText: 'Enter user ID to chat with',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _testReceiverId = value;
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _testReceiverId.isNotEmpty ? _openChatDemo : null,
                child: const Text('Start Chat'),
              ),
            ],
          ),
        ),

        // Chat demo area
        Expanded(
          child: _testReceiverId.isNotEmpty
              ? RealTimeChatWidget(
                  receiverId: _testReceiverId,
                  receiverName: 'Test User ($_testReceiverId)',
                )
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Enter a receiver ID to start chatting',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCallsTab() {
    return Column(
      children: [
        // Video call controls
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Call Receiver ID',
                        hintText: 'Enter user ID to call',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _testReceiverId = value;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed:
                        _testReceiverId.isNotEmpty ? _initiateVideoCall : null,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Video Call'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed:
                    _testReceiverId.isNotEmpty ? _initiateAudioCall : null,
                icon: const Icon(Icons.call),
                label: const Text('Audio Call'),
              ),
            ],
          ),
        ),

        // Call events display
        Expanded(
          child: _buildCallEventsList(),
        ),
      ],
    );
  }

  Widget _buildEventsTab() {
    return Column(
      children: [
        // Event controls
        Container(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: _sendTestMessage,
                child: const Text('Send Test Event'),
              ),
              ElevatedButton(
                onPressed: _sendPresenceUpdate,
                child: const Text('Update Presence'),
              ),
              ElevatedButton(
                onPressed: _sendSystemNotification,
                child: const Text('System Notification'),
              ),
              ElevatedButton(
                onPressed: _clearEvents,
                child: const Text('Clear Events'),
              ),
            ],
          ),
        ),

        // Recent events list
        Expanded(
          child: _buildEventsList(),
        ),
      ],
    );
  }

  Widget _buildConnectionActions() {
    final webSocketManager = ref.read(webSocketManagerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await webSocketManager.disconnectConnection();
                    await Future.delayed(const Duration(seconds: 1));
                    // Auto-reconnect will happen via auth provider
                  },
                  child: const Text('Reconnect'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _runConnectionTest,
                  child: const Text('Test Connection'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    if (_recentMessages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No events yet',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _recentMessages.length,
      itemBuilder: (context, index) {
        final message = _recentMessages[index];
        return _buildEventTile(message);
      },
    );
  }

  Widget _buildEventTile(WebSocketMessage message) {
    final theme = Theme.of(context);
    final eventColor = _getEventColor(message.event);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: eventColor,
          child: Icon(
            _getEventIcon(message.event),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          message.event.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.senderId != null) Text('From: ${message.senderId}'),
            if (message.data.isNotEmpty)
              Text('Data: ${message.data.toString()}'),
            Text(
              _formatTimestamp(message.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildCallEventsList() {
    return Consumer(
      builder: (context, ref, child) {
        final callEvents = ref.watch(callEventsProvider);

        return callEvents.when(
          data: (event) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getEventIcon(event.event),
                  size: 64,
                  color: _getEventColor(event.event),
                ),
                const SizedBox(height: 16),
                Text(
                  'Last Call Event: ${event.event.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTimestamp(event.timestamp),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          loading: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Waiting for call events...',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          error: (error, _) => Center(
            child: Text('Error: $error'),
          ),
        );
      },
    );
  }

  Color _getEventColor(WebSocketEvent event) {
    switch (event) {
      case WebSocketEvent.userOnline:
      case WebSocketEvent.callAccepted:
      case WebSocketEvent.sessionStarted:
        return Colors.green;
      case WebSocketEvent.userOffline:
      case WebSocketEvent.callRejected:
      case WebSocketEvent.callEnded:
        return Colors.red;
      case WebSocketEvent.callInitiated:
      case WebSocketEvent.messageReceived:
      case WebSocketEvent.messageSent:
        return Colors.blue;
      case WebSocketEvent.userTyping:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getEventIcon(WebSocketEvent event) {
    switch (event) {
      case WebSocketEvent.userOnline:
        return Icons.person;
      case WebSocketEvent.userOffline:
        return Icons.person_off;
      case WebSocketEvent.messageReceived:
      case WebSocketEvent.messageSent:
        return Icons.message;
      case WebSocketEvent.callInitiated:
      case WebSocketEvent.callAccepted:
        return Icons.call;
      case WebSocketEvent.callRejected:
      case WebSocketEvent.callEnded:
        return Icons.call_end;
      case WebSocketEvent.userTyping:
        return Icons.keyboard;
      case WebSocketEvent.sessionStarted:
        return Icons.play_circle;
      case WebSocketEvent.sessionEnded:
        return Icons.stop_circle;
      default:
        return Icons.event;
    }
  }

  void _openChatDemo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: RealTimeChatWidget(
          receiverId: _testReceiverId,
          receiverName: 'Test User ($_testReceiverId)',
        ),
      ),
    );
  }

  void _initiateVideoCall() async {
    try {
      final callId = DateTime.now().millisecondsSinceEpoch.toString();
      final webSocketManager = ref.read(webSocketManagerProvider);

      await webSocketManager.initiateVideoCall(
        receiverId: _testReceiverId,
        callData: {'callId': callId},
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoCallWidget(
              callId: callId,
              receiverId: _testReceiverId,
              receiverName: 'Test User ($_testReceiverId)',
              isIncoming: false,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initiate call: $e')),
      );
    }
  }

  void _initiateAudioCall() async {
    try {
      final webSocketManager = ref.read(webSocketManagerProvider);
      await webSocketManager.initiateAudioCall(
        receiverId: _testReceiverId,
        callData: {'type': 'audio'},
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio call initiated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initiate call: $e')),
      );
    }
  }

  void _sendTestMessage() async {
    try {
      final webSocketService = ref.read(webSocketServiceProvider);
      final testMessage = WebSocketMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        event: WebSocketEvent.systemUpdate,
        data: {
          'test': true,
          'message': 'This is a test event',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      await webSocketService.sendMessage(testMessage);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test message sent')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send test message: $e')),
      );
    }
  }

  void _sendPresenceUpdate() async {
    try {
      final webSocketService = ref.read(webSocketServiceProvider);
      final presenceMessage = WebSocketMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        event: WebSocketEvent.userOnline,
        data: {
          'userId': ref.read(authProvider).user?.id ?? 'unknown',
          'status': 'active',
          'lastSeen': DateTime.now().toIso8601String(),
        },
      );

      await webSocketService.sendMessage(presenceMessage);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presence updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update presence: $e')),
      );
    }
  }

  void _sendSystemNotification() async {
    try {
      final webSocketService = ref.read(webSocketServiceProvider);
      final notificationMessage = WebSocketMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        event: WebSocketEvent.notificationReceived,
        data: {
          'title': 'Test Notification',
          'body': 'This is a test system notification',
          'type': 'system',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      await webSocketService.sendMessage(notificationMessage);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System notification sent')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send notification: $e')),
      );
    }
  }

  void _clearEvents() {
    setState(() {
      _recentMessages.clear();
    });
  }

  void _runConnectionTest() async {
    try {
      final webSocketService = ref.read(webSocketServiceProvider);

      if (!webSocketService.isConnected) {
        throw Exception('WebSocket not connected');
      }

      final testMessage = WebSocketMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        event: WebSocketEvent.systemUpdate,
        data: {'ping': 'test'},
      );

      await webSocketService.sendMessage(testMessage);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection test successful'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showWebSocketSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WebSocket Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WebSocketStatusIndicator(),
            SizedBox(height: 16),
            Text(
                'WebSocket connection is managed automatically based on your authentication status.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
