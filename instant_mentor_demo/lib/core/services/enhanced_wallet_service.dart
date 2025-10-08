import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

import '../models/payment_models.dart';

/// Enhanced wallet service implementing the payments architecture
/// Provides wallet operations, transaction management, and balance tracking
class EnhancedWalletService {
  static final _uuid = Uuid();
  static final _supabase = Supabase.instance.client;

  // =============================================================================
  // WALLET OPERATIONS
  // =============================================================================

  /// Get user's wallet with available and locked balances
  static Future<EnhancedWallet> getWallet(String userId) async {
    try {
      final response =
          await _supabase.from('wallets').select().eq('uid', userId).single();

      return EnhancedWallet.fromMap(response, userId);
    } catch (e) {
      // If wallet doesn't exist, create a new one
      if (e.toString().contains('No rows returned')) {
        return await _createWallet(userId);
      }
      rethrow;
    }
  }

  /// Create a new wallet for user
  static Future<EnhancedWallet> _createWallet(String userId) async {
    final wallet = EnhancedWallet(
      uid: userId,
      currency: 'INR', // Default to INR for Indian market
      balanceAvailable: 0,
      balanceLocked: 0,
      updatedAt: DateTime.now(),
    );

    await _supabase.from('wallets').insert(wallet.toMap());
    return wallet;
  }

  /// Get mentor earnings with available and locked amounts
  static Future<MentorEarnings> getMentorEarnings(String mentorId) async {
    try {
      final response = await _supabase
          .from('earnings')
          .select()
          .eq('mentorUid', mentorId)
          .single();

      return MentorEarnings.fromMap(response, mentorId);
    } catch (e) {
      // If earnings record doesn't exist, create a new one
      if (e.toString().contains('No rows returned')) {
        return await _createMentorEarnings(mentorId);
      }
      rethrow;
    }
  }

  /// Create a new earnings record for mentor
  static Future<MentorEarnings> _createMentorEarnings(String mentorId) async {
    final earnings = MentorEarnings(
      mentorUid: mentorId,
      currency: 'INR',
      earningsAvailable: 0,
      earningsLocked: 0,
      updatedAt: DateTime.now(),
    );

    await _supabase.from('earnings').insert(earnings.toMap());
    return earnings;
  }

  // =============================================================================
  // TRANSACTION OPERATIONS
  // =============================================================================

  /// Top-up student wallet (after successful payment gateway confirmation)
  static Future<LedgerTransaction> topupWallet({
    required String userId,
    required int amount, // in minor units (paise)
    required String currency,
    required PaymentGateway gateway,
    required String gatewayId,
    required String idempotencyKey,
  }) async {
    // Create ledger transaction
    final transaction = LedgerTransaction(
      txId: _uuid.v4(),
      type: TransactionType.topup,
      direction: TransactionDirection.credit,
      amount: amount,
      currency: currency,
      fromAccount: AccountType.externalGateway,
      toAccount: AccountType.studentAvailable,
      userId: userId,
      gateway: gateway,
      gatewayId: gatewayId,
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.now(),
    );

    // Execute in transaction to ensure consistency
    await _supabase.rpc('process_wallet_topup', params: {
      'user_id': userId,
      'amount_minor': amount,
      'transaction_data': transaction.toMap(),
    });

    return transaction;
  }

  /// Reserve funds for session booking (wallet mode)
  static Future<LedgerTransaction> reserveFunds({
    required String userId,
    required String sessionId,
    required int amount,
    required String currency,
    required String idempotencyKey,
  }) async {
    // Check if user has sufficient available balance
    final wallet = await getWallet(userId);
    if (wallet.balanceAvailable < amount) {
      throw Exception('Insufficient wallet balance');
    }

    final transaction = LedgerTransaction(
      txId: _uuid.v4(),
      type: TransactionType.reserve,
      direction: TransactionDirection.debit,
      amount: amount,
      currency: currency,
      fromAccount: AccountType.studentAvailable,
      toAccount: AccountType.studentLocked,
      userId: userId,
      sessionId: sessionId,
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.now(),
    );

    // Execute reserve operation
    await _supabase.rpc('process_funds_reserve', params: {
      'user_id': userId,
      'amount_minor': amount,
      'session_id': sessionId,
      'transaction_data': transaction.toMap(),
    });

    return transaction;
  }

  /// Release reserved funds (e.g., on cancellation)
  static Future<LedgerTransaction> releaseFunds({
    required String userId,
    required String sessionId,
    required int amount,
    required String currency,
    required String idempotencyKey,
  }) async {
    final transaction = LedgerTransaction(
      txId: _uuid.v4(),
      type: TransactionType.release,
      direction: TransactionDirection.credit,
      amount: amount,
      currency: currency,
      fromAccount: AccountType.studentLocked,
      toAccount: AccountType.studentAvailable,
      userId: userId,
      sessionId: sessionId,
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.now(),
    );

    await _supabase.rpc('process_funds_release', params: {
      'user_id': userId,
      'amount_minor': amount,
      'session_id': sessionId,
      'transaction_data': transaction.toMap(),
    });

    return transaction;
  }

  /// Complete session payment and split funds
  static Future<List<LedgerTransaction>> completeSessionPayment({
    required String sessionId,
    required String studentId,
    required String mentorId,
    required int totalAmount,
    required String currency,
    required double platformFeePercent, // e.g., 0.15 for 15%
    required String idempotencyKey,
  }) async {
    final transactions = <LedgerTransaction>[];

    // Calculate amounts
    final platformFeeAmount = (totalAmount * platformFeePercent).round();
    final mentorAmount = totalAmount - platformFeeAmount;

    // 1. Capture student payment (debit locked funds)
    final captureTransaction = LedgerTransaction(
      txId: _uuid.v4(),
      type: TransactionType.capture,
      direction: TransactionDirection.debit,
      amount: totalAmount,
      currency: currency,
      fromAccount: AccountType.studentLocked,
      toAccount: AccountType.externalGateway,
      userId: studentId,
      sessionId: sessionId,
      idempotencyKey: '${idempotencyKey}_capture',
      createdAt: DateTime.now(),
    );
    transactions.add(captureTransaction);

    // 2. Credit mentor locked earnings
    final mentorLockTransaction = LedgerTransaction(
      txId: _uuid.v4(),
      type: TransactionType.mentorLock,
      direction: TransactionDirection.credit,
      amount: mentorAmount,
      currency: currency,
      fromAccount: AccountType.externalGateway,
      toAccount: AccountType.mentorLocked,
      userId: mentorId,
      counterpartyUserId: studentId,
      sessionId: sessionId,
      idempotencyKey: '${idempotencyKey}_mentor_lock',
      createdAt: DateTime.now(),
    );
    transactions.add(mentorLockTransaction);

    // 3. Platform fee
    final feeTransaction = LedgerTransaction(
      txId: _uuid.v4(),
      type: TransactionType.fee,
      direction: TransactionDirection.credit,
      amount: platformFeeAmount,
      currency: currency,
      fromAccount: AccountType.externalGateway,
      toAccount: AccountType.platformRevenue,
      sessionId: sessionId,
      idempotencyKey: '${idempotencyKey}_fee',
      createdAt: DateTime.now(),
    );
    transactions.add(feeTransaction);

    // Execute all transactions atomically
    await _supabase.rpc('process_session_completion', params: {
      'session_id': sessionId,
      'student_id': studentId,
      'mentor_id': mentorId,
      'total_amount': totalAmount,
      'mentor_amount': mentorAmount,
      'platform_fee': platformFeeAmount,
      'transactions_data': transactions.map((t) => t.toMap()).toList(),
    });

    return transactions;
  }

  /// Release mentor locked earnings to available (after settlement period)
  static Future<LedgerTransaction> releaseMentorEarnings({
    required String mentorId,
    required String sessionId,
    required int amount,
    required String currency,
    required String idempotencyKey,
  }) async {
    final transaction = LedgerTransaction(
      txId: _uuid.v4(),
      type: TransactionType.mentorRelease,
      direction: TransactionDirection.credit,
      amount: amount,
      currency: currency,
      fromAccount: AccountType.mentorLocked,
      toAccount: AccountType.mentorAvailable,
      userId: mentorId,
      sessionId: sessionId,
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.now(),
    );

    await _supabase.rpc('process_mentor_earnings_release', params: {
      'mentor_id': mentorId,
      'amount_minor': amount,
      'session_id': sessionId,
      'transaction_data': transaction.toMap(),
    });

    return transaction;
  }

  // =============================================================================
  // QUERY OPERATIONS
  // =============================================================================

  /// Get transaction history for a user
  static Future<List<LedgerTransaction>> getTransactionHistory({
    required String userId,
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String filter = 'userId.eq.$userId,counterpartyUserId.eq.$userId';

    if (startDate != null && endDate != null) {
      filter +=
          ',createdAt.gte.${startDate.toIso8601String()},createdAt.lte.${endDate.toIso8601String()}';
    } else if (startDate != null) {
      filter += ',createdAt.gte.${startDate.toIso8601String()}';
    } else if (endDate != null) {
      filter += ',createdAt.lte.${endDate.toIso8601String()}';
    }

    final response = await _supabase
        .from('transactions')
        .select()
        .or(filter)
        .order('createdAt', ascending: false)
        .limit(limit);

    return response
        .map<LedgerTransaction>((data) => LedgerTransaction.fromMap(data))
        .toList();
  }

  /// Get transactions for a specific session
  static Future<List<LedgerTransaction>> getSessionTransactions(
      String sessionId) async {
    final response = await _supabase
        .from('transactions')
        .select()
        .eq('sessionId', sessionId)
        .order('createdAt', ascending: true);

    return response
        .map<LedgerTransaction>((data) => LedgerTransaction.fromMap(data))
        .toList();
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  /// Generate idempotency key for operations
  static String generateIdempotencyKey(String prefix) {
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  /// Validate transaction amount
  static void validateAmount(int amount, {int minAmount = 100}) {
    // Min ₹1
    if (amount < minAmount) {
      throw ArgumentError('Amount must be at least ₹${minAmount / 100}');
    }
    if (amount > 10000000) {
      // Max ₹100,000
      throw ArgumentError('Amount exceeds maximum limit');
    }
  }

  /// Calculate platform fee
  static int calculatePlatformFee(int amount, double feePercent) {
    return (amount * feePercent).round();
  }

  /// Check if wallet has sufficient balance
  static Future<bool> hasSufficientBalance(
      String userId, int requiredAmount) async {
    final wallet = await getWallet(userId);
    return wallet.balanceAvailable >= requiredAmount;
  }
}

/// Provider for wallet service
final walletServiceProvider = Provider<EnhancedWalletService>((ref) {
  return EnhancedWalletService();
});

/// Provider for user's wallet data
final enhancedWalletProvider =
    StreamProvider.family<EnhancedWallet, String>((ref, userId) {
  return Stream.periodic(const Duration(seconds: 30))
      .asyncMap((_) => EnhancedWalletService.getWallet(userId));
});

/// Provider for mentor's earnings data
final mentorEarningsProvider =
    StreamProvider.family<MentorEarnings, String>((ref, mentorId) {
  return Stream.periodic(const Duration(seconds: 30))
      .asyncMap((_) => EnhancedWalletService.getMentorEarnings(mentorId));
});

/// Provider for user's transaction history
final transactionHistoryProvider =
    StreamProvider.family<List<LedgerTransaction>, String>((ref, userId) {
  return Stream.periodic(const Duration(minutes: 1)).asyncMap(
      (_) => EnhancedWalletService.getTransactionHistory(userId: userId));
});
