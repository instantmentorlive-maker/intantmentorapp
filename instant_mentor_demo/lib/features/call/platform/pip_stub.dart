/// Picture-in-Picture (PiP) platform abstraction stub.
/// Actual Android implementation would use a MethodChannel invoking
/// android.app.PictureInPictureParams.Builder and Activity.enterPictureInPictureMode().
/// iOS does not support arbitrary PiP for custom views; video player PiP would
/// require AVPlayerLayer configuration.
class PipService {
  static final PipService instance = PipService._();
  PipService._();

  bool get isSupported {
    // Future: platform checks using dart:io (Platform.isAndroid) etc.
    return false; // stubbed false until implemented
  }

  Future<bool> enterPipMode() async {
    // TODO: invoke platform channel when implemented
    return false;
  }
}
