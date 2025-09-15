import 'package:equatable/equatable.dart';

/// Represents a participant in the call (local or remote).
class Participant extends Equatable {
  final String id; // user id
  final String displayName;
  final bool isLocal;
  final bool audioEnabled;
  final bool videoEnabled;
  final bool screenSharing;
  final DateTime joinedAt;

  Participant({
    required this.id,
    required this.displayName,
    required this.isLocal,
    this.audioEnabled = true,
    this.videoEnabled = true,
    this.screenSharing = false,
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();

  Participant copyWith({
    String? id,
    String? displayName,
    bool? isLocal,
    bool? audioEnabled,
    bool? videoEnabled,
    bool? screenSharing,
    DateTime? joinedAt,
  }) {
    return Participant(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      isLocal: isLocal ?? this.isLocal,
      audioEnabled: audioEnabled ?? this.audioEnabled,
      videoEnabled: videoEnabled ?? this.videoEnabled,
      screenSharing: screenSharing ?? this.screenSharing,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        displayName,
        isLocal,
        audioEnabled,
        videoEnabled,
        screenSharing,
        joinedAt,
      ];
}
