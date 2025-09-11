import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../realtime/messaging_service.dart';
import '../models/user.dart';
import 'mentor_provider.dart';

/// Enhanced mentor presence information
class MentorPresence {
  final String mentorId;
  final PresenceStatus status;
  final String? customStatus;
  final DateTime lastSeen;
  final bool isAcceptingRequests;
  final int activeSessionsCount;
  final Map<String, dynamic>? availability;

  const MentorPresence({
    required this.mentorId,
    required this.status,
    this.customStatus,
    required this.lastSeen,
    this.isAcceptingRequests = true,
    this.activeSessionsCount = 0,
    this.availability,
  });

  bool get isOnline => status == PresenceStatus.online;
  bool get isAvailable =>
      isOnline && isAcceptingRequests && activeSessionsCount < 3;

  String get displayStatus {
    if (!isOnline) return 'Offline';
    if (!isAcceptingRequests) return 'Not Accepting Requests';
    if (activeSessionsCount >= 3) return 'Busy';
    if (customStatus != null) return customStatus!;
    return 'Available';
  }

  MentorPresence copyWith({
    String? mentorId,
    PresenceStatus? status,
    String? customStatus,
    DateTime? lastSeen,
    bool? isAcceptingRequests,
    int? activeSessionsCount,
    Map<String, dynamic>? availability,
  }) {
    return MentorPresence(
      mentorId: mentorId ?? this.mentorId,
      status: status ?? this.status,
      customStatus: customStatus ?? this.customStatus,
      lastSeen: lastSeen ?? this.lastSeen,
      isAcceptingRequests: isAcceptingRequests ?? this.isAcceptingRequests,
      activeSessionsCount: activeSessionsCount ?? this.activeSessionsCount,
      availability: availability ?? this.availability,
    );
  }
}

/// Real-time mentor presence provider
final mentorPresenceProvider =
    StreamProvider<Map<String, MentorPresence>>((ref) async* {
  // Initial empty state
  yield {};

  // Mock real-time updates for demonstration
  await Future.delayed(const Duration(seconds: 1));

  // Get all mentors
  final mentors = ref.read(mentorsProvider);

  // Create mock presence data with real-time updates
  Map<String, MentorPresence> presences = {};

  for (final mentor in mentors) {
    presences[mentor.id] = MentorPresence(
      mentorId: mentor.id,
      status:
          mentor.isAvailable ? PresenceStatus.online : PresenceStatus.offline,
      lastSeen: DateTime.now()
          .subtract(Duration(minutes: mentor.isAvailable ? 0 : 15)),
      isAcceptingRequests: mentor.isAvailable,
      activeSessionsCount: mentor.isAvailable ? (mentor.id.hashCode % 2) : 0,
      customStatus: _getCustomStatus(mentor),
    );
  }

  yield presences;

  // Simulate real-time updates every 30 seconds
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    // Update some mentors' status randomly
    for (final mentorId in presences.keys) {
      if (DateTime.now().millisecond % 4 == 0) {
        // 25% chance of update
        final currentPresence = presences[mentorId]!;
        final newStatus = _getRandomStatus();

        presences[mentorId] = currentPresence.copyWith(
          status: newStatus,
          lastSeen: DateTime.now(),
          isAcceptingRequests: newStatus == PresenceStatus.online,
          activeSessionsCount: newStatus == PresenceStatus.online
              ? (DateTime.now().millisecond % 3)
              : 0,
        );
      }
    }
    yield Map.from(presences);
  }
});

/// Get specific mentor presence
final mentorPresenceByIdProvider =
    Provider.family<MentorPresence?, String>((ref, mentorId) {
  final presences = ref.watch(mentorPresenceProvider);
  return presences.whenData((data) => data[mentorId]).value;
});

/// Available mentors with real-time presence
final availableMentorsWithPresenceProvider = Provider<List<Mentor>>((ref) {
  final mentors = ref.watch(mentorsProvider);
  final presencesAsync = ref.watch(mentorPresenceProvider);

  return presencesAsync.when(
    data: (presences) {
      return mentors.where((mentor) {
        final presence = presences[mentor.id];
        return presence?.isAvailable ?? mentor.isAvailable;
      }).toList();
    },
    loading: () => mentors.where((m) => m.isAvailable).toList(),
    error: (_, __) => mentors.where((m) => m.isAvailable).toList(),
  );
});

/// Online mentors count
final onlineMentorsCountProvider = Provider<int>((ref) {
  final presencesAsync = ref.watch(mentorPresenceProvider);

  return presencesAsync.when(
    data: (presences) => presences.values.where((p) => p.isOnline).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Available mentors count
final availableMentorsCountProvider = Provider<int>((ref) {
  final presencesAsync = ref.watch(mentorPresenceProvider);

  return presencesAsync.when(
    data: (presences) => presences.values.where((p) => p.isAvailable).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// Helper functions
String? _getCustomStatus(Mentor mentor) {
  final statuses = [
    null,
    'Teaching ${mentor.specializations.first}',
    'Available for quick questions',
    'Free trial sessions available',
    'Exam preparation specialist',
  ];
  return statuses[mentor.id.hashCode % statuses.length];
}

PresenceStatus _getRandomStatus() {
  final statuses = [
    PresenceStatus.online,
    PresenceStatus.online, // Higher chance of online
    PresenceStatus.online,
    PresenceStatus.away,
    PresenceStatus.busy,
    PresenceStatus.offline,
  ];
  return statuses[DateTime.now().millisecond % statuses.length];
}
