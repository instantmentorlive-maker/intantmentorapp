import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../config/app_config.dart';
import 'supabase_service.dart';

class PaymentService {
  static PaymentService? _instance;
  static PaymentService get instance => _instance ??= PaymentService._();

  PaymentService._();

  final SupabaseService _supabase = SupabaseService.instance;

  /// Initialize Stripe
  static Future<void> initialize() async {
    Stripe.publishableKey = AppConfig.instance.stripePublishableKey;
    await Stripe.instance.applySettings();
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
      // Create payment intent
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
      final merchantDisplayName = 'InstantMentor';

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
    } catch (e) {
      debugPrint('Payment sheet setup error: $e');
      return false;
    }
  }

  /// Present payment sheet and process payment
  Future<PaymentResult> presentPaymentSheet(String sessionId) async {
    try {
      await Stripe.instance.presentPaymentSheet();

      // Payment successful - update status
      await _updateSessionPaymentStatus(sessionId, 'paid');

      return PaymentResult.success(
        transactionId: sessionId,
        amount: 0, // Amount will be updated from server
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
