import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class WalletService {
  // Static demo balance for now since wallets table doesn't exist
  static double _demoBalance = 250.0;

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
      print('Wallet table not found, using demo balance: $_demoBalance');
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
      // Try to insert transaction record if table exists
      await _supabase.from('wallet_transactions').insert({
        'txn_id': txnId,
        'user_id': userId,
        'amount': amount,
        'status': 'pending',
      });

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
            .update({'status': 'completed'}).eq('txn_id', txnId);
      } catch (rpcError) {
        // RPC doesn't exist, just update demo balance
        _demoBalance += amount;
        print('Updated demo balance to: $_demoBalance');
      }
    } catch (e) {
      // Tables don't exist, just update demo balance
      _demoBalance += amount;
      print('Tables not found, updated demo balance to: $_demoBalance');
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
      print('Withdrawal requested: $amount, new balance: $_demoBalance');
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
}
