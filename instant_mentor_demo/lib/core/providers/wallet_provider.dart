import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wallet_service.dart';

final walletServiceProvider = Provider<WalletService>((ref) => WalletService());

final walletBalanceProvider =
    FutureProvider.family<double, String>((ref, userId) async {
  final svc = ref.watch(walletServiceProvider);
  return svc.getBalance(userId);
});

final walletTransactionsProvider =
    FutureProvider.family((ref, String userId) async {
  final svc = ref.watch(walletServiceProvider);
  return svc.listTransactions(userId);
});
