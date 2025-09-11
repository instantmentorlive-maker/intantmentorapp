import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../core/services/websocket_service.dart';
import '../../../core/providers/websocket_provider.dart';
import '../../../core/providers/auth_provider.dart';

class VideoCallWidget extends ConsumerStatefulWidget {
  final String? callId;
  final String? receiverId;
  final String? receiverName;
  final bool isIncoming;

  const VideoCallWidget({
    super.key,
    this.callId,
    this.receiverId,
    this.receiverName,
    this.isIncoming = false,
  });

  @override
  ConsumerState<VideoCallWidget> createState() => _VideoCallWidgetState();
}

class _VideoCallWidgetState extends ConsumerState<VideoCallWidget> {
  CallState _callState = CallState.idle;
  bool _isMuted = false;
  bool _isCameraOn = true;
  bool _isSpeakerOn = false;
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeCall();
    _setupCallEventListener();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  void _initializeCall() {
    if (widget.isIncoming) {
      setState(() {
        _callState = CallState.incoming;
      });
    } else {
      setState(() {
        _callState = CallState.outgoing;
      });
      _startOutgoingCall();
    }
  }

  void _setupCallEventListener() {
    ref.listen(callEventsProvider, (previous, next) {
      next.whenData((message) {
        if (message.data['callId'] == widget.callId) {
          _handleCallEvent(message);
        }
      });
    });
  }

  void _handleCallEvent(WebSocketMessage message) {
    switch (message.event) {
      case WebSocketEvent.callAccepted:
        setState(() {
          _callState = CallState.connected;
        });
        _startCallTimer();
        break;
      case WebSocketEvent.callRejected:
        setState(() {
          _callState = CallState.rejected;
        });
        _showCallEndedDialog('Call was rejected');
        break;
      case WebSocketEvent.callEnded:
        setState(() {
          _callState = CallState.ended;
        });
        _endCall();
        break;
      case WebSocketEvent.callRinging:
        setState(() {
          _callState = CallState.ringing;
        });
        break;
      default:
        break;
    }
  }

  void _startOutgoingCall() async {
    try {
      final webSocketManager = ref.read(webSocketManagerProvider);
      await webSocketManager.initiateVideoCall(
        receiverId: widget.receiverId!,
        callData: {
          'callId': widget.callId,
          'callerName':
              ref.read(authProvider).user?.userMetadata?['full_name'] ??
                  'Unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      setState(() {
        _callState = CallState.ringing;
      });
    } catch (e) {
      debugPrint('Error starting call: $e');
      setState(() {
        _callState = CallState.failed;
      });
    }
  }

  void _acceptCall() async {
    try {
      final webSocketManager = ref.read(webSocketManagerProvider);
      await webSocketManager.webSocketService.sendMessage(
        WebSocketMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          event: WebSocketEvent.callAccepted,
          data: {
            'callId': widget.callId,
            'timestamp': DateTime.now().toIso8601String(),
          },
          senderId: ref.read(authProvider).user?.id,
          receiverId: widget.receiverId,
        ),
      );

      setState(() {
        _callState = CallState.connected;
      });
      _startCallTimer();
    } catch (e) {
      debugPrint('Error accepting call: $e');
    }
  }

  void _rejectCall() async {
    try {
      final webSocketManager = ref.read(webSocketManagerProvider);
      await webSocketManager.webSocketService.sendMessage(
        WebSocketMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          event: WebSocketEvent.callRejected,
          data: {
            'callId': widget.callId,
            'timestamp': DateTime.now().toIso8601String(),
          },
          senderId: ref.read(authProvider).user?.id,
          receiverId: widget.receiverId,
        ),
      );

      setState(() {
        _callState = CallState.rejected;
      });
      _endCall();
    } catch (e) {
      debugPrint('Error rejecting call: $e');
    }
  }

  void _endCall() async {
    try {
      final webSocketManager = ref.read(webSocketManagerProvider);
      await webSocketManager.webSocketService.sendMessage(
        WebSocketMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          event: WebSocketEvent.callEnded,
          data: {
            'callId': widget.callId,
            'duration': _callDuration.inSeconds,
            'timestamp': DateTime.now().toIso8601String(),
          },
          senderId: ref.read(authProvider).user?.id,
          receiverId: widget.receiverId,
        ),
      );
    } catch (e) {
      debugPrint('Error ending call: $e');
    }

    _callTimer?.cancel();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration = Duration(seconds: _callDuration.inSeconds + 1);
      });
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    // TODO: Implement actual mute functionality with Agora
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOn = !_isCameraOn;
    });
    // TODO: Implement actual camera toggle with Agora
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    // TODO: Implement actual speaker toggle with Agora
  }

  void _showCallEndedDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Call Ended'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header with call info
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Receiver avatar
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary,
                    ),
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Receiver name
                  Text(
                    widget.receiverName ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Call status
                  Text(
                    _getCallStatusText(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),

                  // Call duration (only when connected)
                  if (_callState == CallState.connected) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Video area (placeholder)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam,
                        size: 80,
                        color: Colors.white54,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Video will appear here',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Call controls
            Container(
              padding: const EdgeInsets.all(20),
              child: _buildCallControls(),
            ),
          ],
        ),
      ),
    );
  }

  String _getCallStatusText() {
    switch (_callState) {
      case CallState.idle:
        return 'Preparing call...';
      case CallState.outgoing:
      case CallState.ringing:
        return 'Calling...';
      case CallState.incoming:
        return 'Incoming call';
      case CallState.connected:
        return 'Connected';
      case CallState.ended:
        return 'Call ended';
      case CallState.rejected:
        return 'Call rejected';
      case CallState.failed:
        return 'Call failed';
    }
  }

  Widget _buildCallControls() {
    if (_callState == CallState.incoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reject call
          FloatingActionButton(
            onPressed: _rejectCall,
            backgroundColor: Colors.red,
            heroTag: 'reject',
            child: const Icon(Icons.call_end, color: Colors.white),
          ),

          // Accept call
          FloatingActionButton(
            onPressed: _acceptCall,
            backgroundColor: Colors.green,
            heroTag: 'accept',
            child: const Icon(Icons.call, color: Colors.white),
          ),
        ],
      );
    }

    if (_callState == CallState.connected) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          FloatingActionButton(
            onPressed: _toggleMute,
            backgroundColor: _isMuted ? Colors.red : Colors.grey[700],
            heroTag: 'mute',
            child: Icon(
              _isMuted ? Icons.mic_off : Icons.mic,
              color: Colors.white,
            ),
          ),

          // Camera button
          FloatingActionButton(
            onPressed: _toggleCamera,
            backgroundColor: _isCameraOn ? Colors.grey[700] : Colors.red,
            heroTag: 'camera',
            child: Icon(
              _isCameraOn ? Icons.videocam : Icons.videocam_off,
              color: Colors.white,
            ),
          ),

          // Speaker button
          FloatingActionButton(
            onPressed: _toggleSpeaker,
            backgroundColor: _isSpeakerOn ? Colors.blue : Colors.grey[700],
            heroTag: 'speaker',
            child: Icon(
              _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
              color: Colors.white,
            ),
          ),

          // End call button
          FloatingActionButton(
            onPressed: _endCall,
            backgroundColor: Colors.red,
            heroTag: 'end',
            child: const Icon(Icons.call_end, color: Colors.white),
          ),
        ],
      );
    }

    // Default state (outgoing, ringing, etc.)
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FloatingActionButton(
          onPressed: _endCall,
          backgroundColor: Colors.red,
          heroTag: 'end',
          child: const Icon(Icons.call_end, color: Colors.white),
        ),
      ],
    );
  }
}

enum CallState {
  idle,
  outgoing,
  incoming,
  ringing,
  connected,
  ended,
  rejected,
  failed,
}

// Incoming call overlay widget
class IncomingCallOverlay extends ConsumerWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallOverlay({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.call,
              size: 60,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            const Text(
              'Incoming Call',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Reject button
                FloatingActionButton(
                  onPressed: onReject,
                  backgroundColor: Colors.red,
                  heroTag: 'reject_overlay',
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),

                // Accept button
                FloatingActionButton(
                  onPressed: onAccept,
                  backgroundColor: Colors.green,
                  heroTag: 'accept_overlay',
                  child: const Icon(Icons.call, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
