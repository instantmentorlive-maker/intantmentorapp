import 'participant.dart';

/// High-level descriptor of an active or historical call.
class CallSession {
  final String sessionId;
  final String createdBy;
  final DateTime createdAt;
  final List<Participant> participants;
  final bool group;
  final bool active;
  final DateTime? endedAt;

  CallSession({
    required this.sessionId,
    required this.createdBy,
    DateTime? createdAt,
    List<Participant>? participants,
    this.group = false,
    this.active = true,
    this.endedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        participants = participants ?? const [];

  CallSession copyWith({
    String? sessionId,
    String? createdBy,
    DateTime? createdAt,
    List<Participant>? participants,
    bool? group,
    bool? active,
    DateTime? endedAt,
  }) {
    return CallSession(
      sessionId: sessionId ?? this.sessionId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      participants: participants ?? this.participants,
      group: group ?? this.group,
      active: active ?? this.active,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}
