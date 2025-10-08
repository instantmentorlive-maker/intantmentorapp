// Mock WebRTC implementation for web to avoid compilation issues
import 'package:flutter/material.dart';

// Mock MediaStream class
class MediaStream {
  bool active = true;
  String id = 'mock-stream';

  void dispose() {
    active = false;
  }
}

// Mock RTCVideoRenderer class
class RTCVideoRenderer {
  MediaStream? srcObject;
  bool renderVideo = true;

  Future<void> initialize() async {
    // Mock initialization
  }

  void dispose() {
    srcObject = null;
  }
}

// Mock RTCVideoView widget
class RTCVideoView extends StatelessWidget {
  final RTCVideoRenderer _renderer;
  final bool mirror;

  const RTCVideoView(this._renderer, {super.key, this.mirror = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.videocam_off,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }
}

// Mock MediaDevices class
class MockMediaDevices {
  Future<MediaStream> getUserMedia(Map<String, dynamic> constraints) async {
    // Simulate camera access delay
    await Future.delayed(const Duration(milliseconds: 500));

    // ✅ FIXED: Now successfully returns mock stream instead of throwing error
    // This allows the video call UI to work properly in demo mode
    debugPrint('✅ Mock camera access granted');
    return MediaStream();
  }

  Future<MediaStream> getDisplayMedia(Map<String, dynamic> constraints) async {
    // Simulate screen sharing prompt delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Return mock screen sharing stream
    debugPrint('✅ Mock screen sharing started');
    return MediaStream();
  }
}

// Mock Navigator class - different name to avoid conflict
class WebRTCNavigator {
  final mediaDevices = MockMediaDevices();
}

// Export mock navigator
final navigator = WebRTCNavigator();
