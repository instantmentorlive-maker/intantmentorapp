import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

final isAdminProvider = FutureProvider<bool>((ref) async {
  final sp = ref.watch(supabaseProvider);
  final uid = sp.auth.currentUser?.id;
  if (uid == null) return false;
  // Query profile roles array for 'admin'
  final res = await sp
      .from('user_payment_profiles')
      .select('roles')
      .eq('uid', uid)
      .maybeSingle();
  final roles = (res?['roles'] as List?)?.cast<String>() ?? const [];
  return roles.contains('admin');
});

class AdminPayout {
  AdminPayout(
      {required this.id,
      required this.mentorId,
      required this.amountMinor,
      required this.status,
      required this.createdAt});
  final String id;
  final String mentorId;
  final int amountMinor;
  final String status;
  final DateTime createdAt;
}

class AdminRefundTx {
  AdminRefundTx(
      {required this.id,
      required this.sessionId,
      required this.amountMinor,
      required this.createdAt});
  final String id;
  final String sessionId;
  final int amountMinor;
  final DateTime createdAt;
}

class AdminBalancesSummary {
  AdminBalancesSummary({
    required this.walletAvailable,
    required this.walletLocked,
    required this.earningsAvailable,
    required this.earningsLocked,
    required this.platformRevenueNet,
  });
  final int walletAvailable;
  final int walletLocked;
  final int earningsAvailable;
  final int earningsLocked;
  final int platformRevenueNet;
}

final adminPayoutsProvider =
    FutureProvider.autoDispose<List<AdminPayout>>((ref) async {
  final sp = ref.watch(supabaseProvider);
  final rpc = await sp
      .rpc('admin_list_payouts', params: {'p_limit': 100, 'p_offset': 0});
  final list = (rpc as List).cast<Map<String, dynamic>>();
  return list
      .map((e) => AdminPayout(
            id: e['id'] as String,
            mentorId: e['mentor_id'] as String,
            amountMinor: (e['amount_minor'] as num).toInt(),
            status: e['status'] as String,
            createdAt: DateTime.parse(e['created_at'] as String),
          ))
      .toList();
});

final adminRefundsProvider =
    FutureProvider.autoDispose<List<AdminRefundTx>>((ref) async {
  final sp = ref.watch(supabaseProvider);
  final rpc = await sp
      .rpc('admin_list_refunds', params: {'p_limit': 100, 'p_offset': 0});
  final list = (rpc as List).cast<Map<String, dynamic>>();
  return list
      .map((e) => AdminRefundTx(
            id: e['id'] as String,
            sessionId: (e['session_id'] ?? '') as String,
            amountMinor: (e['amount'] as num).toInt(),
            createdAt: DateTime.parse(e['created_at'] as String),
          ))
      .toList();
});

final adminBalancesSummaryProvider =
    FutureProvider.autoDispose<AdminBalancesSummary>((ref) async {
  final sp = ref.watch(supabaseProvider);
  final res = await sp.rpc('admin_get_balances_summary');
  final j = (res as Map).cast<String, dynamic>();
  return AdminBalancesSummary(
    walletAvailable: (j['wallet_total_available'] as num).toInt(),
    walletLocked: (j['wallet_total_locked'] as num).toInt(),
    earningsAvailable: (j['earnings_total_available'] as num).toInt(),
    earningsLocked: (j['earnings_total_locked'] as num).toInt(),
    platformRevenueNet: (j['platform_revenue_net'] as num).toInt(),
  );
});

final adminReconStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final sp = ref.watch(supabaseProvider);
  final res = await sp.rpc('admin_get_reconciliation_stats');
  return (res as Map).cast<String, dynamic>();
});

class AdminAlert {
  AdminAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.details,
    required this.createdAt,
  });
  final String id;
  final String type;
  final String severity;
  final String message;
  final Map<String, dynamic> details;
  final DateTime createdAt;
}

final adminAlertsProvider = StreamProvider.autoDispose<List<AdminAlert>>((ref) {
  final sp = ref.watch(supabaseProvider);
  return sp
      .from('admin_alerts')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(100)
      .map((rows) => rows
          .map((e) => AdminAlert(
                id: e['id'] as String,
                type: (e['type'] ?? '') as String,
                severity: (e['severity'] ?? 'info') as String,
                message: (e['message'] ?? '') as String,
                details:
                    (e['details'] as Map?)?.cast<String, dynamic>() ?? const {},
                createdAt: DateTime.parse(e['created_at'] as String),
              ))
          .toList());
});
