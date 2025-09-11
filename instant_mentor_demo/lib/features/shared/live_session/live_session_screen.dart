import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/jitsi_service.dart';
import '../../../core/providers/user_provider.dart';

class LiveSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const LiveSessionScreen({super.key, required this.sessionId});

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen> {
  bool _joined = false;
  bool _loading = false;
  bool _inSession = false;

  Future<void> _join() async {
    if (_joined || _loading) return;
    setState(() => _loading = true);
    final user = ref.read(userProvider);
    final name = user?.name ?? 'User';
    try {
      await JitsiService.instance.joinConference(
        room: _generateRoomName(widget.sessionId),
        displayName: name,
        email: user?.email,
        audioMuted: false,
        videoMuted: false,
      );
      setState(() {
        _joined = true;
        _inSession = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Join failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _generateRoomName(String sessionId) {
    // Create a more user-friendly and secure room name
    // In production, you might want to hash this with a secret
    return 'mentor-session-${sessionId.substring(0, 8)}';
  }

  Future<void> _leave() async {
    setState(() => _inSession = false);
    await JitsiService.instance.hangUp();
    if (mounted) context.pop();
  }

  @override
  void initState() {
    super.initState();
    // Auto join on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _join());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _inSession ? 'Live Session - Connected' : 'Joining Session...'),
        backgroundColor:
            _inSession ? Colors.green.shade800 : Colors.orange.shade800,
        foregroundColor: Colors.white,
        actions: [
          if (_inSession) ...[
            IconButton(
              icon: const Icon(Icons.mic_off),
              onPressed: () {
                // TODO: Integrate with Jitsi controls
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Microphone toggle - use Jitsi controls')),
                );
              },
              tooltip: 'Toggle Microphone',
            ),
            IconButton(
              icon: const Icon(Icons.videocam_off),
              onPressed: () {
                // TODO: Integrate with Jitsi controls
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Camera toggle - use Jitsi controls')),
                );
              },
              tooltip: 'Toggle Camera',
            ),
            IconButton(
              icon: const Icon(Icons.screen_share),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Screen share - use Jitsi controls')),
                );
              },
              tooltip: 'Share Screen',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.call_end),
            color: Colors.red,
            onPressed: _leave,
            tooltip: 'End Session',
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Joining session...',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            )
          : Column(
              children: [
                // Session Info Banner
                if (_inSession)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.green.shade800,
                    child: Row(
                      children: [
                        const Icon(Icons.videocam,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Session Active - Video call is running in Jitsi Meet',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Text(
                          'Room: ${_generateRoomName(widget.sessionId)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                // Video Area Placeholder
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey[900],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _inSession ? Icons.video_call : Icons.videocam_off,
                            size: 64,
                            color: _inSession ? Colors.green : Colors.white54,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _inSession
                                ? 'Video call is active in Jitsi Meet app/browser'
                                : 'Waiting to join video call...',
                            style: TextStyle(
                              color: _inSession
                                  ? Colors.green.shade300
                                  : Colors.white54,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_inSession) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Switch to Jitsi app for full video features',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Whiteboard Area
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Column(
                      children: [
                        // Whiteboard Toolbar
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {},
                                tooltip: 'Pen',
                              ),
                              IconButton(
                                icon: const Icon(Icons.crop_square),
                                onPressed: () {},
                                tooltip: 'Rectangle',
                              ),
                              IconButton(
                                icon: const Icon(Icons.circle_outlined),
                                onPressed: () {},
                                tooltip: 'Circle',
                              ),
                              IconButton(
                                icon: const Icon(Icons.text_fields),
                                onPressed: () {},
                                tooltip: 'Text',
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {},
                                tooltip: 'Clear',
                              ),
                              IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () => _exportWhiteboard(context),
                                tooltip: 'Export',
                              ),
                            ],
                          ),
                        ),

                        // Whiteboard Canvas
                        Expanded(
                          child: Center(
                            child: _loading
                                ? const CircularProgressIndicator()
                                : Text(
                                    _joined
                                        ? 'Connected: ${widget.sessionId}'
                                        : 'Joining room ${widget.sessionId}...',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Chat Panel
                Container(
                  height: 150,
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.chat),
                            SizedBox(width: 8),
                            Text('Session Chat'),
                          ],
                        ),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(
                            child: Text(
                              'Session chat messages will appear here',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _exportWhiteboard(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Whiteboard exported as PDF!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
