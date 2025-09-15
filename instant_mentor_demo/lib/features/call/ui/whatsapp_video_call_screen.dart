import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../controller/call_controller.dart';
import '../models/participant.dart';

/// WhatsApp-style video call screen
class WhatsAppVideoCallScreen extends ConsumerWidget {
  final String userId;
  final String displayName;
  final String role;
  final String baseUrl;
  final String? initialPeerId;

  const WhatsAppVideoCallScreen({
    super.key,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.baseUrl,
    this.initialPeerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callControllerProvider((
      userId: userId,
      displayName: displayName,
      role: role,
      baseUrl: baseUrl
    )));
    final controller = ref.read(callControllerProvider((
      userId: userId,
      displayName: displayName,
      role: role,
      baseUrl: baseUrl
    )).notifier);

    // Auto-initiate if provided and not in call yet
    if (initialPeerId != null &&
        state.activeCallId == null &&
        !state.connecting &&
        !state.inCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.initiateCall(receiverId: initialPeerId!);
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video area
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: state.connecting
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Connecting...',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ],
                      ),
                    )
                  : state.inCall
                      ? _buildVideoGrid(context, state, controller)
                      : state.isIncomingCall
                          ? _buildIncomingCall(context, state, controller)
                          : _buildOutgoingCall(context, state, controller),
            ),
          ),

          // Call controls overlay
          if (state.inCall)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: _buildCallControls(context, controller, state),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid(
      BuildContext context, CallState state, CallController controller) {
    return Stack(
      children: [
        // Remote video (full screen)
        if (controller.remoteRenderer?.srcObject != null)
          RTCVideoView(controller.remoteRenderer!)
        else
          Container(
            color: Colors.grey.shade800,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, size: 100, color: Colors.white54),
                  SizedBox(height: 16),
                  Text(
                    'Waiting for video...',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

        // Local video (small overlay)
        Positioned(
          top: 50,
          right: 20,
          child: Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: controller.localRenderer?.srcObject != null
                  ? RTCVideoView(controller.localRenderer!, mirror: true)
                  : Container(
                      color: Colors.grey.shade700,
                      child: const Icon(
                        Icons.person,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutgoingCall(
      BuildContext context, CallState state, CallController controller) {
    final receiver = state.participants.firstWhere(
      (p) => !p.isLocal,
      orElse: () =>
          Participant(id: 'unknown', displayName: 'Calling...', isLocal: false),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Receiver avatar
        CircleAvatar(
          radius: 80,
          backgroundColor: Colors.grey.shade700,
          child: Text(
            receiver.displayName.isNotEmpty
                ? receiver.displayName[0].toUpperCase()
                : 'C',
            style: const TextStyle(fontSize: 60, color: Colors.white),
          ),
        ),
        const SizedBox(height: 32),

        // Receiver name
        Text(
          receiver.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        // Call status
        const Text(
          'Calling...',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 40),

        // Loading indicator
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 40),

        // Only end call button for outgoing calls
        GestureDetector(
          onTap: () => controller.endCall(reason: 'cancelled'),
          child: Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.call_end,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomingCall(
      BuildContext context, CallState state, CallController controller) {
    final caller = state.participants.firstWhere(
      (p) => !p.isLocal,
      orElse: () =>
          Participant(id: 'unknown', displayName: 'Caller', isLocal: false),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Caller avatar
        CircleAvatar(
          radius: 80,
          backgroundColor: Colors.grey.shade700,
          child: Text(
            caller.displayName.isNotEmpty
                ? caller.displayName[0].toUpperCase()
                : 'C',
            style: const TextStyle(fontSize: 60, color: Colors.white),
          ),
        ),
        const SizedBox(height: 32),

        // Caller name
        Text(
          caller.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        // Call status
        const Text(
          'Incoming video call',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 80),

        // Call action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Decline button
            GestureDetector(
              onTap: () => controller.rejectCall(reason: 'declined'),
              child: Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.call_end,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),

            // Accept button
            GestureDetector(
              onTap: controller.acceptCall,
              child: Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.call,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCallControls(
      BuildContext context, CallController controller, CallState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          GestureDetector(
            onTap: controller.toggleMic,
            child: Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: state.micEnabled ? Colors.white24 : Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(
                state.micEnabled ? Icons.mic : Icons.mic_off,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),

          // End call button
          GestureDetector(
            onTap: () => controller.endCall(reason: 'user_ended'),
            child: Container(
              width: 55,
              height: 55,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.call_end,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),

          // Camera button
          GestureDetector(
            onTap: controller.toggleCamera,
            child: Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: state.cameraEnabled ? Colors.white24 : Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(
                state.cameraEnabled ? Icons.videocam : Icons.videocam_off,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
