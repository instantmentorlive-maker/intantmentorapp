import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/session.dart' as app_session;
import 'user_provider.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Live sync: Subscribe to Supabase Realtime for mentoring_sessions and
/// invalidate session providers whenever relevant changes occur.
final sessionsRealtimeSyncProvider = Provider<void>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(userProvider);

  // No user => nothing to subscribe to (demo mode uses local provider which is already reactive)
  if (user == null) return;

  // Create a channel for the table
  final channel = client.channel('public:mentoring_sessions');

  bool isRelevant(Map<String, dynamic>? record) {
    if (record == null) return false;
    final sid = record['student_id']?.toString();
    final mid = record['mentor_id']?.toString();
    return sid == user.id || mid == user.id;
  }

  void touch() {
    // Invalidate the providers to recompute the lists
    ref.invalidate(simpleUpcomingSessionsProvider);
    ref.invalidate(upcomingSessionsProvider);
    ref.invalidate(allSessionsProvider);
  }

  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'mentoring_sessions',
        callback: (payload) {
          if (isRelevant(payload.newRecord)) {
            touch();
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'mentoring_sessions',
        callback: (payload) {
          if (isRelevant(payload.newRecord) || isRelevant(payload.oldRecord)) {
            touch();
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'mentoring_sessions',
        callback: (payload) {
          if (isRelevant(payload.oldRecord)) {
            touch();
          }
        },
      )
      .subscribe();

  // Clean up when provider is disposed or user changes
  ref.onDispose(() {
    try {
      client.removeChannel(channel);
    } catch (_) {}
  });
});

/// Provider for upcoming sessions for the current user
final upcomingSessionsProvider =
    FutureProvider<List<app_session.Session>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final user = ref.watch(userProvider);

  // IMPORTANT: Wait for demo sessions to load from SharedPreferences
  // before reading them, otherwise we'll get empty list on first load!
  final demoSessionsNotifier = ref.read(demoSessionsProvider.notifier);
  // Safeguard: avoid indefinite wait in case SharedPreferences is slow/blocked
  int attempts = 0;
  while (!demoSessionsNotifier.isLoaded && attempts < 80) {
    if (attempts % 5 == 0) {
      print('⏳ Waiting for demo sessions to load... attempt=${attempts + 1}');
    }
    await Future.delayed(const Duration(milliseconds: 50));
    attempts++;
  }
  if (!demoSessionsNotifier.isLoaded) {
    print(
        '⚠️ Timeout waiting for demo sessions to load, continuing with current state');
  }

  // Always consider demo sessions (they're stored locally).
  // Use watch so this provider recomputes whenever demo sessions change
  final demoSessionsAll = ref.watch(demoSessionsProvider);
  final now = DateTime.now();
  final visibleFrom = now.subtract(const Duration(minutes: 5));
  final demoSessionsUpcoming = demoSessionsAll
      .where((session) =>
          // Allow sessions that started within the last 5 minutes so they still appear
          session.scheduledTime.isAfter(visibleFrom) &&
          (session.status == app_session.SessionStatus.pending ||
              session.status == app_session.SessionStatus.confirmed))
      .toList();
  demoSessionsUpcoming
      .sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

  // If there's no authenticated user, return ALL demo sessions (regardless of student ID)
  // This ensures newly booked demo sessions appear in upcoming sessions
  if (user == null) {
    demoSessionsUpcoming
        .sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    print(
        '📅 upcomingSessionsProvider: Returning ${demoSessionsUpcoming.length} demo sessions');
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
        // Include sessions that started within the last 5 minutes
        .gte('scheduled_time', visibleFrom.toIso8601String())
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

    // Include demo sessions for the current user OR demo sessions with standard demo IDs
    // This ensures that sessions booked while unauthenticated still show up after login
    final demoSessions = ref
        .read(demoSessionsProvider)
        .where((session) =>
            // Include if user matches OR if demo session has demo IDs
            (session.studentId == user.id ||
                session.mentorId == user.id ||
                session.studentId == 'demo_student_id' ||
                session.mentorId == 'demo_mentor_id') &&
            session.scheduledTime.isAfter(visibleFrom) &&
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

    // Ensure sorted by soonest first
    allSessions.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
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

    // Include demo sessions for the current user OR show all demo sessions to authenticated users
    final demoSessions = ref.read(demoSessionsProvider).toList();

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
  final user = ref.watch(userProvider);

  // IMPORTANT: Wait for demo sessions to load from SharedPreferences
  // before reading them, otherwise we'll get empty list on first load!
  final demoSessionsNotifier = ref.read(demoSessionsProvider.notifier);
  // Safeguard: avoid indefinite wait in case SharedPreferences is slow/blocked
  int attempts = 0;
  while (!demoSessionsNotifier.isLoaded && attempts < 80) {
    if (attempts % 5 == 0) {
      print('⏳ Waiting for demo sessions to load... attempt=${attempts + 1}');
    }
    await Future.delayed(const Duration(milliseconds: 50));
    attempts++;
  }
  if (!demoSessionsNotifier.isLoaded) {
    print(
        '⚠️ Timeout waiting for demo sessions to load, continuing with current state');
  }

  // Always consider demo sessions (they're stored locally).
  // Use watch so this provider recomputes whenever demo sessions change
  final demoSessionsAll = ref.watch(demoSessionsProvider);
  print('📅 DEBUG: Total demo sessions in provider: ${demoSessionsAll.length}');
  for (var session in demoSessionsAll) {
    print(
        '   Session: ${session.id}, Scheduled: ${session.scheduledTime}, Status: ${session.status}');
  }

  final now = DateTime.now();
  final visibleFrom = now.subtract(const Duration(minutes: 5));
  print('📅 DEBUG: Current time: $now');
  print('📅 DEBUG: Visible from: $visibleFrom');
  print('🔥 HOT RELOAD TEST: ${DateTime.now().millisecondsSinceEpoch}');

  final demoSessionsUpcoming = demoSessionsAll.where((session) {
    print('📅 DEBUG: Checking session ${session.id}:');
    print('   Scheduled: ${session.scheduledTime}');
    print('   Status: ${session.status}');
    print(
        '   Is after visibleFrom: ${session.scheduledTime.isAfter(visibleFrom)}');
    print(
        '   Status is pending/confirmed: ${session.status == app_session.SessionStatus.pending || session.status == app_session.SessionStatus.confirmed}');

    final isAfterTime = session.scheduledTime.isAfter(visibleFrom);
    final hasValidStatus =
        session.status == app_session.SessionStatus.pending ||
            session.status == app_session.SessionStatus.confirmed;
    final shouldInclude = isAfterTime && hasValidStatus;
    print('   Should include: $shouldInclude');

    return shouldInclude;
  }).toList();

  print('📅 DEBUG: Filtered upcoming sessions: ${demoSessionsUpcoming.length}');

  // Always show demo sessions for testing purposes
  // Filter sessions to show both user-specific and demo sessions
  final List<app_session.Session> allUpcomingSessions = [];

  // Add demo sessions
  allUpcomingSessions.addAll(demoSessionsUpcoming);

  if (user != null) {
    print('📅 User authenticated: ${user.email}, Role: ${user.role}');
    // For authenticated users, also include their real sessions if any
    // (This would typically come from Supabase, but for demo we just use demo sessions)
  }

  allUpcomingSessions
      .sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  print(
      '📅 simpleUpcomingSessionsProvider: Returning ${allUpcomingSessions.length} total sessions');
  print('Session details:');
  for (var session in allUpcomingSessions) {
    print('   ${session.id}: ${session.scheduledTime} - ${session.subject}');
  }
  return allUpcomingSessions;
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
        print(
            'Session details: ${demoSession.scheduledTime} with ${demoSession.mentorId}');

        // Force refresh upcoming sessions to ensure immediate UI update
        await Future.delayed(const Duration(milliseconds: 100));
        print(
            '📅 Re-checking upcoming sessions after demo session creation...');
        final currentSessions = _ref.read(demoSessionsProvider);
        print('Total demo sessions now: ${currentSessions.length}');

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

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  DemoSessionsNotifier() : super([]) {
    print('🎬 DemoSessionsNotifier: Constructor called - initializing...');
    _loadFromPrefs();
  }

  /// Backup current demo sessions to Supabase user_profiles.preferences.demo_sessions
  /// to survive browser storage clears or origin changes. Best-effort; non-fatal on error.
  Future<void> _backupToRemote() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        // No authenticated user to bind backup to
        return;
      }

      // Fetch existing preferences then merge demo_sessions
      final profile = await client
          .from('user_profiles')
          .select('preferences')
          .eq('user_id', user.id)
          .maybeSingle();

      final existingPrefs = (profile != null && profile['preferences'] != null)
          ? Map<String, dynamic>.from(profile['preferences'] as Map)
          : <String, dynamic>{};

      final sessionsJson = state.map((s) => s.toJson()).toList();
      existingPrefs['demo_sessions'] = sessionsJson;

      await client
          .from('user_profiles')
          .update({'preferences': existingPrefs}).eq('user_id', user.id);

      print('☁️ Backed up ${state.length} demo sessions to Supabase');
    } catch (e) {
      print('⚠️ Failed to backup demo sessions to Supabase: $e');
    }
  }

  /// Restore demo sessions from Supabase user_profiles.preferences.demo_sessions
  /// when local storage is empty. Best-effort; non-fatal on error.
  Future<void> restoreFromRemoteIfEmpty() async {
    try {
      if (state.isNotEmpty) return; // Nothing to do
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final profile = await client
          .from('user_profiles')
          .select('preferences')
          .eq('user_id', user.id)
          .maybeSingle();

      final prefs = (profile != null && profile['preferences'] != null)
          ? Map<String, dynamic>.from(profile['preferences'] as Map)
          : null;
      final remote = prefs != null ? prefs['demo_sessions'] : null;

      if (remote is List) {
        final restored = remote
            .whereType<Map>()
            .map((e) => app_session.Session.fromJson(
                Map<String, dynamic>.from(e as Map<String, dynamic>)))
            .toList();
        if (restored.isNotEmpty) {
          state = restored;
          print('☁️ Restored ${state.length} demo sessions from Supabase');
          await _saveToPrefs();
        }
      }
    } catch (e) {
      print('⚠️ Failed to restore demo sessions from Supabase: $e');
    }
  }

  void _addTestSessions() {
    print('🧪 Adding test sessions for demo purposes...');

    final now = DateTime.now();
    final testSessions = [
      // Mentor sessions (for mentor dashboard)
      app_session.Session(
        id: 'test_session_1',
        studentId: 'demo_student_alice',
        mentorId: 'mentor_demo',
        subject: 'Mathematics - Calculus',
        scheduledTime: now.add(const Duration(hours: 2)),
        durationMinutes: 60,
        amount: 50.0,
        status: app_session.SessionStatus.confirmed,
        createdAt: now.subtract(const Duration(days: 1)),
        notes: 'Help with understanding derivative rules and applications',
        meetingLink: 'https://meet.example.com/test-1',
      ),
      app_session.Session(
        id: 'test_session_2',
        studentId: 'demo_student_bob',
        mentorId: 'mentor_demo',
        subject: 'Physics - Quantum Mechanics',
        scheduledTime: now.add(const Duration(days: 1, hours: 4)),
        durationMinutes: 90,
        amount: 75.0,
        status: app_session.SessionStatus.confirmed,
        createdAt: now.subtract(const Duration(hours: 8)),
        notes: 'Review quantum tunneling and wave-particle duality',
        meetingLink: 'https://meet.example.com/test-2',
      ),
      // Student sessions (for student dashboard)
      app_session.Session(
        id: 'test_session_student_1',
        studentId: 'student_demo',
        mentorId: 'demo_mentor_sarah',
        subject: 'Chemistry - Organic Chemistry',
        scheduledTime: now.add(const Duration(hours: 3)),
        durationMinutes: 60,
        amount: 60.0,
        status: app_session.SessionStatus.confirmed,
        createdAt: now.subtract(const Duration(hours: 12)),
        notes: 'Practice naming organic compounds and reaction mechanisms',
        meetingLink: 'https://meet.example.com/student-test-1',
      ),
      app_session.Session(
        id: 'test_session_student_2',
        studentId: 'student_demo',
        mentorId: 'demo_mentor_raj',
        subject: 'Computer Science - Data Structures',
        scheduledTime: now.add(const Duration(days: 1, hours: 2)),
        durationMinutes: 120,
        amount: 100.0,
        status: app_session.SessionStatus.confirmed,
        createdAt: now.subtract(const Duration(hours: 6)),
        notes: 'Binary trees, heaps, and graph algorithms implementation',
        meetingLink: 'https://meet.example.com/student-test-2',
      ),
    ];

    // Force add test sessions regardless of existing state
    print(
        '🎯 Force adding ${testSessions.length} test sessions (mentor + student)');
    state = testSessions;
    _saveToPrefs();
    print(
        '✅ Test sessions added successfully! Current state has ${state.length} sessions');
  }

  Future<void> _loadFromPrefs() async {
    try {
      print(
          '🔄 DemoSessionsNotifier: Loading sessions from SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      print(
          '📦 Raw data from prefs: ${raw?.substring(0, raw.length > 100 ? 100 : raw.length)}...');

      if (raw == null || raw.isEmpty) {
        print('⚠️ No demo sessions found in SharedPreferences');
        // Try to restore from remote backup first
        await restoreFromRemoteIfEmpty();
        _isLoaded = true; // Mark as loaded even if no data found
        if (state.isEmpty) {
          _addTestSessions(); // Add test sessions only if nothing to restore
        }
        return;
      }

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      print('📊 Decoded ${decoded.length} sessions from JSON');

      final sessions = decoded
          .map((e) => app_session.Session.fromJson(
              Map<String, dynamic>.from(e as Map<String, dynamic>)))
          .toList();

      // Filter out very old sessions (keep recent ones for persistence)
      final now = DateTime.now();
      final validSessions = sessions.where((session) {
        final daysSinceCreated = now.difference(session.createdAt).inDays;
        final isValid = daysSinceCreated <= 30; // Keep sessions for 30 days
        print(
            '   Session ${session.id}: created $daysSinceCreated days ago, isValid: $isValid');
        return isValid;
      }).toList();

      state = validSessions;
      _isLoaded = true;
      print(
          '✅ DemoSessionsNotifier: Loaded ${validSessions.length} demo sessions');
      print(
          '   (${sessions.length - validSessions.length} old sessions cleaned up)');

      // Log each loaded session
      for (var session in validSessions) {
        print(
            '   📅 ${session.id}: ${session.scheduledTime} (${session.status})');
      }

      if (sessions.length != validSessions.length) {
        // Save cleaned up sessions back to preferences
        await _saveToPrefs();
      }

      // Also perform a best-effort backup to remote when user is authenticated
      // (don’t await to avoid blocking app startup).
      // ignore: unawaited_futures
      _backupToRemote();
    } catch (e, stackTrace) {
      // If anything fails, keep state as empty but don't crash
      _isLoaded =
          true; // Mark as loaded even if failed, so we don't block forever
      print('❌ Failed to load demo sessions from prefs: $e');
      print('Stack trace: $stackTrace');
      // Try to restore from remote on failure as well
      await restoreFromRemoteIfEmpty();
      if (state.isEmpty) {
        _addTestSessions(); // Add test sessions if loading/restoring failed
      }
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      print('💾 Saving ${state.length} demo sessions to SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(state.map((s) => s.toJson()).toList());
      await prefs.setString(_prefsKey, encoded);
      print('✅ Successfully saved to key: $_prefsKey');
      // Best-effort remote backup (do not await)
      // ignore: unawaited_futures
      _backupToRemote();
    } catch (e) {
      print('❌ Failed to save demo sessions to prefs: $e');
    }
  }

  void addSession(app_session.Session session) {
    print('✅ DemoSessionsNotifier: Adding session ${session.id}');
    print('   Before: ${state.length} sessions');
    state = [...state, session];
    print('   After: ${state.length} sessions');
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

  /// Force reset and add test sessions for demo purposes
  void forceAddTestSessions() {
    print('🔄 Force resetting and adding test sessions...');
    clearSessions();
    _addTestSessions();
  }

  /// Add test sessions and ensure they're shown for mentors
  void ensureTestSessions() {
    if (state.isEmpty) {
      print('🎯 No sessions found, adding test sessions...');
      _addTestSessions();
    } else {
      print('✅ Sessions already exist: ${state.length}');
      for (var session in state) {
        print(
            '   - ${session.subject} with ${session.studentId} (mentor: ${session.mentorId})');
      }
    }
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
    // Best-effort remote backup after migration
    // ignore: unawaited_futures
    _backupToRemote();
  }
}
