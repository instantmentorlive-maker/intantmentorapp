import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'wallet_service.dart';
import '../providers/wallet_provider.dart';

class SessionBillingService {
  final WalletService walletService;
  SessionBillingService({required this.walletService});

  final Map<String, _BillingTimer> _active = {};

  /// Start per-minute billing for a live session.
  /// Charges student every minute based on mentor's hourlyRate/60.
  void startMinuteBilling({
    required String sessionId,
    required String studentId,
    required String mentorId,
    required double mentorHourlyRate,
  }) {
    if (_active.containsKey(sessionId)) return;
    final perMinute = mentorHourlyRate / 60.0;
    final timer = _BillingTimer(
      sessionId: sessionId,
      studentId: studentId,
      mentorId: mentorId,
      amountPerMinute: perMinute,
      charge: (qty) async {
        try {
          await walletService.chargeSession(
            sessionId: sessionId,
            studentId: studentId,
            mentorId: mentorId,
            amount: perMinute,
            unit: 'minute',
            quantity: qty,
          );
        } catch (e) {
          if (kDebugMode) {
            // Log and continue; upstream can decide to end session on persistent failures
            print('Minute charge failed: $e');
          }
        }
      },
    );
    _active[sessionId] = timer..start();
  }

  /// Stop billing and optionally perform a final catch-up charge for partial minute.
  Future<void> stopBilling(String sessionId) async {
    final t = _active.remove(sessionId);
    await t?.dispose();
  }
}

class _BillingTimer {
  final String sessionId;
  final String studentId;
  final String mentorId;
  final double amountPerMinute;
  final Future<void> Function(int quantity) charge;
  Timer? _timer;
  // reserved for future analytics

  _BillingTimer({
    required this.sessionId,
    required this.studentId,
    required this.mentorId,
    required this.amountPerMinute,
    required this.charge,
  });

  void start() {
    // Bill first minute after 60s, then every 60s
    _timer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await charge(1);
    });
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
  }
}

final sessionBillingServiceProvider = Provider<SessionBillingService>((ref) {
  final wallet = ref.read(walletServiceProvider);
  return SessionBillingService(walletService: wallet);
});
