import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/realtime_providers.dart';
import '../../../core/realtime/websocket_client.dart';
import '../../../core/realtime/socketio_client.dart';
import '../../../core/realtime/messaging_service.dart';
import '../../../core/realtime/notification_service.dart';

/// Real-time features dashboard widget
class RealtimeDashboard extends ConsumerStatefulWidget {
  const RealtimeDashboard({super.key});

  @override
  ConsumerState<RealtimeDashboard> createState() => _RealtimeDashboardState();
}

class _RealtimeDashboardState extends ConsumerState<RealtimeDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(realtimeDashboardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Dashboard'),
        backgroundColor: theme.colorScheme.primaryContainer,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.message), text: 'Messaging'),
            Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(dashboard),
          _buildMessagingTab(),
          _buildNotificationsTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(RealtimeDashboardState dashboard) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Connection Status Cards
          Row(
            children: [
              Expanded(
                child: _buildConnectionCard(
                  'WebSocket',
                  dashboard.webSocketState,
                  dashboard.webSocketStats.totalMessages,
                  dashboard.webSocketStats.totalErrors,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildConnectionCard(
                  'Socket.IO',
                  dashboard.socketIOState,
                  dashboard.socketIOStats.totalEvents,
                  dashboard.socketIOStats.totalErrors,
                  Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Quick Stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Stats',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        Icons.notifications_active,
                        '${dashboard.unreadNotifications}',
                        'Unread Notifications',
                        Colors.orange,
                      ),
                      _buildStatItem(
                        Icons.people,
                        '${dashboard.userPresences.length}',
                        'Online Users',
                        Colors.green,
                      ),
                      _buildStatItem(
                        Icons.keyboard,
                        '${dashboard.typingUsers.length}',
                        'Typing Users',
                        Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Connection Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildActionButton(
                        'Test WebSocket',
                        Icons.wifi,
                        () => _testWebSocket(),
                        dashboard.webSocketState == WebSocketConnectionState.connected
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      _buildActionButton(
                        'Test Socket.IO',
                        Icons.swap_calls,
                        () => _testSocketIO(),
                        dashboard.socketIOState == SocketConnectionState.connected
                            ? Colors.green
                            : Colors.grey,
                      ),
                      _buildActionButton(
                        'Send Test Message',
                        Icons.send,
                        () => _sendTestMessage(),
                        dashboard.isConnected ? Colors.purple : Colors.grey,
                      ),
                      _buildActionButton(
                        'Send Test Notification',
                        Icons.notification_add,
                        () => _sendTestNotification(),
                        dashboard.isConnected ? Colors.orange : Colors.grey,
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

  Widget _buildMessagingTab() {
    return Consumer(
      builder: (context, ref, child) {
        final messagesAsync = ref.watch(messagesStreamProvider);
        final typingUsers = ref.watch(typingUsersProvider);
        final userPresences = ref.watch(userPresencesProvider);

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Typing Indicators
              if (typingUsers.isNotEmpty)
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.keyboard, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          '${typingUsers.values.map((t) => t.userId).join(', ')} typing...',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // User Presence
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Online Users (${userPresences.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (userPresences.isEmpty)
                        const Text('No users online')
                      else
                        Wrap(
                          spacing: 8,
                          children: userPresences.values.map((presence) {
                            return Chip(
                              avatar: CircleAvatar(
                                backgroundColor: _getPresenceColor(presence.status),
                                radius: 6,
                              ),
                              label: Text(presence.userId),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Recent Messages
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Messages',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: messagesAsync.when(
                            data: (message) => _buildMessagesList([message]),
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (error, stack) => Center(
                              child: Text('Error: $error'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final notifications = ref.watch(allNotificationsProvider);
        final unreadCount = ref.watch(unreadCountProvider);

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Notification Stats
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        Icons.notifications,
                        '${notifications.length}',
                        'Total',
                        Colors.blue,
                      ),
                      _buildStatItem(
                        Icons.mark_email_unread,
                        '$unreadCount',
                        'Unread',
                        Colors.red,
                      ),
                      _buildStatItem(
                        Icons.mark_email_read,
                        '${notifications.length - unreadCount}',
                        'Read',
                        Colors.green,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Notification Actions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: unreadCount > 0
                            ? () => ref.read(allNotificationsProvider.notifier).markAllAsRead()
                            : null,
                        icon: const Icon(Icons.done_all),
                        label: const Text('Mark All Read'),
                      ),
                      ElevatedButton.icon(
                        onPressed: notifications.isNotEmpty
                            ? () => ref.read(allNotificationsProvider.notifier).clearNotifications()
                            : null,
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear All'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Notifications List
              Expanded(
                child: Card(
                  child: notifications.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No notifications'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return _buildNotificationTile(notification, ref);
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final preferences = ref.watch(notificationPreferencesProvider);

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // Notification Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification Settings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Push Notifications'),
                        subtitle: const Text('Receive push notifications'),
                        value: preferences.enablePush,
                        onChanged: (value) => ref
                            .read(notificationPreferencesProvider.notifier)
                            .togglePush(value),
                      ),
                      SwitchListTile(
                        title: const Text('In-App Notifications'),
                        subtitle: const Text('Show notifications within the app'),
                        value: preferences.enableInApp,
                        onChanged: (value) => ref
                            .read(notificationPreferencesProvider.notifier)
                            .toggleInApp(value),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Notification Types
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification Types',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ...NotificationType.values.map((type) {
                        final enabled = preferences.typePreferences[type] ?? true;
                        return SwitchListTile(
                          title: Text(_getNotificationTypeName(type)),
                          value: enabled,
                          onChanged: (value) => ref
                              .read(notificationPreferencesProvider.notifier)
                              .setTypePreference(type, value),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionCard(
    String title,
    dynamic state,
    int messageCount,
    int errorCount,
    Color color,
  ) {
    final isConnected = (state == WebSocketConnectionState.connected) ||
                        (state == SocketConnectionState.connected);
    
    return Card(
      color: isConnected ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.error,
                  color: isConnected ? color : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isConnected ? color : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getStateText(state),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Messages: $messageCount',
                  style: const TextStyle(fontSize: 10),
                ),
                Text(
                  'Errors: $errorCount',
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed, Color color) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
      ),
    );
  }

  Widget _buildMessagesList(List<RealtimeMessage> messages) {
    if (messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No messages yet'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(message.senderId.substring(0, 1).toUpperCase()),
          ),
          title: Text(message.content),
          subtitle: Text(
            '${message.senderId} • ${_formatTime(message.timestamp)}',
          ),
          trailing: _getMessageStatusIcon(message.status),
        );
      },
    );
  }

  Widget _buildNotificationTile(RealtimeNotification notification, WidgetRef ref) {
    return Dismissible(
      key: Key(notification.id),
      onDismissed: (_) {
        ref.read(allNotificationsProvider.notifier).markAsRead(notification.id);
      },
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Icon(Icons.done, color: Colors.white),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getNotificationColor(notification.type),
          child: Icon(
            _getNotificationIcon(notification.type),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body),
            Text(
              _formatTime(notification.timestamp),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: notification.isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () {
          if (!notification.isRead) {
            ref.read(allNotificationsProvider.notifier).markAsRead(notification.id);
          }
        },
      ),
    );
  }

  String _getStateText(dynamic state) {
    if (state is WebSocketConnectionState) {
      switch (state) {
        case WebSocketConnectionState.connected:
          return 'Connected';
        case WebSocketConnectionState.connecting:
          return 'Connecting...';
        case WebSocketConnectionState.disconnected:
          return 'Disconnected';
        case WebSocketConnectionState.reconnecting:
          return 'Reconnecting...';
        case WebSocketConnectionState.error:
          return 'Error';
      }
    } else if (state is SocketConnectionState) {
      switch (state) {
        case SocketConnectionState.connected:
          return 'Connected';
        case SocketConnectionState.connecting:
          return 'Connecting...';
        case SocketConnectionState.disconnected:
          return 'Disconnected';
        case SocketConnectionState.reconnecting:
          return 'Reconnecting...';
        case SocketConnectionState.error:
          return 'Error';
      }
    }
    return 'Unknown';
  }

  Color _getPresenceColor(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return Colors.green;
      case PresenceStatus.away:
        return Colors.orange;
      case PresenceStatus.busy:
        return Colors.red;
      case PresenceStatus.offline:
        return Colors.grey;
    }
  }

  Icon _getMessageStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.schedule, color: Colors.grey, size: 16);
      case MessageStatus.sent:
        return const Icon(Icons.check, color: Colors.grey, size: 16);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, color: Colors.blue, size: 16);
      case MessageStatus.read:
        return const Icon(Icons.done_all, color: Colors.green, size: 16);
      case MessageStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 16);
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return Colors.blue;
      case NotificationType.mention:
        return Colors.purple;
      case NotificationType.assignment:
        return Colors.green;
      case NotificationType.deadline:
        return Colors.orange;
      case NotificationType.system:
        return Colors.grey;
      case NotificationType.achievement:
        return Colors.amber;
      case NotificationType.reminder:
        return Colors.teal;
      case NotificationType.alert:
        return Colors.red;
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return Icons.message;
      case NotificationType.mention:
        return Icons.alternate_email;
      case NotificationType.assignment:
        return Icons.assignment;
      case NotificationType.deadline:
        return Icons.schedule;
      case NotificationType.system:
        return Icons.info;
      case NotificationType.achievement:
        return Icons.emoji_events;
      case NotificationType.reminder:
        return Icons.notifications;
      case NotificationType.alert:
        return Icons.warning;
    }
  }

  String _getNotificationTypeName(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return 'Messages';
      case NotificationType.mention:
        return 'Mentions';
      case NotificationType.assignment:
        return 'Assignments';
      case NotificationType.deadline:
        return 'Deadlines';
      case NotificationType.system:
        return 'System';
      case NotificationType.achievement:
        return 'Achievements';
      case NotificationType.reminder:
        return 'Reminders';
      case NotificationType.alert:
        return 'Alerts';
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Test methods
  void _testWebSocket() async {
    final client = WebSocketClient.instance;
    if (client.connectionState == WebSocketConnectionState.connected) {
      client.ping(data: 'Test ping from dashboard');
      _showSnackBar('WebSocket ping sent!');
    } else {
      _showSnackBar('WebSocket not connected');
    }
  }

  void _testSocketIO() async {
    final client = SocketIOClient.instance;
    if (client.connectionState == SocketConnectionState.connected) {
      client.emit('test', {'message': 'Test event from dashboard'});
      _showSnackBar('Socket.IO event sent!');
    } else {
      _showSnackBar('Socket.IO not connected');
    }
  }

  void _sendTestMessage() async {
    final service = RealtimeMessagingService.instance;
    await service.sendMessage(
      content: 'Test message from dashboard',
      type: MessageType.text,
      priority: MessagePriority.normal,
    );
    _showSnackBar('Test message sent!');
  }

  void _sendTestNotification() async {
    final service = RealtimeNotificationService.instance;
    await service.sendNotification(
      title: 'Test Notification',
      body: 'This is a test notification from the dashboard',
      type: NotificationType.system,
      priority: NotificationPriority.normal,
    );
    _showSnackBar('Test notification sent!');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
