import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import '../services/supabase_service.dart'; // Not directly used here
import '../models/session_request.dart';
import 'auth_provider.dart';

final _supabase = Supabase.instance.client;

/// Stream provider of pending session requests for the authenticated mentor
final StreamProvider<List<SessionRequest>> sessionRequestsProvider =
    StreamProvider<List<SessionRequest>>((ref) async* {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.user == null) {
    yield const [];
    return;
  }

  final userId = auth.user!.id;

  try {
    // Get the mentor profile ID for this user with timeout
    final mentorProfile = await _supabase
        .from('mentor_profiles')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle()
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );

    if (mentorProfile == null) {
      // No mentor profile exists yet - return empty list (demo mode)
      print('📋 No mentor profile found, showing empty requests list');
      yield const [];
      return;
    }

    final mentorProfileId = mentorProfile['id'];

    // Initial fetch with timeout
    Future<List<SessionRequest>> fetch() async {
      try {
        final rows = await _supabase
            .from('mentoring_sessions')
            .select('id, subject, created_at, status, student_id')
            .eq('mentor_id', mentorProfileId)
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => [],
            );

        // Fetch student names for each session
        final List<SessionRequest> requests = [];
        for (final r in rows) {
          String studentName = 'Student';
          final studentId = r['student_id'] as String?;

          if (studentId != null) {
            try {
              final studentProfile = await _supabase
                  .from('user_profiles')
                  .select('full_name')
                  .eq('user_id', studentId)
                  .maybeSingle()
                  .timeout(
                    const Duration(seconds: 3),
                    onTimeout: () => null,
                  );

              if (studentProfile != null) {
                studentName =
                    (studentProfile['full_name'] ?? 'Student').toString();
              }
            } catch (e) {
              // If we can't fetch student name, use default
              studentName = 'Student';
            }
          }

          requests.add(SessionRequest(
            id: r['id'] as String,
            studentName: studentName,
            subject: (r['subject'] ?? 'General').toString(),
            requestedAt: DateTime.parse(r['created_at'] as String),
            status: (r['status'] ?? 'pending').toString(),
          ));
        }

        return requests;
      } catch (e) {
        print('❌ Error fetching session requests: $e');
        return [];
      }
    }

    // Emit initial
    yield await fetch();

    // Subscribe to realtime changes for this mentor's pending sessions
    final channel = _supabase.channel('public:mentoring_sessions')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'mentoring_sessions',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'mentor_id',
            value: mentorProfileId),
        callback: (payload) async {
          // On any change refetch list
          ref.invalidate(sessionRequestsProvider);
        },
      )
      ..subscribe();

    ref.onDispose(() {
      _supabase.removeChannel(channel);
    });
  } catch (e, st) {
    // If anything fails, yield empty list instead of hanging
    print('❌ Session requests provider error: $e');
    print('Stack trace: $st');
    yield const [];
  }
});

/// Mutation notifier for accepting / declining a session request
class SessionRequestActions extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> respond(
      {required String sessionId, required bool accept}) async {
    state = const AsyncLoading();
    try {
      await _supabase.from('mentoring_sessions').update(
          {'status': accept ? 'accepted' : 'declined'}).eq('id', sessionId);
      // Trigger refresh
      ref.invalidate(sessionRequestsProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Accept session and return the session ID for navigation to video call
  Future<String?> acceptAndGetSessionId(String sessionId) async {
    state = const AsyncLoading();
    try {
      await _supabase
          .from('mentoring_sessions')
          .update({'status': 'accepted'}).eq('id', sessionId);
      // Trigger refresh
      ref.invalidate(sessionRequestsProvider);
      state = const AsyncData(null);
      return sessionId;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}

final sessionRequestActionsProvider =
    AsyncNotifierProvider<SessionRequestActions, void>(
        () => SessionRequestActions());
