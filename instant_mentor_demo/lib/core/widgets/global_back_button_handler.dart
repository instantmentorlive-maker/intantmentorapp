import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/video_call_provider.dart';

/// Global back button handler that preserves video calls
/// This widget should wrap the entire app to handle back button presses
/// throughout the application and ensure video calls are minimized instead of ended
class GlobalBackButtonHandler extends ConsumerWidget {
  final Widget child;

  const GlobalBackButtonHandler({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoCallState = ref.watch(videoCallProvider);
    final videoCallNotifier = ref.read(videoCallProvider.notifier);

    return PopScope(
      canPop: true, // Always allow navigation - don't block back button
      onPopInvoked: (didPop) {
        // Only minimize the call if we're in a video call screen and call is not already minimized
        if (didPop && videoCallState.isActive && !videoCallState.isMinimized) {
          // Check if we're currently on a video call screen
          final currentRoute = ModalRoute.of(context)?.settings.name;
          final isVideoCallScreen =
              currentRoute?.contains('/session/') ?? false;

          if (isVideoCallScreen) {
            // If we're leaving a video call screen, minimize the call instead of ending it
            videoCallNotifier.minimizeCall();

            debugPrint(
                'GlobalBackButtonHandler: Video call minimized due to back navigation from $currentRoute');

            // Show a snackbar to inform the user
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Video call with ${videoCallState.mentorName ?? "mentor"} minimized'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.blue[800],
                action: SnackBarAction(
                  label: 'Restore',
                  textColor: Colors.white,
                  onPressed: () {
                    videoCallNotifier.maximizeCall();
                    // Navigate back to the session
                    final sessionId =
                        videoCallState.sessionId ?? 'demo_session_1';
                    context.go('/session/$sessionId');
                  },
                ),
              ),
            );
          }
        }
      },
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            child,
            // Show minimized call overlay if call is active and minimized
            if (videoCallState.isActive && videoCallState.isMinimized)
              _buildMinimizedCallOverlay(
                  context, videoCallState, videoCallNotifier),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimizedCallOverlay(
    BuildContext context,
    VideoCallState callState,
    VideoCallNotifier notifier,
  ) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          // Make the entire overlay clickable to restore the call
          onTap: () {
            final sessionId = callState.sessionId ?? 'demo_session_1';
            debugPrint(
                'GlobalBackButtonHandler: Restoring call, navigating to /session/$sessionId');

            // Maximize the call first
            notifier.maximizeCall();

            // Navigate to the session screen after a brief delay to ensure state updates
            Future.microtask(() => context.go('/session/$sessionId'));
          },
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: Row(
              children: [
                // Video thumbnail placeholder
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.videocam,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Call info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Video Call',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        callState.mentorName ?? 'Mentor',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to restore',
                        style: TextStyle(
                          color: Colors.blue[300],
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Restore button
                    GestureDetector(
                      onTap: () {
                        final sessionId =
                            callState.sessionId ?? 'demo_session_1';
                        debugPrint(
                            'GlobalBackButtonHandler: Restore button clicked, navigating to /session/$sessionId');

                        // Maximize the call first
                        notifier.maximizeCall();

                        // Navigate to the session screen after a brief delay to ensure state updates
                        Future.microtask(
                            () => context.go('/session/$sessionId'));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[700],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // End call button
                    GestureDetector(
                      onTap: () {
                        notifier.endCall();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
