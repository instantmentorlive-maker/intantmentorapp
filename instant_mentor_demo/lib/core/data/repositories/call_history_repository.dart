import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/call/models/call_history.dart';

/// Repository for managing call history data in Supabase
class CallHistoryRepository {
  CallHistoryRepository(this._supabase);

  final SupabaseClient _supabase;
  static const String _tableName = 'call_history';

  /// Save a call to history
  Future<void> saveCall(CallHistory callHistory) async {
    try {
      await _supabase.from(_tableName).insert(callHistory.toJson());
    } catch (e) {
      throw Exception('Failed to save call history: $e');
    }
  }

  /// Get call history for a user
  Future<List<CallHistory>> getCallHistory({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .or('caller_id.eq.$userId,callee_id.eq.$userId')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => CallHistory.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get call history: $e');
    }
  }

  /// Delete a call from history
  Future<void> deleteCall(String callId) async {
    try {
      await _supabase.from(_tableName).delete().eq('id', callId);
    } catch (e) {
      throw Exception('Failed to delete call: $e');
    }
  }

  /// Clear all call history for a user
  Future<void> clearHistory(String userId) async {
    try {
      await _supabase
          .from(_tableName)
          .delete()
          .or('caller_id.eq.$userId,callee_id.eq.$userId');
    } catch (e) {
      throw Exception('Failed to clear call history: $e');
    }
  }
}

/// Provider for call history repository
final callHistoryRepositoryProvider = Provider<CallHistoryRepository>((ref) {
  return CallHistoryRepository(Supabase.instance.client);
});
