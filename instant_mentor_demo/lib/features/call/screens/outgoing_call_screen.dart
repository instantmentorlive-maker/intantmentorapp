import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/simple_call_controller.dart';
import '../models/call_state.dart';
import '../models/call_data.dart';

/// Screen displayed when making an outgoing call
class OutgoingCallScreen extends ConsumerStatefulWidget {
  const OutgoingCallScreen({super.key});

  @override
  ConsumerState<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends ConsumerState<OutgoingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();

    // Setup pulse animation for calling state
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Setup ripple animation
    _rippleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _pulseController.repeat(reverse: true);
    _rippleController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callData = ref.watch(simpleCallControllerProvider);

    // Listen to call state changes
    ref.listen<CallData?>(simpleCallControllerProvider, (previous, next) {
      if (next?.state == CallState.inCall) {
        // Navigate to active call screen
        Navigator.of(context).pushReplacementNamed('/active-call');
      } else if (next?.state == CallState.ended ||
          next?.state == CallState.rejected ||
          next?.state == CallState.failed) {
        // Call ended, go back
        Navigator.of(context).pop();
      }
    });

    if (callData == null) {
      return const Scaffold(
        body: Center(child: Text('No outgoing call')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            // Top section with recipient info
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Call status
                    Text(
                      _getCallStatusText(callData.state),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Animated recipient avatar with ripple effect
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple effect
                        AnimatedBuilder(
                          animation: _rippleAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 200 * _rippleAnimation.value,
                              height: 200 * _rippleAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(
                                    0.3 * (1 - _rippleAnimation.value),
                                  ),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        ),

                        // Main avatar
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 3,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 65,
                                  backgroundColor: Colors.grey[800],
                                  backgroundImage:
                                      callData.calleeAvatar.isNotEmpty
                                          ? NetworkImage(callData.calleeAvatar)
                                          : null,
                                  child: callData.calleeAvatar.isEmpty
                                      ? Text(
                                          callData.calleeName.isNotEmpty
                                              ? callData.calleeName[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Recipient name
                    Text(
                      callData.calleeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // Call type indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          callData.mediaState.isVideoEnabled
                              ? Icons.videocam
                              : Icons.phone,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          callData.mediaState.isVideoEnabled
                              ? 'Video call'
                              : 'Voice call',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom section with call controls
            Expanded(
              flex: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Call control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mute button
                        _CallControlButton(
                          icon: callData.mediaState.isAudioEnabled
                              ? Icons.mic
                              : Icons.mic_off,
                          isActive: callData.mediaState.isAudioEnabled,
                          onTap: () {
                            ref
                                .read(simpleCallControllerProvider.notifier)
                                .toggleAudio();
                          },
                        ),

                        // Video button (if video call)
                        if (callData.mediaState.isVideoEnabled)
                          _CallControlButton(
                            icon: callData.mediaState.isVideoEnabled
                                ? Icons.videocam
                                : Icons.videocam_off,
                            isActive: callData.mediaState.isVideoEnabled,
                            onTap: () {
                              ref
                                  .read(simpleCallControllerProvider.notifier)
                                  .toggleVideo();
                            },
                          ),

                        // Speaker button
                        _CallControlButton(
                          icon: callData.mediaState.isSpeakerOn
                              ? Icons.volume_up
                              : Icons.volume_down,
                          isActive: callData.mediaState.isSpeakerOn,
                          onTap: () {
                            // TODO: Toggle speaker
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // End call button
                    _EndCallButton(
                      onTap: () async {
                        await ref
                            .read(simpleCallControllerProvider.notifier)
                            .endCall();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // Additional actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            // TODO: Add another person
                          },
                          icon: const Icon(Icons.person_add,
                              color: Colors.white70),
                          label: const Text(
                            'Add person',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            // TODO: Send message
                          },
                          icon:
                              const Icon(Icons.message, color: Colors.white70),
                          label: const Text(
                            'Message',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCallStatusText(CallState state) {
    switch (state) {
      case CallState.calling:
        return 'Calling...';
      case CallState.ringing:
        return 'Ringing...';
      case CallState.connecting:
        return 'Connecting...';
      default:
        return 'Calling...';
    }
  }
}

/// Call control button for outgoing call
class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _CallControlButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? Colors.white.withOpacity(0.1)
              : Colors.red.withOpacity(0.2),
          border: Border.all(
            color: isActive
                ? Colors.white.withOpacity(0.3)
                : Colors.red.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.red[300],
          size: 24,
        ),
      ),
    );
  }
}

/// End call button with special styling
class _EndCallButton extends StatefulWidget {
  final VoidCallback onTap;

  const _EndCallButton({required this.onTap});

  @override
  State<_EndCallButton> createState() => _EndCallButtonState();
}

class _EndCallButtonState extends State<_EndCallButton>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.call_end,
                color: Colors.white,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }
}
