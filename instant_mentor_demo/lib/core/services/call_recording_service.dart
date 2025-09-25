// Stub: CallRecordingService removed
class CallRecordingService {
  bool get isRecording => false;
  String? get currentRecordingId => null;
  Stream<dynamic> get eventStream => const Stream.empty();
  Future<bool> initialize() async => false;
  Future<bool> startRecording({required String channelName}) async => false;
  Future<void> stopRecording() async {}
  Future<void> dispose() async {}
}
  RecordingConfiguration get config => _config;

  CallRecordingService(this._videoService);

  /// Initialize recording service
  Future<bool> initialize() async {
    try {
      debugPrint('$_tag: Initializing call recording service...');

      // Load recording configuration
      await _loadRecordingConfiguration();

      // Listen to video call events
      _videoService.eventStream.listen(_handleVideoCallEvent);

      debugPrint('$_tag: ✅ Call recording service initialized');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to initialize recording service: $e');
      return false;
    }
  }

  /// Start call recording
  Future<bool> startRecording({
    String? channelName,
    RecordingConfiguration? customConfig,
  }) async {
    if (_isRecording) {
      debugPrint('$_tag: ⚠️ Recording already in progress');
      return false;
    }

    final channel = channelName ?? _videoService.currentChannelName;
    if (channel == null) {
      debugPrint('$_tag: ❌ No active call to record');
      return false;
    }

    try {
      debugPrint('$_tag: Starting call recording for channel: $channel');

      final recordingConfig = customConfig ?? _config;

      // Request recording token from server
      final recordingToken =
          await _requestRecordingToken(channel, recordingConfig);
      if (recordingToken == null) {
        return false;
      }

      // Start server-side recording
      final recordingId =
          await _startServerRecording(channel, recordingToken, recordingConfig);
      if (recordingId == null) {
        return false;
      }

      // Update local state
      _isRecording = true;
      _currentRecordingId = recordingId;
      _recordingStartTime = DateTime.now();

      // Create recording session
      final session = RecordingSession(
        recordingId: recordingId,
        channelName: channel,
        startTime: _recordingStartTime!,
        configuration: recordingConfig,
        status: RecordingStatus.recording,
      );

      _recordingSessions.add(session);

      _eventController.add(RecordingEvent(
        type: RecordingEventType.recordingStarted,
        message: 'Call recording started',
        data: {
          'recordingId': recordingId,
          'channelName': channel,
          'startTime': _recordingStartTime!.toIso8601String(),
        },
      ));

      debugPrint('$_tag: ✅ Recording started successfully - ID: $recordingId');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to start recording: $e');

      _eventController.add(RecordingEvent(
        type: RecordingEventType.recordingFailed,
        message: 'Failed to start recording: $e',
      ));

      return false;
    }
  }

  /// Stop current call recording
  Future<bool> stopRecording() async {
    if (!_isRecording || _currentRecordingId == null) {
      debugPrint('$_tag: ⚠️ No active recording to stop');
      return false;
    }

    try {
      debugPrint('$_tag: Stopping call recording - ID: $_currentRecordingId');

      // Stop server-side recording
      final success = await _stopServerRecording(_currentRecordingId!);
      if (!success) {
        return false;
      }

      // Update recording session
      final sessionIndex = _recordingSessions
          .indexWhere((s) => s.recordingId == _currentRecordingId);

      if (sessionIndex != -1) {
        final session = _recordingSessions[sessionIndex];
        final duration = DateTime.now().difference(session.startTime);

        _recordingSessions[sessionIndex] = session.copyWith(
          endTime: DateTime.now(),
          duration: duration,
          status: RecordingStatus.completed,
        );
      }

      _eventController.add(RecordingEvent(
        type: RecordingEventType.recordingStopped,
        message: 'Call recording stopped',
        data: {
          'recordingId': _currentRecordingId,
          'duration': DateTime.now().difference(_recordingStartTime!).inSeconds,
        },
      ));

      // Reset state
      final recordingId = _currentRecordingId;
      _isRecording = false;
      _currentRecordingId = null;
      _recordingStartTime = null;

      debugPrint('$_tag: ✅ Recording stopped successfully - ID: $recordingId');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to stop recording: $e');

      _eventController.add(RecordingEvent(
        type: RecordingEventType.recordingFailed,
        message: 'Failed to stop recording: $e',
      ));

      return false;
    }
  }

  /// Pause current recording (if supported)
  Future<bool> pauseRecording() async {
    if (!_isRecording || _currentRecordingId == null) {
      debugPrint('$_tag: ⚠️ No active recording to pause');
      return false;
    }

    try {
      debugPrint('$_tag: Pausing recording - ID: $_currentRecordingId');

      // Pause server-side recording
      final success = await _pauseServerRecording(_currentRecordingId!);
      if (!success) {
        return false;
      }

      _eventController.add(RecordingEvent(
        type: RecordingEventType.recordingPaused,
        message: 'Recording paused',
        data: {'recordingId': _currentRecordingId},
      ));

      debugPrint('$_tag: ✅ Recording paused');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to pause recording: $e');
      return false;
    }
  }

  /// Resume paused recording
  Future<bool> resumeRecording() async {
    if (!_isRecording || _currentRecordingId == null) {
      debugPrint('$_tag: ⚠️ No paused recording to resume');
      return false;
    }

    try {
      debugPrint('$_tag: Resuming recording - ID: $_currentRecordingId');

      // Resume server-side recording
      final success = await _resumeServerRecording(_currentRecordingId!);
      if (!success) {
        return false;
      }

      _eventController.add(RecordingEvent(
        type: RecordingEventType.recordingResumed,
        message: 'Recording resumed',
        data: {'recordingId': _currentRecordingId},
      ));

      debugPrint('$_tag: ✅ Recording resumed');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to resume recording: $e');
      return false;
    }
  }

  /// Update recording configuration
  Future<void> updateConfiguration(RecordingConfiguration newConfig) async {
    _config = newConfig;
    await _saveRecordingConfiguration();

    debugPrint('$_tag: Recording configuration updated');

    _eventController.add(RecordingEvent(
      type: RecordingEventType.configurationUpdated,
      message: 'Recording configuration updated',
      data: newConfig.toJson(),
    ));
  }

  /// Get recording sessions history
  List<RecordingSession> getRecordingSessions({int? limit}) {
    final sessions = List<RecordingSession>.from(_recordingSessions)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    if (limit != null && sessions.length > limit) {
      return sessions.take(limit).toList();
    }

    return sessions;
  }

  /// Get recording session by ID
  RecordingSession? getRecordingSession(String recordingId) {
    try {
      return _recordingSessions.firstWhere(
        (session) => session.recordingId == recordingId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Delete recording session
  Future<bool> deleteRecording(String recordingId) async {
    try {
      debugPrint('$_tag: Deleting recording - ID: $recordingId');

      // Delete from server
      final success = await _deleteServerRecording(recordingId);
      if (!success) {
        return false;
      }

      // Remove from local sessions
      _recordingSessions.removeWhere(
        (session) => session.recordingId == recordingId,
      );

      _eventController.add(RecordingEvent(
        type: RecordingEventType.recordingDeleted,
        message: 'Recording deleted',
        data: {'recordingId': recordingId},
      ));

      debugPrint('$_tag: ✅ Recording deleted - ID: $recordingId');
      return true;
    } catch (e) {
      debugPrint('$_tag: ❌ Failed to delete recording: $e');
      return false;
    }
  }

  /// Request recording token from server
  Future<String?> _requestRecordingToken(
      String channelName, RecordingConfiguration config) async {
    try {
      final response = await http.post(
        Uri.parse('$_recordingServerUrl/recording/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'channelName': channelName,
          'recordingConfig': config.toJson(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['recordingToken'] as String?;
      } else {
        debugPrint(
            '$_tag: ❌ Failed to get recording token: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('$_tag: ❌ Error requesting recording token: $e');
      return null;
    }
  }

  /// Start server-side recording
  Future<String?> _startServerRecording(
      String channelName, String token, RecordingConfiguration config) async {
    try {
      final response = await http.post(
        Uri.parse('$_recordingServerUrl/recording/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'channelName': channelName,
          'recordingToken': token,
          'configuration': config.toJson(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['recordingId'] as String?;
      } else {
        debugPrint(
            '$_tag: ❌ Failed to start server recording: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('$_tag: ❌ Error starting server recording: $e');
      return null;
    }
  }

  /// Stop server-side recording
  Future<bool> _stopServerRecording(String recordingId) async {
    try {
      final response = await http.post(
        Uri.parse('$_recordingServerUrl/recording/stop'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'recordingId': recordingId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('$_tag: ❌ Error stopping server recording: $e');
      return false;
    }
  }

  /// Pause server-side recording
  Future<bool> _pauseServerRecording(String recordingId) async {
    try {
      final response = await http.post(
        Uri.parse('$_recordingServerUrl/recording/pause'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'recordingId': recordingId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('$_tag: ❌ Error pausing server recording: $e');
      return false;
    }
  }

  /// Resume server-side recording
  Future<bool> _resumeServerRecording(String recordingId) async {
    try {
      final response = await http.post(
        Uri.parse('$_recordingServerUrl/recording/resume'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'recordingId': recordingId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('$_tag: ❌ Error resuming server recording: $e');
      return false;
    }
  }

  /// Delete server-side recording
  Future<bool> _deleteServerRecording(String recordingId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_recordingServerUrl/recording/$recordingId'),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('$_tag: ❌ Error deleting server recording: $e');
      return false;
    }
  }

  /// Load recording configuration from storage
  Future<void> _loadRecordingConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('recording_configuration');

      if (configJson != null) {
        final configMap = json.decode(configJson) as Map<String, dynamic>;
        _config = RecordingConfiguration.fromJson(configMap);
      }
    } catch (e) {
      debugPrint('$_tag: ❌ Error loading recording configuration: $e');
    }
  }

  /// Save recording configuration to storage
  Future<void> _saveRecordingConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'recording_configuration', json.encode(_config.toJson()));
    } catch (e) {
      debugPrint('$_tag: ❌ Error saving recording configuration: $e');
    }
  }

  /// Handle video call events
  void _handleVideoCallEvent(VideoCallEvent event) {
    switch (event.type) {
      case VideoCallEventType.callEnded:
        if (_isRecording) {
          debugPrint('$_tag: Call ended, stopping recording automatically');
          stopRecording();
        }
        break;
      case VideoCallEventType.callFailed:
        if (_isRecording) {
          debugPrint('$_tag: Call failed, stopping recording');
          stopRecording();
        }
        break;
      default:
        break;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    // Stop any active recording
    if (_isRecording) {
      await stopRecording();
    }

    await _eventController.close();

    debugPrint('$_tag: ✅ Call recording service disposed');
  }
}

/// Recording configuration
class RecordingConfiguration {
  final RecordingMode mode;
  final VideoQuality videoQuality;
  final AudioQuality audioQuality;
  final bool enableCloudStorage;
  final String? storageLocation;
  final Duration maxDuration;
  final bool autoStart;
  final bool includeScreenShare;

  const RecordingConfiguration({
    this.mode = RecordingMode.individual,
    this.videoQuality = VideoQuality.hd,
    this.audioQuality = AudioQuality.high,
    this.enableCloudStorage = true,
    this.storageLocation,
    this.maxDuration = const Duration(hours: 2),
    this.autoStart = false,
    this.includeScreenShare = true,
  });

  Map<String, dynamic> toJson() => {
        'mode': mode.toString(),
        'videoQuality': videoQuality.toString(),
        'audioQuality': audioQuality.toString(),
        'enableCloudStorage': enableCloudStorage,
        'storageLocation': storageLocation,
        'maxDuration': maxDuration.inSeconds,
        'autoStart': autoStart,
        'includeScreenShare': includeScreenShare,
      };

  factory RecordingConfiguration.fromJson(Map<String, dynamic> json) {
    return RecordingConfiguration(
      mode: RecordingMode.values.firstWhere(
        (e) => e.toString() == json['mode'],
        orElse: () => RecordingMode.individual,
      ),
      videoQuality: VideoQuality.values.firstWhere(
        (e) => e.toString() == json['videoQuality'],
        orElse: () => VideoQuality.hd,
      ),
      audioQuality: AudioQuality.values.firstWhere(
        (e) => e.toString() == json['audioQuality'],
        orElse: () => AudioQuality.high,
      ),
      enableCloudStorage: json['enableCloudStorage'] ?? true,
      storageLocation: json['storageLocation'],
      maxDuration: Duration(seconds: json['maxDuration'] ?? 7200),
      autoStart: json['autoStart'] ?? false,
      includeScreenShare: json['includeScreenShare'] ?? true,
    );
  }
}

/// Recording modes
enum RecordingMode { individual, composite }

/// Video quality settings
enum VideoQuality { sd, hd, fullHd }

/// Audio quality settings
enum AudioQuality { standard, high, lossless }

/// Recording status
enum RecordingStatus { recording, paused, completed, failed }

/// Recording session data
class RecordingSession {
  final String recordingId;
  final String channelName;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? duration;
  final RecordingConfiguration configuration;
  final RecordingStatus status;
  final String? errorMessage;
  final int fileSizeBytes;
  final String? downloadUrl;

  const RecordingSession({
    required this.recordingId,
    required this.channelName,
    required this.startTime,
    this.endTime,
    this.duration,
    required this.configuration,
    required this.status,
    this.errorMessage,
    this.fileSizeBytes = 0,
    this.downloadUrl,
  });

  RecordingSession copyWith({
    String? recordingId,
    String? channelName,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    RecordingConfiguration? configuration,
    RecordingStatus? status,
    String? errorMessage,
    int? fileSizeBytes,
    String? downloadUrl,
  }) {
    return RecordingSession(
      recordingId: recordingId ?? this.recordingId,
      channelName: channelName ?? this.channelName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      configuration: configuration ?? this.configuration,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'recordingId': recordingId,
        'channelName': channelName,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'duration': duration?.inSeconds,
        'configuration': configuration.toJson(),
        'status': status.toString(),
        'errorMessage': errorMessage,
        'fileSizeBytes': fileSizeBytes,
        'downloadUrl': downloadUrl,
      };
}

/// Recording event types
enum RecordingEventType {
  recordingStarted,
  recordingStopped,
  recordingPaused,
  recordingResumed,
  recordingFailed,
  recordingDeleted,
  configurationUpdated,
}

/// Recording event data
class RecordingEvent {
  final RecordingEventType type;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  RecordingEvent({
    required this.type,
    required this.message,
    this.data,
  }) : timestamp = DateTime.now();
}
