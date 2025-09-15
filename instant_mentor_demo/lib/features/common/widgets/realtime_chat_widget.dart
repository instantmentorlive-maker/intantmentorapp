import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../core/services/websocket_service.dart';
import '../../../core/providers/websocket_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/chat_providers.dart';
import '../../../core/providers/realtime_chat_provider.dart'
    hide typingIndicatorProvider;
import '../../../core/models/chat.dart';

class RealTimeChatWidget extends ConsumerStatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? receiverAvatar;

  const RealTimeChatWidget({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
  });

  @override
  ConsumerState<RealTimeChatWidget> createState() => _RealTimeChatWidgetState();
}

class _RealTimeChatWidgetState extends ConsumerState<RealTimeChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _showTypingIndicator = false;

  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _setupMessageListener();
    _loadInitialMessages();
  }

  void _loadInitialMessages() async {
    try {
      final chatService = ref.read(chatServiceProvider);
      final messages = await chatService.fetchMessages(widget.receiverId);
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Failed to load initial messages: $e');
      // Continue without initial messages - they'll show as empty
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _setupMessageListener() {
    // Listen to WebSocket messages
    ref.listen(webSocketMessageProvider, (previous, next) {
      next.whenData((message) {
        if (message.senderId == widget.receiverId ||
            message.receiverId == widget.receiverId) {
          _handleIncomingMessage(message);
        }
      });
    });

    // Listen to typing indicators
    ref.listen(typingIndicatorProvider(widget.receiverId), (previous, next) {
      next.whenData((isTyping) {
        // Use provider instead of setState
        ref
            .read(realtimeChatProvider(widget.receiverId).notifier)
            .setTypingIndicator(isTyping);
      });
    });
  }

  void _handleIncomingMessage(WebSocketMessage wsMessage) {
    if (wsMessage.event == WebSocketEvent.messageReceived) {
      final chatMessage = ChatMessage(
        id: wsMessage.id,
        chatId: widget.receiverId, // Use receiverId as chatId
        content: wsMessage.data['content'] ?? '',
        senderId: wsMessage.senderId ?? '',
        senderName: wsMessage.data['senderName'] ?? 'Unknown',
        type: MessageType.text, // Default to text
        timestamp: wsMessage.timestamp,
      );

      // Use provider instead of setState
      ref
          .read(realtimeChatProvider(widget.receiverId).notifier)
          .addMessage(chatMessage);
      _scrollToBottom();
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final content = _messageController.text.trim();
    final currentUser = ref.read(authProvider).user;

    if (currentUser == null) return;

    // Add message to local list immediately
    final localMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: widget.receiverId, // Use receiverId as chatId
      content: content,
      senderId: currentUser.id,
      senderName: currentUser.email ?? 'User',
      type: MessageType.text,
      timestamp: DateTime.now(),
      isSent: false, // Initially not sent
    );

    setState(() {
      _messages.add(localMessage);
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Send through WebSocket first (for real-time)
      final webSocketManager = ref.read(webSocketManagerProvider);
      await webSocketManager.sendChatMessage(
        receiverId: widget.receiverId,
        content: content,
        messageType: 'text',
      );

      // Also save to persistent chat service
      final chatService = ref.read(chatServiceProvider);
      try {
        await chatService.sendTextMessage(
          chatId: widget.receiverId,
          senderId: currentUser.id,
          senderName: currentUser.email ?? 'User',
          content: content,
        );
      } catch (e) {
        debugPrint('Failed to save to chat service (using mock): $e');
        // Message still shows as sent via WebSocket
      }

      // Update message status to sent
      final messageIndex = _messages.indexWhere((m) => m.id == localMessage.id);
      if (messageIndex != -1) {
        setState(() {
          _messages[messageIndex] = localMessage.copyWith(isSent: true);
        });
      }
    } catch (e) {
      debugPrint('Error sending message: $e');

      // Update message status to failed
      final messageIndex = _messages.indexWhere((m) => m.id == localMessage.id);
      if (messageIndex != -1) {
        setState(() {
          _messages[messageIndex] = localMessage.copyWith(isSent: false);
        });
      }
    }
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _sendTypingIndicator(true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _sendTypingIndicator(false);
      }
    });
  }

  void _sendTypingIndicator(bool isTyping) async {
    try {
      final webSocketManager = ref.read(webSocketManagerProvider);
      await webSocketManager.sendTypingIndicator(
        receiverId: widget.receiverId,
        isTyping: isTyping,
      );
    } catch (e) {
      debugPrint('Error sending typing indicator: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _initiateVideoCall() async {
    try {
      final webSocketManager = ref.read(webSocketManagerProvider);
      await webSocketManager.initiateVideoCall(
        receiverId: widget.receiverId,
        callData: {
          'callerName':
              ref.read(authProvider).user?.userMetadata?['full_name'] ??
                  'Unknown',
          'callId': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video call initiated')),
        );
      }
    } catch (e) {
      debugPrint('Error initiating video call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initiate call: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connectionState = ref.watch(webSocketConnectionStateProvider);

    return Column(
      children: [
        // Header with connection status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom:
                  BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
            ),
          ),
          child: Row(
            children: [
              // User avatar
              CircleAvatar(
                radius: 20,
                backgroundImage: widget.receiverAvatar != null
                    ? NetworkImage(widget.receiverAvatar!)
                    : null,
                child: widget.receiverAvatar == null
                    ? Text(widget.receiverName.isNotEmpty
                        ? widget.receiverName[0].toUpperCase()
                        : '?')
                    : null,
              ),
              const SizedBox(width: 12),

              // User name and status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.receiverName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    connectionState.when(
                      data: (state) {
                        String statusText;
                        Color statusColor;

                        switch (state) {
                          case WebSocketConnectionState.connected:
                            statusText = 'Online';
                            statusColor = Colors.green;
                            break;
                          case WebSocketConnectionState.connecting:
                          case WebSocketConnectionState.reconnecting:
                            statusText = 'Connecting...';
                            statusColor = Colors.orange;
                            break;
                          default:
                            statusText = 'Offline';
                            statusColor = Colors.grey;
                        }

                        return Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: statusColor,
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                  ],
                ),
              ),

              // Video call button
              IconButton(
                onPressed: _initiateVideoCall,
                icon: const Icon(Icons.videocam),
                tooltip: 'Start video call',
              ),
            ],
          ),
        ),

        // Messages list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_showTypingIndicator ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _showTypingIndicator) {
                return _buildTypingIndicator();
              }

              final message = _messages[index];
              return _buildMessageBubble(message);
            },
          ),
        ),

        // Message input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top:
                  BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  onChanged: _onTextChanged,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: _sendMessage,
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final theme = Theme.of(context);
    final currentUser = ref.read(authProvider).user;
    final isFromCurrentUser =
        currentUser != null && message.senderId == currentUser.id;

    return Align(
      alignment:
          isFromCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: isFromCurrentUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isFromCurrentUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight:
                      isFromCurrentUser ? const Radius.circular(4) : null,
                  bottomLeft:
                      !isFromCurrentUser ? const Radius.circular(4) : null,
                ),
              ),
              child: Text(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isFromCurrentUser
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            // Message status and timestamp
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  if (isFromCurrentUser) ...[
                    const SizedBox(width: 4),
                    _buildMessageStatusIcon(message.isSent),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomLeft: const Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.receiverName} is typing',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 20,
              height: 10,
              child: Row(
                children: List.generate(3, (index) {
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageStatusIcon(bool isSent) {
    if (isSent) {
      return Icon(
        Icons.check,
        size: 12,
        color: Colors.grey[600],
      );
    } else {
      return Icon(
        Icons.access_time,
        size: 12,
        color: Colors.grey[600],
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    } else if (diff.inDays < 1) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}
