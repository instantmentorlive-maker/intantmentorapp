import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../call/controller/call_controller.dart';
import '../models/participant.dart';
import 'stats_sheet.dart';

/// Generic high-level call screen driven by CallController state.
/// For now it displays placeholders for participant video (WebRTC wiring later).
class CallScreen extends ConsumerWidget {
  final String userId;
  final String displayName;
  final String role; // 'student' | 'mentor'
  final String baseUrl; // signaling server base URL
  final String? initialPeerId; // optional direct peer to call automatically

  const CallScreen({
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
      appBar: AppBar(
        title: Text(state.inCall
            ? 'In Call'
            : state.activeCallId != null
                ? 'Incoming Call'
                : 'Start Call'),
        actions: [
          if (state.error != null)
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.error, color: Colors.redAccent),
              tooltip: state.error,
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBody(context, state, controller),
      ),
      floatingActionButton: kDebugMode && state.inCall
          ? FloatingActionButton(
              tooltip: 'Stats',
              child: const Icon(Icons.analytics),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: false,
                  backgroundColor: Colors.grey.shade900,
                  builder: (_) => CallStatsSheet(controller: controller),
                );
              },
            )
          : null,
    );
  }

  Widget _buildBody(
      BuildContext context, CallState state, CallController controller) {
    if (state.connecting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.activeCallId == null && !state.inCall) {
      return _buildDialer(context, controller, state.error);
    }

    if (!state.inCall && state.activeCallId != null) {
      return _buildIncoming(context, state, controller);
    }

    return _buildInCall(context, state, controller);
  }

  Widget _buildDialer(
      BuildContext context, CallController controller, String? error) {
    final peerController = TextEditingController();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Connection Issue',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(error,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            onPressed: controller.retrySignaling,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black54,
                                foregroundColor: Colors.white),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Text('Start a Call',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: peerController,
            decoration: const InputDecoration(
              labelText: 'Peer User ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.call),
              label: const Text('Call'),
              onPressed: () {
                if (peerController.text.trim().isNotEmpty) {
                  controller.initiateCall(
                      receiverId: peerController.text.trim());
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncoming(
      BuildContext context, CallState state, CallController controller) {
    final caller = state.participants.firstWhere((p) => !p.isLocal,
        orElse: () =>
            Participant(id: 'unknown', displayName: 'Caller', isLocal: false));
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                  radius: 36, child: Text(_initials(caller.displayName))),
              const SizedBox(height: 16),
              Text('${caller.displayName} is calling...',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: controller.acceptCall,
                    icon: const Icon(Icons.call),
                    label: const Text('Accept'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => controller.rejectCall(reason: 'declined'),
                    icon: const Icon(Icons.call_end, color: Colors.red),
                    label: const Text('Decline'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInCall(
      BuildContext context, CallState state, CallController controller) {
    final participants = state.participants;
    final waitingForRemote = participants.any((p) => !p.isLocal) &&
        (controller.remoteRenderer == null ||
            controller.remoteRenderer?.srcObject == null);
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: participants.length <= 1
                      ? 1
                      : (participants.length <= 4 ? 2 : 3),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final p = participants[index];
                  final renderer = p.isLocal
                      ? controller.localRenderer
                      : controller.remoteRenderer;
                  return _participantTile(
                    p,
                    isLocal: p.isLocal,
                    mic: state.micEnabled,
                    cam: state.cameraEnabled,
                    renderer: renderer,
                  );
                },
              ),
              if (waitingForRemote)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(strokeWidth: 4),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Connecting…',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        _controlsBar(state, controller),
      ],
    );
  }

  Widget _participantTile(Participant p,
      {required bool isLocal,
      required bool mic,
      required bool cam,
      RTCVideoRenderer? renderer}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildVideoOrPlaceholder(p, cam, renderer),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            right: 8,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${p.displayName}${isLocal ? ' (You)' : ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Icon(mic ? Icons.mic : Icons.mic_off,
                    size: 16, color: mic ? Colors.green : Colors.redAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoOrPlaceholder(
      Participant p, bool cam, RTCVideoRenderer? r) {
    final hasStream = r != null && r.srcObject != null;
    if (cam && hasStream) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: RTCVideoView(
          r,
          mirror: p.isLocal,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }
    return Container(
      alignment: Alignment.center,
      child: Text(
        cam ? _initials(p.displayName) : 'CAM OFF',
        style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 28,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _controlsBar(CallState state, CallController controller) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlButton(
            icon: state.micEnabled ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            active: state.micEnabled,
            onTap: controller.toggleMic,
          ),
          _controlButton(
            icon: state.cameraEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            active: state.cameraEnabled,
            onTap: controller.toggleCamera,
          ),
          _controlButton(
            icon: Icons.picture_in_picture_alt,
            label: 'PiP',
            active: state.pipEnabled,
            onTap: controller.togglePip,
          ),
          _controlButton(
            icon: Icons.call_end,
            label: 'End',
            active: true,
            color: Colors.red,
            onTap: () => controller.endCall(reason: 'user_end'),
          ),
        ],
      ),
    );
  }

  Widget _controlButton(
      {required IconData icon,
      required String label,
      required bool active,
      required VoidCallback onTap,
      Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color ??
              (active ? Colors.blueGrey.shade700 : Colors.blueGrey.shade900),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
