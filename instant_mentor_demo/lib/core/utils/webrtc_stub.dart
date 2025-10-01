import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Stub WebRTC utilities for non-web platforms
class WebRTCWebUtils {
  /// Initialize camera with standard approach
  static Future<MediaStream?> getUserMedia({
    bool video = true,
    bool audio = true,
  }) async {
    try {
      final constraints = <String, dynamic>{
        'video': video ? {'width': 640, 'height': 480} : false,
        'audio': audio,
      };

      return await navigator.mediaDevices.getUserMedia(constraints);
    } catch (e) {
      print('Error getting user media: $e');
      return null;
    }
  }

  /// Not needed for non-web platforms
  static dynamic createVideoElement() {
    return null;
  }
}
