// Conditional imports for WebRTC utilities
export 'webrtc_stub.dart' if (dart.library.html) 'webrtc_web.dart';
