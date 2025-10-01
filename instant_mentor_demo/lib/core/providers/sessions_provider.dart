import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/session.dart' as app_session;
import 'user_provider.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider for upcoming sessions for the current user
final upcomingSessionsProvider =
    FutureProvider<List<app_session.Session>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final user = ref.watch(userProvider);

  // Always consider demo sessions (they're stored locally).
  final demoSessionsAll = ref.read(demoSessionsProvider);
  final demoSessionsUpcoming = demoSessionsAll
      .where((session) =>
          session.scheduledTime.isAfter(DateTime.now()) &&
          (session.status == app_session.SessionStatus.pending ||
              session.status == app_session.SessionStatus.confirmed))
      .toList();

  // If there's no authenticated user, return demo sessions only.
  if (user == null) {
    demoSessionsUpcoming
        .sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return demoSessionsUpcoming;
  }

  try {
    final response = await client
        .from('mentoring_sessions')
        .select('''
          *,
          mentors:mentor_id (
            id,
            name,
            avatar_url,
            specializations
          ),
          students:student_id (
            id,
            name,
            avatar_url
          )
        ''')
        .or('student_id.eq.${user.id},mentor_id.eq.${user.id}')
        .gte('scheduled_time', DateTime.now().toIso8601String())
        .inFilter('status', ['scheduled', 'confirmed', 'pending'])
        .order('scheduled_time', ascending: true);

    final dbSessions = response.map<app_session.Session>((sessionData) {
      return app_session.Session(
        id: sessionData['id'],
        studentId: sessionData['student_id'],
        mentorId: sessionData['mentor_id'],
        subject: sessionData['subject'] ?? 'General',
        scheduledTime: DateTime.parse(sessionData['scheduled_time']),
        durationMinutes: sessionData['duration_minutes'] ?? 60,
        amount: (sessionData['amount'] ?? 0.0).toDouble(),
        status: _parseSessionStatus(sessionData['status']),
        notes: sessionData['notes'],
        attachments: List<String>.from(sessionData['attachments'] ?? []),
        createdAt: DateTime.parse(sessionData['created_at']),
        meetingLink: sessionData['meeting_link'],
      );
    }).toList();

    // Include demo sessions for the current user
    final demoSessions = ref
        .read(demoSessionsProvider)
        .where((session) =>
            (session.studentId == user.id || session.mentorId == user.id) &&
            session.scheduledTime.isAfter(DateTime.now()) &&
            (session.status == app_session.SessionStatus.pending ||
                session.status == app_session.SessionStatus.confirmed))
        .toList();

    // Combine and sort all sessions
    final allSessions = [...dbSessions, ...demoSessions];
    allSessions.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    // Debug: print upcoming session ids and mentor mapping
    try {
      print('simpleUpcomingSessionsProvider -> returning sessions:');
      for (final s in allSessions) {
        print(
            '  session id=${s.id} mentorId=${s.mentorId} subject=${s.subject} scheduled=${s.scheduledTime.toIso8601String()}');
      }
    } catch (_) {}

    return allSessions;
  } catch (e) {
    print('Error fetching sessions: $e');
    return [];
  }
});

/// Provider for all sessions (completed and upcoming) for analytics
final allSessionsProvider =
    FutureProvider<List<app_session.Session>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final user = ref.watch(userProvider);

  // If no authenticated user, return local demo sessions (useful in demo mode)
  final demoSessionsAll = ref.read(demoSessionsProvider);
  if (user == null) {
    final demoSessions = demoSessionsAll.toList();
    demoSessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return demoSessions;
  }

  try {
    final response = await client
        .from('mentoring_sessions')
        .select('''
          *,
          mentors:mentor_id (
            id,
            name,
            avatar_url,
            specializations
          ),
          students:student_id (
            id,
            name,
            avatar_url
          )
        ''')
        .or('student_id.eq.${user.id},mentor_id.eq.${user.id}')
        .order('scheduled_time', ascending: false);

    final dbSessions = response.map<app_session.Session>((sessionData) {
      return app_session.Session(
        id: sessionData['id'],
        studentId: sessionData['student_id'],
        mentorId: sessionData['mentor_id'],
        subject: sessionData['subject'] ?? 'General',
        scheduledTime: DateTime.parse(sessionData['scheduled_time']),
        durationMinutes: sessionData['duration_minutes'] ?? 60,
        amount: (sessionData['amount'] ?? 0.0).toDouble(),
        status: _parseSessionStatus(sessionData['status']),
        notes: sessionData['notes'],
        attachments: List<String>.from(sessionData['attachments'] ?? []),
        createdAt: DateTime.parse(sessionData['created_at']),
        meetingLink: sessionData['meeting_link'],
      );
    }).toList();

    // Include demo sessions for the current user
    final demoSessions = ref
        .read(demoSessionsProvider)
        .where((session) =>
            session.studentId == user.id || session.mentorId == user.id)
        .toList();

    // Combine and sort all sessions by creation time (most recent first)
    final allSessions = [...dbSessions, ...demoSessions];
    allSessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return allSessions;
  } catch (e) {
    print('Error fetching all sessions: $e');
    return [];
  }
});

/// Simple provider for upcoming sessions without real-time updates (for now)
final realtimeUpcomingSessionsProvider =
    FutureProvider<List<app_session.Session>>((ref) async {
  // For now, let's use the simple provider to avoid stream issues
  return ref.watch(simpleUpcomingSessionsProvider.future);
});

/// Simple provider for upcoming sessions without real-time updates
final simpleUpcomingSessionsProvider =
    FutureProvider<List<app_session.Session>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final user = ref.watch(userProvider);

  // Always consider demo sessions (they're stored locally).
  final demoSessionsAll = ref.read(demoSessionsProvider);
  final demoSessionsUpcoming = demoSessionsAll
      .where((session) =>
          session.scheduledTime.isAfter(DateTime.now()) &&
          (session.status == app_session.SessionStatus.pending ||
              session.status == app_session.SessionStatus.confirmed))
      .toList();

  // If there's no authenticated user, return demo sessions only.
  if (user == null) {
    demoSessionsUpcoming
        .sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return demoSessionsUpcoming;
  }

  try {
    final response = await client
        .from('mentoring_sessions')
        .select()
        .or('student_id.eq.${user.id},mentor_id.eq.${user.id}')
        .gte('scheduled_time', DateTime.now().toIso8601String())
        .inFilter('status', ['scheduled', 'confirmed', 'pending']).order(
            'scheduled_time',
            ascending: true);

    final dbSessions = response.map<app_session.Session>((sessionData) {
      return app_session.Session(
        id: sessionData['id'],
        studentId: sessionData['student_id'],
        mentorId: sessionData['mentor_id'],
        subject: sessionData['subject'] ?? 'General',
        scheduledTime: DateTime.parse(sessionData['scheduled_time']),
        durationMinutes: sessionData['duration_minutes'] ?? 60,
        amount: (sessionData['amount'] ?? 0.0).toDouble(),
        status: _parseSessionStatus(sessionData['status']),
        notes: sessionData['notes'],
        attachments: List<String>.from(sessionData['attachments'] ?? []),
        createdAt: DateTime.parse(sessionData['created_at']),
        meetingLink: sessionData['meeting_link'],
      );
    }).toList();

    // Include demo sessions for the current user
    final demoSessions = ref
        .read(demoSessionsProvider)
        .where((session) =>
            (session.studentId == user.id || session.mentorId == user.id) &&
            session.scheduledTime.isAfter(DateTime.now()) &&
            (session.status == app_session.SessionStatus.pending ||
                session.status == app_session.SessionStatus.confirmed))
        .toList();

    // Combine and sort all sessions
    final allSessions = [...dbSessions, ...demoSessions];
    allSessions.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    return allSessions;
  } catch (e) {
    print('Error fetching sessions: $e');
    return [];
  }
});

/// Provider to create a new session
final sessionServiceProvider = Provider((ref) => SessionService(ref));

class SessionService {
  final Ref _ref;
  SessionService(this._ref);

  SupabaseClient get _client => _ref.read(supabaseClientProvider);

  Future<app_session.Session?> createSession({
    required String mentorId,
    required String studentId,
    required DateTime scheduledTime,
    required int durationMinutes,
    required double amount,
    String? subject,
    String? notes,
  }) async {
    try {
      print('Creating session with data:');
      print('mentorId: $mentorId');
      print('studentId: $studentId');
      print('scheduledTime: ${scheduledTime.toIso8601String()}');
      print('durationMinutes: $durationMinutes');
      print('amount: $amount');
      print('subject: ${subject ?? 'General'}');
      print('notes: $notes');

      // Check if this is a mock/demo mentor (starts with 'mentor_')
      final isMockMentor = mentorId.startsWith('mentor_');

      // Check if we have an authenticated user
      final currentUser = _client.auth.currentUser;
      print('Current authenticated user: ${currentUser?.id}');

      // If using mock mentor or no authenticated user, create a demo session without database interaction
      if (isMockMentor || currentUser == null) {
        print(
            'Using mock mentor or no authenticated user - creating demo session without database save');

        // Create a demo session object that looks like it was saved
        final demoSession = app_session.Session(
          id: 'demo_${DateTime.now().millisecondsSinceEpoch}',
          studentId: studentId,
          mentorId: mentorId,
          subject: subject ?? 'General',
          scheduledTime: scheduledTime,
          durationMinutes: durationMinutes,
          amount: amount,
          status: app_session.SessionStatus.pending,
          notes: notes,
          attachments: [],
          createdAt: DateTime.now(),
        );

        // Save the demo session to the local provider
        _ref.read(demoSessionsProvider.notifier).addSession(demoSession);

        // Invalidate the upcoming sessions providers to refresh the UI
        _ref.invalidate(upcomingSessionsProvider);
        _ref.invalidate(simpleUpcomingSessionsProvider);
        _ref.invalidate(allSessionsProvider);

        print('Demo session created successfully: ${demoSession.id}');
        return demoSession;
      }

      // If we have an authenticated user and real mentor, proceed with database operation
      final sessionData = {
        'mentor_id': mentorId,
        'student_id': currentUser.id,
        'scheduled_time': scheduledTime.toIso8601String(),
        'duration_minutes': durationMinutes,
        'amount': amount,
        'subject': subject ?? 'General',
        'notes': notes,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      print('Session data to insert: $sessionData');

      final response = await _client
          .from('mentoring_sessions')
          .insert(sessionData)
          .select()
          .single();

      print('Session created successfully: $response');

      // Invalidate the upcoming sessions provider to refresh the UI
      _ref.invalidate(upcomingSessionsProvider);
      _ref.invalidate(simpleUpcomingSessionsProvider);
      _ref.invalidate(allSessionsProvider);

      return app_session.Session(
        id: response['id'],
        studentId: response['student_id'],
        mentorId: response['mentor_id'],
        subject: response['subject'] ?? 'General',
        scheduledTime: DateTime.parse(response['scheduled_time']),
        durationMinutes: response['duration_minutes'] ?? 60,
        amount: (response['amount'] ?? 0.0).toDouble(),
        status: _parseSessionStatus(response['status']),
        notes: response['notes'],
        attachments: List<String>.from(response['attachments'] ?? []),
        createdAt: DateTime.parse(response['created_at']),
        meetingLink: response['meeting_link'],
      );
    } catch (e, stackTrace) {
      print('Error creating session: $e');
      print('Stack trace: $stackTrace');
      if (e is PostgrestException) {
        print('Postgrest error details:');
        print('Message: ${e.message}');
        print('Details: ${e.details}');
        print('Hint: ${e.hint}');
        print('Code: ${e.code}');
      }
      return null;
    }
  }

  Future<bool> updateSessionStatus(
      String sessionId, app_session.SessionStatus status) async {
    try {
      await _client.from('mentoring_sessions').update({
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);

      // Invalidate providers to refresh the UI
      _ref.invalidate(upcomingSessionsProvider);
      _ref.invalidate(allSessionsProvider);

      return true;
    } catch (e) {
      print('Error updating session status: $e');
      return false;
    }
  }
}

app_session.SessionStatus _parseSessionStatus(String? status) {
  switch (status?.toLowerCase()) {
    case 'pending':
      return app_session.SessionStatus.pending;
    case 'confirmed':
    case 'scheduled':
      return app_session.SessionStatus.confirmed;
    case 'in_progress':
    case 'inprogress':
      return app_session.SessionStatus.inProgress;
    case 'completed':
      return app_session.SessionStatus.completed;
    case 'cancelled':
      return app_session.SessionStatus.cancelled;
    default:
      return app_session.SessionStatus.pending;
  }
}

/// State provider for demo sessions (not persisted to database)
final demoSessionsProvider =
    StateNotifierProvider<DemoSessionsNotifier, List<app_session.Session>>(
        (ref) {
  return DemoSessionsNotifier();
});

class DemoSessionsNotifier extends StateNotifier<List<app_session.Session>> {
  static const _prefsKey =
      'demo_sessions_v2_persistent'; // Updated key for better persistence

  DemoSessionsNotifier() : super([]) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final sessions = decoded
          .map((e) => app_session.Session.fromJson(
              Map<String, dynamic>.from(e as Map<String, dynamic>)))
          .toList();

      // Filter out very old sessions (keep recent ones for persistence)
      final now = DateTime.now();
      final validSessions = sessions.where((session) {
        final daysSinceCreated = now.difference(session.createdAt).inDays;
        return daysSinceCreated <= 30; // Keep sessions for 30 days
      }).toList();

      state = validSessions;
      if (sessions.length != validSessions.length) {
        // Save cleaned up sessions back to preferences
        _saveToPrefs();
      }
      print(
          'DemoSessionsNotifier: Loaded ${validSessions.length} demo sessions (${sessions.length - validSessions.length} old sessions cleaned up)');
    } catch (e) {
      // If anything fails, keep state as empty but don't crash
      print('Failed to load demo sessions from prefs: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(state.map((s) => s.toJson()).toList());
      await prefs.setString(_prefsKey, encoded);
    } catch (e) {
      print('Failed to save demo sessions to prefs: $e');
    }
  }

  void addSession(app_session.Session session) {
    state = [...state, session];
    _saveToPrefs();
  }

  void removeSession(String sessionId) {
    state = state.where((s) => s.id != sessionId).toList();
    _saveToPrefs();
  }

  void clearSessions() {
    state = [];
    _saveToPrefs();
  }

  /// If the user logs in after creating demo sessions, migrate any demo
  /// sessions (created with a demo student id) to the authenticated user id
  /// so they appear in the user's upcoming sessions after relogin.
  void migrateSessionsToUser(String userId) {
    final migrated = state.map((s) {
      if (s.studentId.startsWith('demo_student_')) {
        return s.copyWith(studentId: userId);
      }
      return s;
    }).toList();

    state = migrated;
    _saveToPrefs();
  }
}
