import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

final _supabase = Supabase.instance.client;

class WalletService {
  // Static demo balance for now since wallets table doesn't exist
  static double _demoBalance = 250.0;
  // Track processed transactions locally to avoid double-crediting in demo mode
  static final Set<String> _processedTxns = <String>{};

  /// Get current wallet balance for user
  Future<double> getBalance(String userId) async {
    try {
      final res = await _supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();

      if (res == null) return _demoBalance;
      return (res['balance'] as num?)?.toDouble() ?? _demoBalance;
    } catch (e) {
      // If wallets table doesn't exist, return demo balance
      debugPrint('Wallet table not found, using demo balance: $_demoBalance');
      return _demoBalance;
    }
  }

  /// Add money to wallet (demo implementation)
  Future<void> addMoney({
    required String userId,
    required double amount,
    required String txnId,
  }) async {
    try {
      // Idempotency check (local/demo): if already processed in this runtime, no-op
      if (_processedTxns.contains(txnId)) {
        return;
      }

      // Try to insert or ignore duplicate transaction record if table exists (server-side idempotency by txn_id)
      await _supabase.from('wallet_transactions').upsert({
        'txn_id': txnId,
        'user_id': userId,
        'amount': amount,
        'status': 'pending',
      }, onConflict: 'txn_id', ignoreDuplicates: true);

      // If a successful transaction with this txn_id already exists, treat as idempotent success
      try {
        final existing = await _supabase
            .from('wallet_transactions')
            .select('status')
            .eq('txn_id', txnId)
            .maybeSingle();
        if (existing != null && existing['status'] == 'success') {
          _processedTxns.add(txnId);
          return;
        }
      } catch (_) {
        // ignore read errors; continue best-effort
      }

      // Try to call RPC if it exists
      try {
        await _supabase.rpc('add_money_to_wallet', params: {
          'user_id': userId,
          'amount': amount,
          'txn_id': txnId,
        });

        // mark transaction success
        await _supabase
            .from('wallet_transactions')
            .update({'status': 'success'}).eq('txn_id', txnId);
        _processedTxns.add(txnId);
      } catch (rpcError) {
        // RPC doesn't exist, just update demo balance
        _demoBalance += amount;
        debugPrint('Updated demo balance to: $_demoBalance');
        _processedTxns.add(txnId);
        // Try to reflect success status if table exists
        try {
          await _supabase
              .from('wallet_transactions')
              .update({'status': 'success'}).eq('txn_id', txnId);
        } catch (_) {}
      }
    } catch (e) {
      // Tables don't exist, just update demo balance
      _demoBalance += amount;
      debugPrint('Tables not found, updated demo balance to: $_demoBalance');
      _processedTxns.add(txnId);
    }
  }

  /// Create a withdrawal request (demo implementation)
  Future<void> requestWithdrawal({
    required String userId,
    required double amount,
    required String bankAccountId,
  }) async {
    try {
      await _supabase.from('withdrawal_requests').insert({
        'user_id': userId,
        'amount': amount,
        'bank_account_id': bankAccountId,
        'status': 'pending',
      });
    } catch (e) {
      // Table doesn't exist, just simulate withdrawal
      _demoBalance -= amount;
      debugPrint('Withdrawal requested: $amount, new balance: $_demoBalance');
    }
  }

  /// Get transaction history (demo implementation)
  Future<List<Map<String, dynamic>>> getTransactionHistory(
      String userId) async {
    try {
      final res = await _supabase
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      // Return demo transaction history
      return [
        {
          'txn_id': 'demo_1',
          'amount': 500.0,
          'status': 'completed',
          'created_at': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'type': 'credit'
        },
        {
          'txn_id': 'demo_2',
          'amount': -100.0,
          'status': 'completed',
          'created_at': DateTime.now()
              .subtract(const Duration(days: 3))
              .toIso8601String(),
          'type': 'debit'
        }
      ];
    }
  }

  /// List recent transactions for a user (alias for compatibility)
  Future<List<Map<String, dynamic>>> listTransactions(String userId,
      {int limit = 20}) async {
    return getTransactionHistory(userId);
  }

  /// Charge a session incrementally (demo implementation). Records a transaction or updates demo balance.
  Future<void> chargeSession({
    required String sessionId,
    required String studentId,
    required String mentorId,
    required double amount,
    required String unit,
    required int quantity,
  }) async {
    try {
      await _supabase.from('wallet_transactions').insert({
        'txn_id': 'sess_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': studentId,
        'amount': -amount * quantity,
        'status': 'completed',
        'type': 'debit',
        'metadata': {
          'sessionId': sessionId,
          'mentorId': mentorId,
          'unit': unit,
          'quantity': quantity,
        }
      });
    } catch (_) {
      _demoBalance -= amount * quantity;
      debugPrint(
          'Session charge (demo): -$amount x$quantity. Balance: $_demoBalance');
    }
  }
}
