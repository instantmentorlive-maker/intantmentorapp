/// Media state for managing audio/video controls during a call
class MediaState {
  /// Whether audio is enabled (microphone)
  final bool isAudioEnabled;

  /// Whether video is enabled (camera)
  final bool isVideoEnabled;

  /// Whether speaker is enabled (vs earpiece)
  final bool isSpeakerOn;

  /// Whether echo cancellation is enabled
  final bool isEchoCancellationEnabled;

  /// Current camera facing (front/rear)
  final CameraFacing cameraFacing;

  const MediaState({
    this.isAudioEnabled = true,
    this.isVideoEnabled = true,
    this.isSpeakerOn = false,
    this.isEchoCancellationEnabled = true,
    this.cameraFacing = CameraFacing.front,
  });

  /// Create a copy with updated values
  MediaState copyWith({
    bool? isAudioEnabled,
    bool? isVideoEnabled,
    bool? isSpeakerOn,
    bool? isEchoCancellationEnabled,
    CameraFacing? cameraFacing,
  }) {
    return MediaState(
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isEchoCancellationEnabled:
          isEchoCancellationEnabled ?? this.isEchoCancellationEnabled,
      cameraFacing: cameraFacing ?? this.cameraFacing,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'isAudioEnabled': isAudioEnabled,
      'isVideoEnabled': isVideoEnabled,
      'isSpeakerOn': isSpeakerOn,
      'isEchoCancellationEnabled': isEchoCancellationEnabled,
      'cameraFacing': cameraFacing.name,
    };
  }

  /// Create from JSON
  factory MediaState.fromJson(Map<String, dynamic> json) {
    return MediaState(
      isAudioEnabled: json['isAudioEnabled'] ?? true,
      isVideoEnabled: json['isVideoEnabled'] ?? true,
      isSpeakerOn: json['isSpeakerOn'] ?? false,
      isEchoCancellationEnabled: json['isEchoCancellationEnabled'] ?? true,
      cameraFacing: CameraFacing.values.firstWhere(
        (e) => e.name == json['cameraFacing'],
        orElse: () => CameraFacing.front,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaState &&
        other.isAudioEnabled == isAudioEnabled &&
        other.isVideoEnabled == isVideoEnabled &&
        other.isSpeakerOn == isSpeakerOn &&
        other.isEchoCancellationEnabled == isEchoCancellationEnabled &&
        other.cameraFacing == cameraFacing;
  }

  @override
  int get hashCode {
    return Object.hash(
      isAudioEnabled,
      isVideoEnabled,
      isSpeakerOn,
      isEchoCancellationEnabled,
      cameraFacing,
    );
  }

  @override
  String toString() {
    return 'MediaState('
        'audio: $isAudioEnabled, '
        'video: $isVideoEnabled, '
        'speaker: $isSpeakerOn, '
        'echo: $isEchoCancellationEnabled, '
        'camera: ${cameraFacing.name}'
        ')';
  }

  /// Check if any media is enabled
  bool get hasActiveMedia => isAudioEnabled || isVideoEnabled;

  /// Check if call is audio-only
  bool get isAudioOnly => isAudioEnabled && !isVideoEnabled;

  /// Get a user-friendly media description
  String get description {
    if (!hasActiveMedia) return 'No media';
    if (isAudioOnly) return 'Audio only';
    if (isAudioEnabled && isVideoEnabled) return 'Audio & Video';
    if (isVideoEnabled) return 'Video only';
    return 'Unknown';
  }

  /// Legacy compatibility getter
  bool get isSpeakerEnabled => isSpeakerOn;
}

/// Camera facing direction
enum CameraFacing {
  front,
  rear,
}

/// Extension for camera facing
extension CameraFacingExtension on CameraFacing {
  /// Get display name
  String get displayName {
    switch (this) {
      case CameraFacing.front:
        return 'Front Camera';
      case CameraFacing.rear:
        return 'Rear Camera';
    }
  }

  /// Get opposite facing
  CameraFacing get opposite {
    switch (this) {
      case CameraFacing.front:
        return CameraFacing.rear;
      case CameraFacing.rear:
        return CameraFacing.front;
    }
  }
}
