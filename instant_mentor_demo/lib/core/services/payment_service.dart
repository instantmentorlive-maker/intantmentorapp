import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'backend_api_service.dart';

class PaymentService {
  static PaymentService? _instance;
  static PaymentService get instance => _instance ??= PaymentService._();

  PaymentService._();

  final BackendApiService _api = BackendApiService.instance;
  late Razorpay _razorpay;

  /// Initialize Razorpay
  static Future<void> initialize() async {
    try {
      final instance = PaymentService.instance;
      instance._razorpay = Razorpay();

      // Set up event listeners
      instance._razorpay
          .on(Razorpay.EVENT_PAYMENT_SUCCESS, instance._handlePaymentSuccess);
      instance._razorpay
          .on(Razorpay.EVENT_PAYMENT_ERROR, instance._handlePaymentError);
      instance._razorpay
          .on(Razorpay.EVENT_EXTERNAL_WALLET, instance._handleExternalWallet);

      print('✅ Payment service: Razorpay initialized successfully');
    } catch (e) {
      print('❌ Payment service: Failed to initialize - $e');
      // Don't throw error in development, just log it
    }
  }

  /// Process payment for a mentoring session
  Future<PaymentResult> processSessionPayment({
    required int mentorId,
    required int studentId,
    required Function(PaymentResult) onSuccess,
    required Function(PaymentResult) onError,
  }) async {
    try {
      // Create session via backend API
      final sessionData = await _api.createSession(
        mentorId: mentorId,
        studentId: studentId,
      );

      final orderId = sessionData['order_id'] as String;
      final amount = sessionData['amount'] as int; // Amount in paise

      // Configure Razorpay checkout options
      final options = {
        'key': 'rzp_test_RVEyPNHbfGXitb', // Test key - should come from config
        'amount': amount,
        'name': 'InstantMentor',
        'description': 'Mentoring Session Payment',
        'order_id': orderId,
        'prefill': {
          'contact': '', // TODO: Get from user profile
          'email': '', // TODO: Get from user profile
        },
        'theme': {
          'color': '#4CAF50', // Green theme
        },
      };

      // Store callbacks for handling success/error
      _currentOnSuccess = onSuccess;
      _currentOnError = onError;

      // Open Razorpay checkout
      _razorpay.open(options);

      // Return pending result - actual result will be delivered via callbacks
      return PaymentResult.pending();
    } catch (e) {
      debugPrint('Payment processing error: $e');
      return PaymentResult.failure(error: e.toString());
    }
  }

  Function(PaymentResult)? _currentOnSuccess;
  Function(PaymentResult)? _currentOnError;

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      // Verify payment with backend
      await _api.verifyPayment(
        razorpayPaymentId: response.paymentId!,
        razorpayOrderId: response.orderId!,
        razorpaySignature: response.signature!,
      );

      final result = PaymentResult.success(
        transactionId: response.paymentId!,
        amount: 0, // TODO: Get actual amount
        currency: 'INR',
        orderId: response.orderId,
      );

      _currentOnSuccess?.call(result);
    } catch (e) {
      final result =
          PaymentResult.failure(error: 'Payment verification failed: $e');
      _currentOnError?.call(result);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    final result = PaymentResult.failure(
      error: response.message ?? 'Payment failed',
      code: response.code?.toString(),
    );
    _currentOnError?.call(result);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet payments if needed
    print('External wallet selected: ${response.walletName}');
  }

  /// Dispose of Razorpay instance
  void dispose() {
    _razorpay.clear();
  }
}

/// Payment result model
class PaymentResult {
  final bool isSuccess;
  final bool isCancelled;
  final bool isPending;
  final String? transactionId;
  final double amount;
  final String currency;
  final String? error;
  final String? code;
  final String? orderId;

  const PaymentResult._({
    required this.isSuccess,
    this.isCancelled = false,
    this.isPending = false,
    this.transactionId,
    this.amount = 0,
    this.currency = 'INR',
    this.error,
    this.code,
    this.orderId,
  });

  factory PaymentResult.success({
    required String transactionId,
    required double amount,
    required String currency,
    String? orderId,
  }) {
    return PaymentResult._(
      isSuccess: true,
      transactionId: transactionId,
      amount: amount,
      currency: currency,
      orderId: orderId,
    );
  }

  factory PaymentResult.failure({
    required String error,
    String? code,
  }) {
    return PaymentResult._(
      isSuccess: false,
      error: error,
      code: code,
    );
  }

  factory PaymentResult.cancelled() {
    return const PaymentResult._(
      isSuccess: false,
      isCancelled: true,
    );
  }

  factory PaymentResult.pending() {
    return const PaymentResult._(
      isSuccess: false,
      isPending: true,
    );
  }
}
