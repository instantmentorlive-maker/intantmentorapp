import 'dart:html' as html;
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Web-compatible WebRTC utilities
class WebRTCWebUtils {
  /// Initialize camera with web-compatible approach
  static Future<MediaStream?> getUserMedia({
    bool video = true,
    bool audio = true,
  }) async {
    try {
      // Use the standard WebRTC approach for web
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

  /// Create a simple video element for web
  static html.VideoElement? createVideoElement() {
    return html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';
  }
}
