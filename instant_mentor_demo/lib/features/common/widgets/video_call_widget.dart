import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Conditional import to avoid flutter_webrtc on web (uses stub instead)
// ignore: uri_does_not_exist
import 'package:flutter_webrtc/flutter_webrtc.dart'
    if (dart.library.html) 'package:instant_mentor_demo/features/shared/live_session/webrtc_stub.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/websocket_provider.dart';
import '../../../core/services/websocket_service.dart';

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
  // Local video rendering
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  bool _mediaInitializing = false;
  String? _mediaErrorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCall();
    _setupCallEventListener();
    _initLocalMedia();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    try {
      _localStream?.getTracks().forEach((t) => t.stop());
      _localRenderer.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _initLocalMedia() async {
    if (_mediaInitializing) return;
    setState(() => _mediaInitializing = true);
    try {
      await _localRenderer.initialize();
      final constraints = <String, dynamic>{
        'audio': true,
        'video': _isCameraOn
            ? {
                // For web (and compatible native), provide facingMode to ensure front camera
                'facingMode': 'user',
                // Web style optional/ideal constraints
                'width': {'ideal': 640},
                'height': {'ideal': 480},
                'frameRate': {'ideal': 24},
              }
            : false,
      };
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _localRenderer.srcObject = _localStream;
      _mediaErrorMessage = null;
      // Apply initial mute state if already toggled before stream init
      if (_isMuted) {
        for (var t in _localStream!.getAudioTracks()) {
          t.enabled = false;
        }
      }
    } catch (e) {
      debugPrint('Failed to init local media: $e');
      _mediaErrorMessage = 'Camera/Mic access denied or unavailable';
    } finally {
      if (mounted) setState(() => _mediaInitializing = false);
    }
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
    setState(() => _isMuted = !_isMuted);
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
    }
  }

  void _toggleCamera() {
    setState(() => _isCameraOn = !_isCameraOn);
    // Reconfigure local tracks
    if (_localStream != null) {
      // Enable/disable existing video tracks
      for (var track in _localStream!.getVideoTracks()) {
        track.enabled = _isCameraOn;
      }
      if (_isCameraOn && _localStream!.getVideoTracks().isEmpty) {
        _initLocalMedia();
      }
    } else if (_isCameraOn) {
      _initLocalMedia();
    }
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
    final String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.read(authProvider).user;
    final userMeta = user?.userMetadata ?? {};
    final avatarUrl = (userMeta['avatar_url'] ?? userMeta['avatarUrl'] ?? '')
        .toString()
        .trim();
    final displayName =
        (userMeta['full_name'] ?? userMeta['name'] ?? 'You').toString();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme, avatarUrl, displayName),

            _buildVideoArea(avatarUrl, displayName),

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

  Widget _buildHeader(ThemeData theme, String avatarUrl, String displayName) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar or placeholder
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary,
              image: avatarUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatarUrl.isEmpty
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            widget.receiverName ?? 'Unknown',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getCallStatusText(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
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
    );
  }

  Widget _buildVideoArea(String avatarUrl, String displayName) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: _isCameraOn
            ? (_mediaInitializing
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : (_localStream != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          RTCVideoView(_localRenderer, mirror: true),
                          if (_mediaErrorMessage != null)
                            _buildMediaErrorOverlay(),
                        ],
                      )
                    : _mediaErrorMessage != null
                        ? _buildMediaErrorOverlay()
                        : _buildAvatarFallback(avatarUrl, displayName)))
            : _buildAvatarFallback(avatarUrl, displayName),
      ),
    );
  }

  Widget _buildMediaErrorOverlay() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(
              _mediaErrorMessage ?? 'Media unavailable',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _initLocalMedia();
              },
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String avatarUrl, String displayName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.grey[700],
            backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _isCameraOn ? 'Initializing camera...' : 'Camera off',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
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
