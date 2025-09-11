import 'dart:developer';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// RtcService wraps Agora basic join/leave & channel events.
/// Expect env vars: AGORA_APP_ID, AGORA_TEMP_TOKEN (or fetch from backend func).
class RtcService {
  RtcService._();
  static final RtcService instance = RtcService._();
  late final RtcEngine _engine;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final appId = dotenv.env['AGORA_APP_ID'];
    if (appId == null || appId.isEmpty) {
      throw Exception('AGORA_APP_ID missing in .env');
    }
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));
    await _engine.enableVideo();
    _initialized = true;
  }

  Future<void> joinChannel({
    required String channelId,
    required int uid,
    String? token,
  }) async {
    if (!_initialized) await initialize();
    await _engine.startPreview();
    final effectiveToken = token ?? dotenv.env['AGORA_TEMP_TOKEN'] ?? '';
    await _engine.joinChannel(
      token: effectiveToken,
      channelId: channelId,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> leaveChannel() async {
    try {
      await _engine.leaveChannel();
    } catch (e) {
      debugPrint('leaveChannel error: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _engine.release();
    } catch (e) {
      log('RtcService dispose error: $e');
    }
    _initialized = false;
  }
}
