// DEPRECATED: This legacy prototype screen is superseded by the controller-driven
// CallScreen + WebRTCMediaService architecture. Retained temporarily for
// comparison/testing and will be removed after stabilization.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/services/webrtc_service.dart';

class WebRTCCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String peerUserId;
  final String title;
  final bool video;
  final bool isCaller;
  const WebRTCCallScreen({
    super.key,
    required this.callId,
    required this.peerUserId,
    required this.title,
    this.video = true,
    this.isCaller = true,
  });

  @override
  ConsumerState<WebRTCCallScreen> createState() => _WebRTCCallScreenState();
}

class _WebRTCCallScreenState extends ConsumerState<WebRTCCallScreen> {
  final _svc = WebRTCService.instance;
  bool _muted = false;
  bool _cameraOn = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _svc.initialize();
    // If caller, create offer. If callee, prepare local stream and wait for offer.
    if (widget.isCaller) {
      await _svc.startCall(
          callId: widget.callId,
          peerUserId: widget.peerUserId,
          video: widget.video);
    } else {
      await _svc.acceptCall(
          callId: widget.callId,
          peerUserId: widget.peerUserId,
          video: widget.video);
    }
    // Connected state is reflected by active renderers
  }

  @override
  void dispose() {
    _svc.endCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Remote video
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      child: RTCVideoView(_svc.remoteRenderer),
                    ),
                  ),
                  // Local preview
                  Positioned(
                    right: 16,
                    top: 16,
                    width: 120,
                    height: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Colors.black54,
                        child: RTCVideoView(_svc.localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildControls(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FloatingActionButton(
          heroTag: 'mute',
          backgroundColor: _muted ? Colors.red : Colors.grey[800],
          onPressed: () async {
            await _svc.toggleMute();
            setState(() => _muted = !_muted);
          },
          child: Icon(_muted ? Icons.mic_off : Icons.mic, color: Colors.white),
        ),
        FloatingActionButton(
          heroTag: 'camera',
          backgroundColor: _cameraOn ? Colors.grey[800] : Colors.red,
          onPressed: () async {
            await _svc.toggleCamera();
            setState(() => _cameraOn = !_cameraOn);
          },
          child: Icon(_cameraOn ? Icons.videocam : Icons.videocam_off,
              color: Colors.white),
        ),
        FloatingActionButton(
          heroTag: 'end',
          backgroundColor: Colors.red,
          onPressed: () async {
            await _svc.endCall();
            if (mounted) Navigator.of(context).pop();
          },
          child: const Icon(Icons.call_end, color: Colors.white),
        ),
      ],
    );
  }
}
