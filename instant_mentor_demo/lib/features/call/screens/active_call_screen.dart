import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Conditional import: use real flutter_webrtc except on web where we fall back to stub
// ignore: uri_does_not_exist
import 'package:flutter_webrtc/flutter_webrtc.dart'
    if (dart.library.html) 'package:instant_mentor_demo/features/shared/live_session/webrtc_stub.dart';

import '../controllers/simple_call_controller.dart';
import '../models/call_data.dart';
import '../models/call_state.dart';

/// Screen displayed during an active video/audio call
class ActiveCallScreen extends ConsumerStatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  bool _isControlsVisible = true;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initRenderers();

    // Auto-hide controls after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });

    // Auto-hide controls after 3 seconds
    if (_isControlsVisible) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isControlsVisible) {
          setState(() {
            _isControlsVisible = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final callData = ref.watch(simpleCallControllerProvider);
    final localStream = ref.watch(localStreamProvider);
    final remoteStream = ref.watch(remoteStreamProvider);

    // Listen to call state changes
    ref.listen<CallData?>(simpleCallControllerProvider, (previous, next) {
      if (next?.state == CallState.ended ||
          next?.state == CallState.failed ||
          next == null) {
        Navigator.of(context).pop();
      }
    });

    // Update video renderers when streams change
    ref.listen<AsyncValue<MediaStream?>>(localStreamProvider, (previous, next) {
      next.whenData((stream) {
        if (stream != null) {
          _localRenderer.srcObject = stream;
        }
      });
    });

    ref.listen<AsyncValue<MediaStream?>>(remoteStreamProvider,
        (previous, next) {
      next.whenData((stream) {
        if (stream != null) {
          _remoteRenderer.srcObject = stream;
        }
      });
    });

    if (callData == null) {
      return const Scaffold(
        body: Center(child: Text('No active call')),
      );
    }

    final isVideoCall = callData.mediaState.isVideoEnabled;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              // Main video area
              if (isVideoCall) ...[
                // Remote video (full screen)
                Positioned.fill(
                  child: remoteStream.when(
                    data: (stream) => stream != null
                        ? RTCVideoView(_remoteRenderer)
                        : _buildNoVideoPlaceholder(
                            callData.getOtherParticipantName('')),
                    loading: () => _buildConnectingPlaceholder(),
                    error: (_, __) => _buildNoVideoPlaceholder(
                        callData.getOtherParticipantName('')),
                  ),
                ),

                // Local video (picture-in-picture)
                Positioned(
                  top: 60,
                  right: 20,
                  child: Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: localStream.when(
                      data: (stream) => stream != null
                          ? RTCVideoView(_localRenderer, mirror: true)
                          : _buildLocalVideoPlaceholder(),
                      loading: () => _buildLocalVideoPlaceholder(),
                      error: (_, __) => _buildLocalVideoPlaceholder(),
                    ),
                  ),
                ),
              ] else ...[
                // Audio call UI
                _buildAudioCallUI(callData),
              ],

              // Top overlay with call info
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                top: _isControlsVisible ? 0 : -100,
                left: 0,
                right: 0,
                child: _buildTopOverlay(callData),
              ),

              // Bottom overlay with call controls
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                bottom: _isControlsVisible ? 0 : -150,
                left: 0,
                right: 0,
                child: _buildBottomControls(callData),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoVideoPlaceholder(String name) {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[700],
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Camera is off',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectingPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Connecting...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalVideoPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(
          Icons.videocam_off,
          color: Colors.white70,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildAudioCallUI(CallData callData) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue[900]!,
            Colors.purple[900]!,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Participant avatar
          CircleAvatar(
            radius: 80,
            backgroundColor: Colors.white.withOpacity(0.1),
            backgroundImage: callData.getOtherParticipantAvatar('').isNotEmpty
                ? NetworkImage(callData.getOtherParticipantAvatar(''))
                : null,
            child: callData.getOtherParticipantAvatar('').isEmpty
                ? Text(
                    callData.getOtherParticipantName('').isNotEmpty
                        ? callData.getOtherParticipantName('')[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 24),

          // Participant name
          Text(
            callData.getOtherParticipantName(''),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          // Call duration
          if (callData.duration != null)
            Text(
              _formatDuration(callData.duration!),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopOverlay(CallData callData) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Call info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  callData.getOtherParticipantName(''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (callData.duration != null)
                  Text(
                    _formatDuration(callData.duration!),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),

          // Minimize button
          IconButton(
            onPressed: () {
              // TODO: Minimize to picture-in-picture
            },
            icon: const Icon(
              Icons.picture_in_picture_alt,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(CallData callData) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          _CallControlButton(
            icon:
                callData.mediaState.isAudioEnabled ? Icons.mic : Icons.mic_off,
            isActive: callData.mediaState.isAudioEnabled,
            backgroundColor: callData.mediaState.isAudioEnabled
                ? Colors.white.withOpacity(0.2)
                : Colors.red,
            onTap: () {
              ref.read(simpleCallControllerProvider.notifier).toggleAudio();
            },
          ),

          // Video button
          _CallControlButton(
            icon: callData.mediaState.isVideoEnabled
                ? Icons.videocam
                : Icons.videocam_off,
            isActive: callData.mediaState.isVideoEnabled,
            backgroundColor: callData.mediaState.isVideoEnabled
                ? Colors.white.withOpacity(0.2)
                : Colors.red,
            onTap: () {
              ref.read(simpleCallControllerProvider.notifier).toggleVideo();
            },
          ),

          // Speaker button
          _CallControlButton(
            icon: callData.mediaState.isSpeakerOn
                ? Icons.volume_up
                : Icons.volume_down,
            isActive: callData.mediaState.isSpeakerOn,
            backgroundColor: Colors.white.withOpacity(0.2),
            onTap: () {
              // TODO: Toggle speaker
            },
          ),

          // Camera switch button (only show for video calls)
          if (callData.mediaState.isVideoEnabled)
            _CallControlButton(
              icon: Icons.flip_camera_ios,
              isActive: true,
              backgroundColor: Colors.white.withOpacity(0.2),
              onTap: () {
                // TODO: Switch camera
              },
            ),

          // End call button
          _CallControlButton(
            icon: Icons.call_end,
            isActive: false,
            backgroundColor: Colors.red,
            onTap: () async {
              await ref.read(simpleCallControllerProvider.notifier).endCall();
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}

/// Call control button for active call screen
class _CallControlButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _CallControlButton({
    required this.icon,
    required this.isActive,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  State<_CallControlButton> createState() => _CallControlButtonState();
}

class _CallControlButtonState extends State<_CallControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.backgroundColor,
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }
}
