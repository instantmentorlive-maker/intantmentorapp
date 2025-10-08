import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/payment_models.dart';
import '../services/enhanced_wallet_service.dart';
import '../services/payment_gateway_service.dart';
import 'auth_provider.dart';

// Export existing providers from enhanced_wallet_service
export '../services/enhanced_wallet_service.dart'
    show
        enhancedWalletProvider,
        mentorEarningsProvider,
        transactionHistoryProvider,
        walletServiceProvider;

/// Enhanced payment providers for the new payments architecture
/// Connects the enhanced wallet and payment gateway services

// =============================================================================
// SERVICE PROVIDERS
// =============================================================================

/// Provider for payment gateway service
final paymentGatewayServiceProvider = Provider<PaymentGatewayService>((ref) {
  return PaymentGatewayService();
});

/// Provider for user's payment profile
final userPaymentProfileProvider =
    FutureProvider.family<UserPaymentProfile?, String>((ref, userId) async {
  final supabase = Supabase.instance.client;

  try {
    final response = await supabase
        .from('user_payment_profiles')
        .select('*')
        .eq('uid', userId)
        .maybeSingle();

    if (response == null) return null;
    return UserPaymentProfile.fromMap(response);
  } catch (e) {
    throw Exception('Failed to fetch payment profile: $e');
  }
});

/// Provider for mentor's payout requests
final mentorPayoutRequestsProvider =
    StreamProvider.family<List<PayoutRequest>, String>((ref, mentorId) async* {
  final supabase = Supabase.instance.client;

  yield* supabase
      .from('payout_requests')
      .stream(primaryKey: ['id'])
      .eq('mentor_uid', mentorId)
      .order('created_at', ascending: false)
      .map((data) => data.map((item) => PayoutRequest.fromMap(item)).toList());
});

// =============================================================================
// USER-SPECIFIC PROVIDERS
// =============================================================================

/// Provider for current user's wallet (auto-detects user ID)
final currentUserWalletProvider = StreamProvider<EnhancedWallet?>((ref) async* {
  final user = ref.watch(authProvider).user;
  if (user?.id == null) {
    yield null;
    return;
  }

  yield* ref.watch(enhancedWalletProvider(user!.id).stream);
});

/// Provider for current user's earnings (for mentors)
final currentUserEarningsProvider =
    StreamProvider<MentorEarnings?>((ref) async* {
  final user = ref.watch(authProvider).user;
  if (user?.id == null) {
    yield null;
    return;
  }

  // Check if user is a mentor
  final userProfile =
      await ref.read(userPaymentProfileProvider(user!.id).future);
  if (userProfile?.roles.contains('mentor') != true) {
    yield null;
    return;
  }

  yield* ref.watch(mentorEarningsProvider(user.id).stream);
});

/// Provider for current user's transactions
final currentUserTransactionsProvider =
    StreamProvider<List<LedgerTransaction>>((ref) async* {
  final user = ref.watch(authProvider).user;
  if (user?.id == null) {
    yield [];
    return;
  }

  yield* ref.watch(transactionHistoryProvider(user!.id).stream);
});

// =============================================================================
// BALANCE PROVIDERS
// =============================================================================

/// Provider for user's available (spendable) balance
final userAvailableBalanceProvider =
    Provider.family<double, String>((ref, userId) {
  final walletAsync = ref.watch(enhancedWalletProvider(userId));

  return walletAsync.when(
    data: (wallet) => CurrencyUtils.toMajorUnits(wallet.balanceAvailable),
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Provider for mentor's available earnings
final mentorAvailableEarningsProvider =
    Provider.family<double, String>((ref, mentorId) {
  final earningsAsync = ref.watch(mentorEarningsProvider(mentorId));

  return earningsAsync.when(
    data: (earnings) => CurrencyUtils.toMajorUnits(earnings.earningsAvailable),
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

// =============================================================================
// VALIDATION PROVIDERS
// =============================================================================

/// Provider to check if user can make a payment of given amount
final canMakePaymentProvider = Provider.family
    .autoDispose<bool, ({String userId, double amount})>((ref, params) {
  final availableBalance =
      ref.watch(userAvailableBalanceProvider(params.userId));
  return availableBalance >= params.amount;
});

/// Provider to check if mentor can request payout of given amount
final canRequestPayoutProvider = Provider.family
    .autoDispose<bool, ({String mentorId, double amount})>((ref, params) {
  final availableEarnings =
      ref.watch(mentorAvailableEarningsProvider(params.mentorId));
  return availableEarnings >= params.amount &&
      params.amount >= 100.0; // Minimum ₹100 payout
});

/// Provider for user's KYC status
final userKYCStatusProvider = Provider.family<KYCStatus, String>((ref, userId) {
  final profileAsync = ref.watch(userPaymentProfileProvider(userId));

  return profileAsync.when(
    data: (profile) => profile?.kycStatus ?? KYCStatus.unverified,
    loading: () => KYCStatus.unverified,
    error: (_, __) => KYCStatus.unverified,
  );
});

// =============================================================================
// CACHE INVALIDATION HELPERS
// =============================================================================

/// Helper to refresh all payment-related data for a user
void refreshUserPaymentData(WidgetRef ref, String userId) {
  ref.invalidate(enhancedWalletProvider(userId));
  ref.invalidate(mentorEarningsProvider(userId));
  ref.invalidate(transactionHistoryProvider(userId));
  ref.invalidate(userPaymentProfileProvider(userId));
  ref.invalidate(mentorPayoutRequestsProvider(userId));
}

/// Helper to refresh wallet data after a transaction
void refreshAfterTransaction(WidgetRef ref, String userId) {
  ref.invalidate(enhancedWalletProvider(userId));
  ref.invalidate(transactionHistoryProvider(userId));
}

/// Helper to refresh earnings data after a session
void refreshAfterSession(WidgetRef ref, String mentorId, String studentId) {
  ref.invalidate(mentorEarningsProvider(mentorId));
  ref.invalidate(enhancedWalletProvider(studentId));
  ref.invalidate(transactionHistoryProvider(mentorId));
  ref.invalidate(transactionHistoryProvider(studentId));
}
