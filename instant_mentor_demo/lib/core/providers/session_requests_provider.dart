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

  // Initial fetch
  Future<List<SessionRequest>> fetch() async {
    final rows = await _supabase
        .from('mentoring_sessions')
        .select(
            'id, student:student_id(full_name), subject, created_at, status')
        .eq('mentor_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return rows.map<SessionRequest>((r) {
      final student = r['student'] as Map<String, dynamic>?;
      return SessionRequest(
        id: r['id'] as String,
        studentName:
            (student != null ? (student['full_name'] ?? 'Student') : 'Student')
                .toString(),
        subject: (r['subject'] ?? 'General').toString(),
        requestedAt: DateTime.parse(r['created_at'] as String),
        status: (r['status'] ?? 'pending').toString(),
      );
    }).toList();
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
          value: userId),
      callback: (payload) async {
        // On any change refetch list
        ref.invalidate(sessionRequestsProvider);
      },
    )
    ..subscribe();

  ref.onDispose(() {
    _supabase.removeChannel(channel);
  });
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
