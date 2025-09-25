import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/simple_call_controller.dart';

/// Screen displayed when receiving an incoming call
class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Setup pulse animation for incoming call
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callData = ref.watch(simpleCallControllerProvider);

    if (callData == null) {
      return const Scaffold(
        body: Center(child: Text('No incoming call')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            // Top section with caller info
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Incoming call',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Animated caller avatar
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
                              backgroundImage: callData.callerAvatar.isNotEmpty
                                  ? NetworkImage(callData.callerAvatar)
                                  : null,
                              child: callData.callerAvatar.isEmpty
                                  ? Text(
                                      callData.callerName.isNotEmpty
                                          ? callData.callerName[0].toUpperCase()
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

                    const SizedBox(height: 24),

                    // Caller name
                    Text(
                      callData.callerName,
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

            // Bottom section with call actions
            Expanded(
              flex: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Quick action buttons (if video call)
                    if (callData.mediaState.isVideoEnabled) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _QuickActionButton(
                            icon: Icons.mic_off,
                            label: 'Mute',
                            onTap: () {
                              // TODO: Toggle microphone before accepting
                            },
                          ),
                          _QuickActionButton(
                            icon: Icons.videocam_off,
                            label: 'Video off',
                            onTap: () {
                              // TODO: Toggle video before accepting
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],

                    // Main action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Decline button
                        _CallActionButton(
                          icon: Icons.call_end,
                          backgroundColor: Colors.red,
                          onTap: () async {
                            await ref
                                .read(simpleCallControllerProvider.notifier)
                                .rejectCall();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),

                        // Accept button
                        _CallActionButton(
                          icon: Icons.call,
                          backgroundColor: Colors.green,
                          onTap: () async {
                            await ref
                                .read(simpleCallControllerProvider.notifier)
                                .acceptCall();
                            if (context.mounted) {
                              Navigator.of(context)
                                  .pushReplacementNamed('/active-call');
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Alternative actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            // TODO: Send message instead
                          },
                          icon:
                              const Icon(Icons.message, color: Colors.white70),
                          label: const Text(
                            'Message',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            // TODO: Remind me later
                          },
                          icon:
                              const Icon(Icons.schedule, color: Colors.white70),
                          label: const Text(
                            'Remind me',
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
}

/// Quick action button for call preparation
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Main call action button (accept/decline)
class _CallActionButton extends StatefulWidget {
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  State<_CallActionButton> createState() => _CallActionButtonState();
}

class _CallActionButtonState extends State<_CallActionButton>
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
                color: widget.backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: widget.backgroundColor.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
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
