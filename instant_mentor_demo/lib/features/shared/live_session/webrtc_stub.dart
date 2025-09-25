// Lightweight stub for flutter_webrtc to allow web build without the real package.
// Only used on web via conditional import.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class RTCVideoRenderer {
  Object? srcObject;
  Future<void> initialize() async {}
  void dispose() {}
}

class RTCVideoView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool mirror;
  const RTCVideoView(this.renderer, {super.key, this.mirror = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF222222),
      alignment: Alignment.center,
      child: const Text(
        'Video (stub)',
        style: TextStyle(color: Color(0xFFAAAAAA)),
      ),
    );
  }
}

class MediaStream {
  final List<MediaStreamTrack> _videoTracks = [];
  final List<MediaStreamTrack> _audioTracks = [];
  List<MediaStreamTrack> getVideoTracks() => _videoTracks;
  List<MediaStreamTrack> getAudioTracks() => _audioTracks;
  List<MediaStreamTrack> getTracks() => [..._videoTracks, ..._audioTracks];
  void dispose() {}
}

class MediaStreamTrack {
  bool enabled = true;
  Future<void> applyConstraints(Map<String, dynamic> constraints) async {}
  void stop() {}
}

class RTCPeerConnection {
  Future<void> addStream(MediaStream stream) async {}
  Future<dynamic> createOffer() async => _FakeSDP();
  Future<dynamic> createAnswer() async => _FakeSDP();
  Future<void> setLocalDescription(dynamic desc) async {}
  Future<void> setRemoteDescription(dynamic desc) async {}
  Future<void> addCandidate(dynamic c) async {}
  Future<List<dynamic>> getStats() async => [];
  Future<void> close() async {}
  void Function(dynamic)? onIceCandidate;
  void Function(MediaStream stream)? onAddStream;
  void Function(dynamic)? onConnectionState;
  dynamic connectionState;
  dynamic iceConnectionState;
  dynamic signalingState;
}

// Minimal enum mimic
class RTCPeerConnectionState {
  static const RTCPeerConnectionState RTCPeerConnectionStateFailed =
      RTCPeerConnectionState._('failed');
  final String value;
  const RTCPeerConnectionState._(this.value);
}

class _FakeSDP {
  Map<String, dynamic> toMap() => {'sdp': 'stub', 'type': 'offer'};
}

class RTCSessionDescription {
  final String sdp;
  final String type;
  RTCSessionDescription(this.sdp, this.type);
}

class RTCIceCandidate {
  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
  RTCIceCandidate(this.candidate, this.sdpMid, this.sdpMLineIndex);
  Map<String, dynamic> toMap() => {
        'candidate': candidate,
        'sdpMid': sdpMid,
        'sdpMLineIndex': sdpMLineIndex,
      };
}

class Helper {
  static Future<void> switchCamera(MediaStreamTrack track) async {}
  static Future<void> setSpeakerphoneOn(bool on) async {}
}

Future<RTCPeerConnection> createPeerConnection(
        Map<String, dynamic> config) async =>
    RTCPeerConnection();

// Pretend navigator.mediaDevices.getUserMedia - we just return a dummy object.
class _FakeNavigator {
  final mediaDevices = _FakeMediaDevices();
}

class _FakeMediaDevices {
  Future<dynamic> getUserMedia(Map<String, dynamic> constraints) async {
    if (kDebugMode) {
      print('Stub getUserMedia called with $constraints');
    }
    return null;
  }
}

final navigator = _FakeNavigator();
