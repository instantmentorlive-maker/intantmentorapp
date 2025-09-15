import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/user_provider.dart';
import '../../call/ui/whatsapp_video_call_screen.dart';
import '../../../core/config/signaling_config.dart';
import '../../call/controller/call_controller.dart';

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
    // For 1:1 session we treat current user as caller and sessionId peer as receiver (placeholder logic)
    final user = ref.read(userProvider);
    final callerId = user?.id ?? 'local';
    final receiverId = 'peer-${widget.sessionId}'; // TODO: derive real peer
    final signalingUrl = ref.read(signalingBaseUrlProvider);
    final controller = ref.read(callControllerProvider((
      userId: callerId,
      displayName: user?.name ?? 'User',
      role: 'user',
      baseUrl: signalingUrl
    )).notifier);
    controller.initiateCall(receiverId: receiverId);
    setState(() {
      _joined = true;
      _inSession = true;
      _loading = false;
    });
  }

  Future<void> _leave() async {
    setState(() => _inSession = false);
    // End internal call if active
    final user = ref.read(userProvider);
    final callerId = user?.id ?? 'local';
    final signalingUrl = ref.read(signalingBaseUrlProvider);
    final controller = ref.read(callControllerProvider((
      userId: callerId,
      displayName: user?.name ?? 'User',
      role: 'user',
      baseUrl: signalingUrl
    )).notifier);
    controller.endCall(reason: 'left-session');
    if (mounted && context.canPop()) {
      context.pop();
    } else if (mounted) {
      // If we can't pop, go to a safe route
      context.go('/student/home');
    }
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
            _inSession ? 'Live Session (In-App Call)' : 'Starting Call...'),
        backgroundColor:
            _inSession ? Colors.green.shade800 : Colors.orange.shade800,
        foregroundColor: Colors.white,
        actions: [
          // Media controls now handled inside CallScreen UI
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
                  Text('Starting in-app call...',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            )
          : _inSession
              ? Builder(builder: (context) {
                  final signalingUrl = ref.watch(signalingBaseUrlProvider);
                  return WhatsAppVideoCallScreen(
                    userId: (ref.read(userProvider)?.id ?? 'local'),
                    displayName: (ref.read(userProvider)?.name ?? 'User'),
                    role: 'user',
                    baseUrl: signalingUrl,
                    initialPeerId: 'peer-${widget.sessionId}',
                  );
                })
              : const Center(
                  child: Text('Preparing call UI...',
                      style: TextStyle(color: Colors.white54)),
                ),
    );
  }
}
