import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// JitsiService handles video calls using Jitsi Meet web interface.
/// This is a simple implementation that opens Jitsi in browser/app.
class JitsiService {
  JitsiService._();
  static final JitsiService instance = JitsiService._();

  Future<void> joinConference({
    required String room,
    required String displayName,
    String? email,
    bool audioMuted = false,
    bool videoMuted = false,
  }) async {
    // Use public Jitsi server or custom server
    const baseUrl = 'https://meet.jit.si';

    // Create Jitsi meeting URL with parameters
    final cleanRoom = room.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');
    final meetingUrl = '$baseUrl/$cleanRoom';

    try {
      final uri = Uri.parse(meetingUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode:
              LaunchMode.externalApplication, // Opens in Jitsi app if installed
        );
      } else {
        throw Exception('Could not launch Jitsi meeting: $meetingUrl');
      }
    } catch (e) {
      debugPrint('Jitsi join error: $e');
      rethrow;
    }
  }

  Future<void> hangUp() async {
    // For URL-based approach, this is handled by the Jitsi app/browser
    // In a real implementation, you might track the meeting state
    debugPrint('Jitsi hangup requested - user should end call in Jitsi app');
  }

  /// Generate a random readable room name if none provided
  String generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
