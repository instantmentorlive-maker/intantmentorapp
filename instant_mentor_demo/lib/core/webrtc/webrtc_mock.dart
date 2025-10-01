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

    // Simulate permission denied for demo
    if (constraints['video'] != false) {
      throw Exception('NotAllowedError: Permission denied');
    }

    return MediaStream();
  }
}

// Mock Navigator class - different name to avoid conflict
class WebRTCNavigator {
  final mediaDevices = MockMediaDevices();
}

// Export mock navigator
final navigator = WebRTCNavigator();
