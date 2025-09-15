/// Screen share stub. Real implementation will require:
///  - Requesting capture permissions (Android MediaProjection)
///  - Using flutter_webrtc's navigator.mediaDevices.getDisplayMedia (Web)
///  - iOS: ReplayKit based broadcast extension (separate target)
class ScreenShareService {
  static final ScreenShareService instance = ScreenShareService._();
  ScreenShareService._();

  bool _sharing = false;
  bool get isSharing => _sharing;

  Future<bool> startShare() async {
    // TODO: integrate with WebRTC track addition
    _sharing = true;
    return _sharing;
  }

  Future<void> stopShare() async {
    _sharing = false;
  }
}
