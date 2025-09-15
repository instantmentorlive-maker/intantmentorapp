import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Central place to resolve the signaling (Socket.IO) base URL.
/// In the future this can read from dotenv or remote config.
/// For now we expose a provider so tests / different builds can override.
final signalingBaseUrlProvider = Provider<String>((ref) {
  // TODO: integrate flutter_dotenv if .env is present; fallback to default.
  const defaultUrl = 'http://localhost:3000';
  return defaultUrl;
});
