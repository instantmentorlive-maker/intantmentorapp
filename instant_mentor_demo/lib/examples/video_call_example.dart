import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/call/controllers/simple_call_controller.dart';
import '../features/call/models/models.dart';
import '../features/call/screens/active_call_screen.dart';
import '../features/call/screens/incoming_call_screen.dart';
import '../features/call/screens/outgoing_call_screen.dart';
import '../features/call/services/call_notification_service.dart';

/// Example implementation showing how to integrate video calling
/// This demonstrates the complete call flow and UI integration
class VideoCallExample extends ConsumerWidget {
  const VideoCallExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callData = ref.watch(simpleCallControllerProvider);
    final callController = ref.read(simpleCallControllerProvider.notifier);

    // Initialize notification service
    ref.watch(callNotificationServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call Demo'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current call status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Call Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      callData == null
                          ? 'No active call'
                          : 'Call with ${callData.getOtherParticipantName("")} - ${callData.state.name}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (callData?.duration != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Duration: ${_formatDuration(callData!.duration!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Call actions
            Text(
              'Start a Call',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Video call buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: callData == null
                        ? () => _startVideoCall(context, callController)
                        : null,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Start Video Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: callData == null
                        ? () => _startAudioCall(context, callController)
                        : null,
                    icon: const Icon(Icons.phone),
                    label: const Text('Start Audio Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Call controls (when in call)
            if (callData != null) ...[
              Text(
                'Call Controls',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (callData.state == CallState.ringing &&
                      callData.isIncoming) ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        await callController.acceptCall();
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ActiveCallScreen(),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.call),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => callController.rejectCall(),
                      icon: const Icon(Icons.call_end),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                  if (callData.state.isOngoing) ...[
                    ElevatedButton.icon(
                      onPressed: () => callController.toggleAudio(),
                      icon: Icon(
                        callData.mediaState.isAudioEnabled
                            ? Icons.mic
                            : Icons.mic_off,
                      ),
                      label: Text(
                        callData.mediaState.isAudioEnabled ? 'Mute' : 'Unmute',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: callData.mediaState.isAudioEnabled
                            ? Colors.grey
                            : Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => callController.toggleVideo(),
                      icon: Icon(
                        callData.mediaState.isVideoEnabled
                            ? Icons.videocam
                            : Icons.videocam_off,
                      ),
                      label: Text(
                        callData.mediaState.isVideoEnabled
                            ? 'Camera Off'
                            : 'Camera On',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: callData.mediaState.isVideoEnabled
                            ? Colors.grey
                            : Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => callController.endCall(),
                      icon: const Icon(Icons.call_end),
                      label: const Text('End Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // Advanced call features
              Text(
                'Advanced Features',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => callController.switchCamera(),
                    icon: const Icon(Icons.flip_camera_ios),
                    label: const Text('Switch Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => callController.toggleSpeaker(),
                    icon: Icon(
                      callData.mediaState.isSpeakerOn
                          ? Icons.volume_up
                          : Icons.hearing,
                    ),
                    label: Text(
                      callData.mediaState.isSpeakerOn ? 'Earpiece' : 'Speaker',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: callData.mediaState.isSpeakerOn
                          ? Colors.purple
                          : Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showCallStatistics(context, callController),
                    icon: const Icon(Icons.analytics),
                    label: const Text('Call Stats'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showVideoSettings(context, callController),
                    icon: const Icon(Icons.settings),
                    label: const Text('Video Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Navigation to call screens
            Text(
              'Call Screen Examples',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const IncomingCallScreen(),
                      ),
                    );
                  },
                  child: const Text('View Incoming Call Screen'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const OutgoingCallScreen(),
                      ),
                    );
                  },
                  child: const Text('View Outgoing Call Screen'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ActiveCallScreen(),
                      ),
                    );
                  },
                  child: const Text('View Active Call Screen'),
                ),
              ],
            ),

            const Spacer(),

            // Implementation notes
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Implementation Notes',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• WebRTC peer-to-peer video calling\n'
                      '• Signaling via WebSocket service\n'
                      '• Support for video and audio calls\n'
                      '• Call history persistence\n'
                      '• Comprehensive UI with animations\n'
                      '• Real-time media controls',
                      style: TextStyle(fontSize: 12),
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

  /// Start a video call with a demo user
  void _startVideoCall(
      BuildContext context, SimpleCallController controller) async {
    try {
      await controller.startCall(
        currentUserId: 'user1',
        targetUserId: 'user2',
        targetUserName: 'John Doe',
        currentUserName: 'You',
      );

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const OutgoingCallScreen(),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Start an audio call with a demo user
  void _startAudioCall(
      BuildContext context, SimpleCallController controller) async {
    try {
      await controller.startCall(
        currentUserId: 'user1',
        targetUserId: 'user2',
        targetUserName: 'Jane Smith',
        currentUserName: 'You',
        isVideoCall: false,
      );

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const OutgoingCallScreen(),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Format duration for display
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

  /// Show call statistics dialog
  void _showCallStatistics(
      BuildContext context, SimpleCallController controller) async {
    try {
      final stats = await controller.getCallStatistics();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Call Statistics'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (stats != null) ...[
                    _buildStatRow('Connection State',
                        stats['connectionState'] ?? 'Unknown'),
                    _buildStatRow(
                        'ICE State', stats['iceConnectionState'] ?? 'Unknown'),
                    _buildStatRow('Signaling State',
                        stats['signalingState'] ?? 'Unknown'),
                    const Divider(),
                    if (stats['videoBytesReceived'] != null)
                      _buildStatRow('Video Received',
                          '${stats['videoBytesReceived']} bytes'),
                    if (stats['videoBytesSent'] != null)
                      _buildStatRow(
                          'Video Sent', '${stats['videoBytesSent']} bytes'),
                    if (stats['videoPacketsReceived'] != null)
                      _buildStatRow('Video Packets In',
                          '${stats['videoPacketsReceived']}'),
                    if (stats['videoPacketsSent'] != null)
                      _buildStatRow(
                          'Video Packets Out', '${stats['videoPacketsSent']}'),
                  ] else ...[
                    const Text('No statistics available'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get statistics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show video settings dialog
  void _showVideoSettings(
      BuildContext context, SimpleCallController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('HD Quality (720p)'),
              onTap: () {
                controller.setVideoResolution();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Video quality set to HD')),
                );
              },
            ),
            ListTile(
              title: const Text('Standard Quality (480p)'),
              onTap: () {
                controller.setVideoResolution(
                    width: 854, height: 480, frameRate: 24);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Video quality set to Standard')),
                );
              },
            ),
            ListTile(
              title: const Text('Low Quality (360p)'),
              onTap: () {
                controller.setVideoResolution(
                    width: 640, height: 360, frameRate: 15);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Video quality set to Low')),
                );
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('Toggle Echo Cancellation'),
              onTap: () {
                controller.toggleEchoCancellation();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Echo cancellation toggled')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build a statistics row
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

/// Simple demo app to showcase video calling
class VideoCallDemoApp extends StatelessWidget {
  const VideoCallDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Video Call Demo',
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          useMaterial3: true,
        ),
        home: const VideoCallExample(),
        routes: {
          '/incoming-call': (context) => const IncomingCallScreen(),
          '/outgoing-call': (context) => const OutgoingCallScreen(),
          '/active-call': (context) => const ActiveCallScreen(),
        },
      ),
    );
  }
}
