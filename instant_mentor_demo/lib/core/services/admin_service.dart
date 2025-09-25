import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AdminService wraps Supabase calls for admin operations.
class AdminService {
  final SupabaseClient _sb;
  AdminService(this._sb);

  // Mentor applications
  Stream<List<Map<String, dynamic>>> watchMentorApplications() {
    return _sb
        .from('mentor_applications')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows);
  }

  Future<void> reviewMentorApplication({
    required String id,
    required String status, // approved | rejected
    String? adminNotes,
  }) async {
    await _sb.from('mentor_applications').update({
      'status': status,
      'admin_notes': adminNotes,
      'reviewed_by': _sb.auth.currentUser?.id,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // Call logs
  Stream<List<Map<String, dynamic>>> watchCallLogs() {
    return _sb
        .from('call_logs')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows);
  }

  Future<void> logCallEvent(Map<String, dynamic> payload) async {
    try {
      await _sb.from('call_logs').insert(payload);
    } catch (e) {
      debugPrint('call log insert failed: $e');
    }
  }

  // Disputes
  Stream<List<Map<String, dynamic>>> watchDisputes() {
    return _sb
        .from('disputes')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows);
  }

  Future<void> updateDisputeStatus({
    required String id,
    required String status, // in_review | resolved | rejected | refunded
    String? resolution,
    num? refundAmount,
  }) async {
    await _sb.from('disputes').update({
      'status': status,
      'resolution': resolution,
      'refund_amount': refundAmount,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // Refunds
  Future<Map<String, dynamic>> processRefund({
    required String sessionId,
    required String studentId,
    required String mentorId,
    required num amount,
    String? reason,
  }) async {
    // Record admin refund request
    await _sb.from('admin_refunds').insert({
      'session_id': sessionId,
      'student_id': studentId,
      'mentor_id': mentorId,
      'amount': amount,
      'reason': reason,
      'status': 'pending',
      'created_by': _sb.auth.currentUser?.id,
    });

    // Execute atomic RPC if available
    final res = await _sb.rpc('refund_session_wallet', params: {
      'p_session_id': sessionId,
      'p_student_id': studentId,
      'p_mentor_id': mentorId,
      'p_amount': amount,
      'p_reason': reason ?? 'admin_refund',
    });

    // Mark admin_refunds as processed (best-effort)
    await _sb
        .from('admin_refunds')
        .update({
          'status': 'processed',
          'processed_at': DateTime.now().toIso8601String(),
        })
        .eq('session_id', sessionId)
        .eq('student_id', studentId)
        .eq('mentor_id', mentorId)
        .eq('status', 'pending');

    return (res as Map<String, dynamic>?) ?? {'status': 'processed'};
  }

  // Bans
  Stream<List<Map<String, dynamic>>> watchActiveBans() {
    return _sb
        .from('user_bans')
        .stream(primaryKey: ['id'])
        .eq('active', true)
        .map((rows) => rows);
  }

  // Refund requests / processed refunds
  Stream<List<Map<String, dynamic>>> watchRefunds() {
    return _sb
        .from('admin_refunds')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows);
  }

  Future<void> banUser({
    required String userId,
    required String reason,
  }) async {
    await _sb.from('user_bans').insert({
      'user_id': userId,
      'reason': reason,
      'active': true,
      'banned_by': _sb.auth.currentUser?.id,
    });
  }

  Future<void> liftBan({
    required String banId,
  }) async {
    await _sb.from('user_bans').update({
      'active': false,
      'lifted_at': DateTime.now().toIso8601String()
    }).eq('id', banId);
  }

  // GDPR helpers
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    final res =
        await _sb.rpc('export_user_data', params: {'p_user_id': userId});
    return (res as Map<String, dynamic>?) ?? {};
  }

  Future<void> deleteUserData(String userId) async {
    await _sb.rpc('delete_user_data', params: {'p_user_id': userId});
  }
}
