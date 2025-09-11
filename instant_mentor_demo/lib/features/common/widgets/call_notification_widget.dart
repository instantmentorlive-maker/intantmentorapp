import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/providers/auth_provider.dart';

/// Provider for WebSocket service
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService.instance;
});

/// Provider for WebSocket messages
final webSocketMessageProvider = StreamProvider<WebSocketMessage>((ref) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  return webSocketService.messageStream;
});

/// Widget to handle incoming call notifications and actions
class CallNotificationWidget extends ConsumerStatefulWidget {
  const CallNotificationWidget({super.key});

  @override
  ConsumerState<CallNotificationWidget> createState() =>
      _CallNotificationWidgetState();
}

class _CallNotificationWidgetState extends ConsumerState<CallNotificationWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  WebSocketMessage? _currentCall;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to WebSocket messages for call events
    ref.listen<AsyncValue<WebSocketMessage>>(webSocketMessageProvider,
        (previous, next) {
      next.when(
        data: (message) {
          if (message.event == WebSocketEvent.callInitiated &&
              message.receiverId == ref.read(authProvider).user?.id) {
            _showIncomingCall(message);
          } else if (message.event == WebSocketEvent.callAccepted ||
              message.event == WebSocketEvent.callRejected ||
              message.event == WebSocketEvent.callEnded) {
            _handleCallResponse(message);
          }
        },
        loading: () {},
        error: (error, stack) {},
      );
    });

    return _currentCall != null
        ? _buildCallNotification()
        : const SizedBox.shrink();
  }

  Widget _buildCallNotification() {
    final call = _currentCall!;
    final callerName = call.data['callerName'] ?? 'Unknown Caller';
    final callType = call.data['callType'] ?? 'video';

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Caller Info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor:
                          Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      child: Icon(
                        callType == 'video' ? Icons.videocam : Icons.phone,
                        color: Theme.of(context).primaryColor,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Incoming ${callType.toUpperCase()} Call',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          callerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject Button
                  GestureDetector(
                    onTap: () => _rejectCall(),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  // Accept Button
                  GestureDetector(
                    onTap: () => _acceptCall(),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        callType == 'video' ? Icons.videocam : Icons.phone,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIncomingCall(WebSocketMessage message) {
    setState(() {
      _currentCall = message;
    });
    _animationController.forward();

    // Auto-dismiss after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (_currentCall?.id == message.id) {
        _rejectCall(autoReject: true);
      }
    });
  }

  void _acceptCall() async {
    if (_currentCall == null) return;

    final webSocketService = ref.read(webSocketServiceProvider);

    try {
      await webSocketService.acceptCall(
        callId: _currentCall!.id,
        callerId: _currentCall!.senderId!,
        callData: {
          'acceptedAt': DateTime.now().toIso8601String(),
          'userId': ref.read(authProvider).user?.id,
        },
      );

      _dismissCall();

      // Navigate to call screen or show call interface
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Call accepted! Connecting...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to accept call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to accept call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _rejectCall({bool autoReject = false}) async {
    if (_currentCall == null) return;

    final webSocketService = ref.read(webSocketServiceProvider);

    try {
      await webSocketService.rejectCall(
        callId: _currentCall!.id,
        callerId: _currentCall!.senderId!,
        reason: autoReject ? 'No answer' : 'Call declined',
        callData: {
          'rejectedAt': DateTime.now().toIso8601String(),
          'userId': ref.read(authProvider).user?.id,
          'autoReject': autoReject,
        },
      );

      _dismissCall();

      if (mounted && !autoReject) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📞 Call declined'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to reject call: $e');
    }
  }

  void _handleCallResponse(WebSocketMessage message) {
    if (_currentCall?.id == message.id) {
      _dismissCall();

      String responseText = '';
      Color backgroundColor = Colors.grey;

      switch (message.event) {
        case WebSocketEvent.callAccepted:
          responseText =
              '✅ Call accepted by ${message.data['userName'] ?? 'user'}';
          backgroundColor = Colors.green;
          break;
        case WebSocketEvent.callRejected:
          responseText =
              '❌ Call rejected: ${message.data['reason'] ?? 'No reason'}';
          backgroundColor = Colors.red;
          break;
        case WebSocketEvent.callEnded:
          responseText = '📞 Call ended';
          backgroundColor = Colors.orange;
          break;
        default:
          return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseText),
            backgroundColor: backgroundColor,
          ),
        );
      }
    }
  }

  void _dismissCall() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentCall = null;
        });
      }
    });
  }
}
