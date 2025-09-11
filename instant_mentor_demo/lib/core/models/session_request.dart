import 'package:equatable/equatable.dart';

class SessionRequest extends Equatable {
  final String id; // mentoring_sessions.id
  final String studentName;
  final String subject;
  final DateTime requestedAt;
  final String status; // pending / accepted / declined

  const SessionRequest({
    required this.id,
    required this.studentName,
    required this.subject,
    required this.requestedAt,
    required this.status,
  });

  SessionRequest copyWith({
    String? status,
  }) =>
      SessionRequest(
        id: id,
        studentName: studentName,
        subject: subject,
        requestedAt: requestedAt,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [id, studentName, subject, requestedAt, status];
}
