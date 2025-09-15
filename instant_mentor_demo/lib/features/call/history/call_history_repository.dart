/// Supabase Call History Proposed Schema (execute once):
/// ---------------------------------------------------
/// create table call_history (
///   id uuid primary key default gen_random_uuid(),
///   call_id text not null,
///   caller_id text not null,
///   receiver_id text not null,
///   started_at timestamptz not null default now(),
///   accepted_at timestamptz,
///   ended_at timestamptz,
///   end_reason text,
///   duration_seconds int,
///   call_type text default 'video',
///   metadata jsonb,
///   constraint call_history_uniq unique(call_id)
/// );
///
/// Optional index for querying recent calls per user:
/// create index idx_call_history_user_time on call_history (caller_id, started_at desc);
/// create index idx_call_history_receiver_time on call_history (receiver_id, started_at desc);
/// ---------------------------------------------------
library;

import 'dart:async';
import '../../../core/services/supabase_service.dart';

class CallRecord {
  final String callId;
  final String callerId;
  final String receiverId;
  final DateTime startedAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;
  final String? endReason;
  final String callType;

  CallRecord({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.startedAt,
    this.acceptedAt,
    this.endedAt,
    this.endReason,
    this.callType = 'video',
  });

  int? get durationSeconds => endedAt?.difference(startedAt).inSeconds;

  Map<String, dynamic> toMap() => {
        'call_id': callId,
        'caller_id': callerId,
        'receiver_id': receiverId,
        'started_at': startedAt.toUtc().toIso8601String(),
        if (acceptedAt != null)
          'accepted_at': acceptedAt!.toUtc().toIso8601String(),
        if (endedAt != null) 'ended_at': endedAt!.toUtc().toIso8601String(),
        if (endReason != null) 'end_reason': endReason,
        'duration_seconds': durationSeconds,
        'call_type': callType,
      };

  CallRecord copyWith({
    DateTime? acceptedAt,
    DateTime? endedAt,
    String? endReason,
  }) =>
      CallRecord(
        callId: callId,
        callerId: callerId,
        receiverId: receiverId,
        startedAt: startedAt,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        endedAt: endedAt ?? this.endedAt,
        endReason: endReason ?? this.endReason,
        callType: callType,
      );
}

/// In-memory + extensible repository; can be backed by Supabase later.
class CallHistoryRepository {
  final _records = <String, CallRecord>{};
  final _updates = StreamController<CallRecord>.broadcast();
  Stream<CallRecord> get updates => _updates.stream;
  final _pending = <String>{};
  final _supabase = SupabaseService.instance;
  bool _syncing = false;

  void logCallStarted({
    required String callId,
    required String callerId,
    required String receiverId,
    String callType = 'video',
  }) {
    if (_records.containsKey(callId)) return;
    final record = CallRecord(
      callId: callId,
      callerId: callerId,
      receiverId: receiverId,
      startedAt: DateTime.now(),
      callType: callType,
    );
    _records[callId] = record;
    _updates.add(record);
  }

  void logAccepted(String callId) {
    final existing = _records[callId];
    if (existing == null) return;
    final updated = existing.copyWith(acceptedAt: DateTime.now());
    _records[callId] = updated;
    _updates.add(updated);
  }

  void logEnded(String callId, {String? reason}) {
    final existing = _records[callId];
    if (existing == null) return;
    final updated =
        existing.copyWith(endedAt: DateTime.now(), endReason: reason);
    _records[callId] = updated;
    _updates.add(updated);
    _pending.add(callId);
    // Fire and forget sync attempt (schedule in microtask to avoid blocking caller)
    scheduleMicrotask(_drainQueue);
  }

  List<CallRecord> recent({int limit = 25}) {
    final all = _records.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return all.take(limit).toList();
  }

  Future<void> _drainQueue() async {
    if (_syncing) return;
    if (!_supabase.isInitialized) return; // skip if not ready
    _syncing = true;
    try {
      while (_pending.isNotEmpty) {
        final id = _pending.first;
        final rec = _records[id];
        if (rec == null) {
          _pending.remove(id);
          continue;
        }
        try {
          final map = rec.toMap();
          await _supabase.client
              .from('call_history')
              .upsert(map, onConflict: 'call_id');
          _pending.remove(id);
        } catch (e) {
          break; // leave item in queue for later retry
        }
      }
    } finally {
      _syncing = false;
    }
  }

  /// Manual trigger (e.g. app lifecycle) to force sync
  Future<void> syncToRemote() => _drainQueue();

  void dispose() {
    _updates.close();
  }
}
