class SessionNote {
  final String id;
  final String title;
  final String content;
  final String mentorId;
  final String mentorName;
  final String subject;
  final DateTime date;
  final bool hasRecording;
  final bool isBookmarked;
  final List<String> topics;
  final String? recordingUrl;
  final String? homeworkAssigned;

  SessionNote({
    required this.id,
    required this.title,
    required this.content,
    required this.mentorId,
    required this.mentorName,
    required this.subject,
    required this.date,
    this.hasRecording = false,
    this.isBookmarked = false,
    required this.topics,
    this.recordingUrl,
    this.homeworkAssigned,
  });

  factory SessionNote.fromJson(Map<String, dynamic> json) {
    return SessionNote(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      mentorId: json['mentorId'],
      mentorName: json['mentorName'],
      subject: json['subject'],
      date: DateTime.parse(json['date']),
      hasRecording: json['hasRecording'] ?? false,
      isBookmarked: json['isBookmarked'] ?? false,
      topics: List<String>.from(json['topics'] ?? []),
      recordingUrl: json['recordingUrl'],
      homeworkAssigned: json['homeworkAssigned'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'mentorId': mentorId,
      'mentorName': mentorName,
      'subject': subject,
      'date': date.toIso8601String(),
      'hasRecording': hasRecording,
      'isBookmarked': isBookmarked,
      'topics': topics,
      'recordingUrl': recordingUrl,
      'homeworkAssigned': homeworkAssigned,
    };
  }

  SessionNote copyWith({
    String? id,
    String? title,
    String? content,
    String? mentorId,
    String? mentorName,
    String? subject,
    DateTime? date,
    bool? hasRecording,
    bool? isBookmarked,
    List<String>? topics,
    String? recordingUrl,
    String? homeworkAssigned,
  }) {
    return SessionNote(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      mentorId: mentorId ?? this.mentorId,
      mentorName: mentorName ?? this.mentorName,
      subject: subject ?? this.subject,
      date: date ?? this.date,
      hasRecording: hasRecording ?? this.hasRecording,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      topics: topics ?? this.topics,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      homeworkAssigned: homeworkAssigned ?? this.homeworkAssigned,
    );
  }
}
