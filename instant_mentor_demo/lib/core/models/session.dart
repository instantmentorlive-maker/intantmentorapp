enum SessionStatus { pending, confirmed, inProgress, completed, cancelled }

class Session {
  final String id;
  final String studentId;
  final String mentorId;
  final String subject;
  final DateTime scheduledTime;
  final int durationMinutes;
  final double amount;
  final SessionStatus status;
  final String? notes;
  final List<String> attachments;
  final DateTime createdAt;
  final String? meetingLink;

  const Session({
    required this.id,
    required this.studentId,
    required this.mentorId,
    required this.subject,
    required this.scheduledTime,
    required this.durationMinutes,
    required this.amount,
    required this.status,
    this.notes,
    this.attachments = const [],
    required this.createdAt,
    this.meetingLink,
  });

  Session copyWith({
    String? id,
    String? studentId,
    String? mentorId,
    String? subject,
    DateTime? scheduledTime,
    int? durationMinutes,
    double? amount,
    SessionStatus? status,
    String? notes,
    List<String>? attachments,
    DateTime? createdAt,
    String? meetingLink,
  }) {
    return Session(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      mentorId: mentorId ?? this.mentorId,
      subject: subject ?? this.subject,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      meetingLink: meetingLink ?? this.meetingLink,
    );
  }
}

class SessionRequest {
  final String id;
  final String studentId;
  final String studentName;
  final String mentorId;
  final String subject;
  final DateTime preferredTime;
  final int durationMinutes;
  final double amount;
  final String message;
  final DateTime createdAt;
  final bool isUrgent;

  const SessionRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.mentorId,
    required this.subject,
    required this.preferredTime,
    required this.durationMinutes,
    required this.amount,
    required this.message,
    required this.createdAt,
    this.isUrgent = false,
  });
}

class Progress {
  final String studentId;
  final String subject;
  final double completionPercentage;
  final int totalSessions;
  final int completedSessions;
  final List<String> weakAreas;
  final Map<String, double> topicProgress;
  final DateTime lastUpdated;

  const Progress({
    required this.studentId,
    required this.subject,
    required this.completionPercentage,
    required this.totalSessions,
    required this.completedSessions,
    required this.weakAreas,
    required this.topicProgress,
    required this.lastUpdated,
  });
}
