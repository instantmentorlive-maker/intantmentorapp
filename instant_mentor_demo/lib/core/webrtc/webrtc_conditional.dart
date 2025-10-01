// Conditional WebRTC exports - use mock on web to avoid compilation issues
export 'package:flutter_webrtc/flutter_webrtc.dart'
    if (dart.library.html) 'webrtc_mock.dart';
