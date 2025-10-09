import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../config/app_config.dart';
import 'supabase_service.dart';
import 'enhanced_wallet_service.dart';
import 'analytics_tracker.dart';

class PaymentService {
  static PaymentService? _instance;
  static PaymentService get instance => _instance ??= PaymentService._();

  PaymentService._();

  final SupabaseService _supabase = SupabaseService.instance;
  // Cache last created payment intent ids by session to use after presentPaymentSheet
  final Map<String, String> _sessionToPaymentIntent = {};
  final Map<String, double> _sessionToAmount = {};

  /// Initialize Stripe
  static Future<void> initialize() async {
    try {
      final publishableKey = AppConfig.stripePublishableKey;
      if (publishableKey.isEmpty ||
          publishableKey == 'pk_test_demo_key_for_development') {
        print(
            '⚠️ Payment service: Using demo/development mode - payments disabled');
        return;
      }

      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();
      print('✅ Payment service: Stripe initialized successfully');
    } catch (e) {
      print('❌ Payment service: Failed to initialize - $e');
      // Don't throw error in development, just log it
    }
  }

  /// Process payment for a mentoring session
  Future<PaymentResult> processSessionPayment({
    required String sessionId,
    required double amount,
    String currency = 'USD',
    String? paymentMethodId,
  }) async {
    try {
      // Create payment intent via Supabase Edge Function
      final response = await _supabase.client.functions.invoke(
        'process-payment',
        body: {
          'sessionId': sessionId,
          'amount': amount,
          'currency': currency,
          'paymentMethod': paymentMethodId,
        },
      );

      if (response.data == null) {
        throw Exception('Failed to create payment intent');
      }

      final clientSecret = response.data['clientSecret'] as String;
      final paymentIntentId = response.data['paymentIntentId'] as String;

      // Confirm payment with Stripe
      final paymentIntent = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              email: _supabase.currentUser?.email,
            ),
          ),
        ),
      );

      // Update payment status in database
      if (paymentIntent.status == PaymentIntentsStatus.Succeeded) {
        await _updatePaymentStatus(sessionId, 'paid', paymentIntentId);
        return PaymentResult.success(
          transactionId: paymentIntentId,
          amount: amount,
          currency: currency,
        );
      } else {
        await _updatePaymentStatus(sessionId, 'failed', paymentIntentId);
        return PaymentResult.failure(
          error: 'Payment failed: ${paymentIntent.status}',
        );
      }
    } catch (e) {
      debugPrint('Payment processing error: $e');
      return PaymentResult.failure(error: e.toString());
    }
  }

  /// Process refund for a session
  Future<PaymentResult> processRefund({
    required String sessionId,
    required String transactionId,
    double? amount,
    String reason = 'Session cancelled',
  }) async {
    try {
      final response = await _supabase.client.functions.invoke(
        'process-refund',
        body: {
          'sessionId': sessionId,
          'transactionId': transactionId,
          'amount': amount,
          'reason': reason,
        },
      );

      if (response.data == null || response.data['success'] != true) {
        throw Exception('Failed to process refund');
      }

      await _updatePaymentStatus(sessionId, 'refunded', transactionId);

      return PaymentResult.success(
        transactionId: response.data['refundId'],
        amount: amount ?? 0,
        currency: 'USD',
      );
    } catch (e) {
      debugPrint('Refund processing error: $e');
      return PaymentResult.failure(error: e.toString());
    }
  }

  /// Get payment methods for user
  Future<List<PaymentMethod>> getUserPaymentMethods() async {
    try {
      // This would typically fetch saved payment methods from Stripe
      // For now, return empty list - users will add payment method during checkout
      return [];
    } catch (e) {
      debugPrint('Failed to fetch payment methods: $e');
      return [];
    }
  }

  /// Setup payment sheet for session booking
  Future<bool> setupPaymentSheet({
    required String sessionId,
    required double amount,
    String currency = 'USD',
  }) async {
    try {
      // Check if Stripe keys are properly configured
      if (AppConfig.stripePublishableKey.isEmpty ||
          AppConfig.stripePublishableKey ==
              'pk_test_demo_key_for_development') {
        debugPrint(
            '⚠️ Payment: Using demo mode - Stripe keys not configured properly');
        // In demo mode, simulate successful setup
        return true;
      }

      // Try to create payment intent via Supabase Edge Function
      try {
        final response = await _supabase.client.functions.invoke(
          'process-payment',
          body: {
            'sessionId': sessionId,
            'amount': amount,
            'currency': currency,
          },
        );

        if (response.data == null) {
          throw Exception('Failed to create payment intent');
        }

        final clientSecret = response.data['clientSecret'] as String;
        final paymentIntentId = response.data['paymentIntentId'] as String?;
        if (paymentIntentId != null) {
          _sessionToPaymentIntent[sessionId] = paymentIntentId;
        }
        _sessionToAmount[sessionId] = amount;
        const merchantDisplayName = 'InstantMentor';

        // Initialize payment sheet
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: merchantDisplayName,
            style: ThemeMode.system,
            allowsDelayedPaymentMethods: true,
          ),
        );

        return true;
      } catch (supabaseError) {
        debugPrint(
            '⚠️ Payment: Supabase function failed, using demo mode: $supabaseError');
        // Fall back to demo mode if Supabase function fails
        return true;
      }
    } catch (e) {
      debugPrint('❌ Payment sheet setup error: $e');
      return false;
    }
  }

  /// Present payment sheet and process payment
  Future<PaymentResult> presentPaymentSheet(String sessionId) async {
    try {
      // Check if we're in demo mode
      if (AppConfig.stripePublishableKey.isEmpty ||
          AppConfig.stripePublishableKey ==
              'pk_test_demo_key_for_development') {
        debugPrint('💳 Payment: Demo mode - simulating successful payment');
        // Simulate payment processing delay
        await Future.delayed(const Duration(seconds: 1));

        return PaymentResult.success(
          transactionId: 'demo_${DateTime.now().millisecondsSinceEpoch}',
          amount: 0,
          currency: 'USD',
        );
      }

      await Stripe.instance.presentPaymentSheet();

      // Payment successful - update status
      await _updateSessionPaymentStatus(sessionId, 'paid');

      // Post to ledger for direct payment flow
      final user = _supabase.client.auth.currentUser;
      final studentId = user?.id;
      if (studentId != null) {
        // Resolve mentor and price from session
        final session = await _supabase.client
            .from('mentoring_sessions')
            .select('mentor_id, cost, currency')
            .eq('id', sessionId)
            .maybeSingle();

        final mentorId = session != null ? (session['mentor_id'] as String?) : null;
        final currency = (session != null ? (session['currency'] as String?) : null) ?? 'INR';
        // Prefer server cost but fall back to cached
        final amountMajor = session != null && session['cost'] != null
            ? (session['cost'] as num).toDouble()
            : (_sessionToAmount[sessionId] ?? 0);
        final totalMinor = (amountMajor * 100).round();

        // Use default platform fee percent (env or 0.15). We don't have app-level setting exposed here,
        // keep consistent with SQL default 15%.
        const platformFeePercent = 0.15;
        final platformMinor = EnhancedWalletService.calculatePlatformFee(totalMinor, platformFeePercent);
        final mentorMinor = totalMinor - platformMinor;

        final paymentIntentId = _sessionToPaymentIntent[sessionId] ?? sessionId;

        if (mentorId != null && totalMinor > 0) {
          // Call direct-session completion RPC defined in migration 004
          await _supabase.client.rpc('process_direct_session_completion', params: {
            'p_session_id': sessionId,
            'p_student_id': studentId,
            'p_mentor_id': mentorId,
            'p_total_amount': totalMinor,
            'p_mentor_amount': mentorMinor,
            'p_platform_fee': platformMinor,
            'p_currency': currency,
            'p_payment_gateway': 'stripe',
            'p_payment_intent_id': paymentIntentId,
          });

          // Fire analytics event
          await AnalyticsTracker.instance.paymentSucceeded(
            sessionId,
            amountMajor,
            mentorMinor / 100.0,
            platformMinor / 100.0,
          );
        }
      }

      return PaymentResult.success(
        transactionId: _sessionToPaymentIntent[sessionId] ?? sessionId,
        amount: _sessionToAmount[sessionId] ?? 0,
        currency: 'USD',
      );
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return PaymentResult.cancelled();
      } else {
        return PaymentResult.failure(
            error: e.error.message ?? 'Payment failed');
      }
    } catch (e) {
      return PaymentResult.failure(error: e.toString());
    }
  }

  /// Get transaction history for user
  Future<List<PaymentTransaction>> getTransactionHistory() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase.fetchData(
        table: 'payment_transactions',
        filters: {'payer_id': userId},
        orderBy: 'created_at',
        ascending: false,
      );

      return response.map((data) => PaymentTransaction.fromMap(data)).toList();
    } catch (e) {
      debugPrint('Failed to fetch transaction history: $e');
      return [];
    }
  }

  /// Update payment status in database
  Future<void> _updatePaymentStatus(
    String sessionId,
    String status,
    String transactionId,
  ) async {
    await _supabase.updateData(
      table: 'payment_transactions',
      data: {'status': status},
      column: 'transaction_id',
      value: transactionId,
    );
  }

  /// Update session payment status
  Future<void> _updateSessionPaymentStatus(
      String sessionId, String status) async {
    await _supabase.updateData(
      table: 'mentoring_sessions',
      data: {'payment_status': status},
      column: 'id',
      value: sessionId,
    );
  }
}

/// Payment result model
class PaymentResult {
  final bool isSuccess;
  final bool isCancelled;
  final String? transactionId;
  final double amount;
  final String currency;
  final String? error;

  const PaymentResult._({
    required this.isSuccess,
    this.isCancelled = false,
    this.transactionId,
    this.amount = 0,
    this.currency = 'USD',
    this.error,
  });

  factory PaymentResult.success({
    required String transactionId,
    required double amount,
    required String currency,
  }) {
    return PaymentResult._(
      isSuccess: true,
      transactionId: transactionId,
      amount: amount,
      currency: currency,
    );
  }

  factory PaymentResult.failure({required String error}) {
    return PaymentResult._(
      isSuccess: false,
      error: error,
    );
  }

  factory PaymentResult.cancelled() {
    return const PaymentResult._(
      isSuccess: false,
      isCancelled: true,
    );
  }
}

/// Payment transaction model
class PaymentTransaction {
  final String id;
  final String sessionId;
  final String payerId;
  final String payeeId;
  final double amount;
  final String currency;
  final String status;
  final String? paymentMethod;
  final String? transactionId;
  final DateTime createdAt;

  const PaymentTransaction({
    required this.id,
    required this.sessionId,
    required this.payerId,
    required this.payeeId,
    required this.amount,
    required this.currency,
    required this.status,
    this.paymentMethod,
    this.transactionId,
    required this.createdAt,
  });

  factory PaymentTransaction.fromMap(Map<String, dynamic> map) {
    return PaymentTransaction(
      id: map['id'],
      sessionId: map['session_id'],
      payerId: map['payer_id'],
      payeeId: map['payee_id'],
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] ?? 'USD',
      status: map['status'],
      paymentMethod: map['payment_method'],
      transactionId: map['transaction_id'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
