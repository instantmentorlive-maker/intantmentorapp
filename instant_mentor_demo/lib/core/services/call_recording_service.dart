// Stub: CallRecordingService removed - video calling features disabled
class CallRecordingService {
  bool get isRecording => false;
  String? get currentRecordingId => null;
  Stream<dynamic> get eventStream => const Stream.empty();
  Future<bool> initialize() async => false;
  Future<bool> startRecording({required String channelName}) async => false;
  Future<void> stopRecording() async {}
  Future<void> dispose() async {}
}
