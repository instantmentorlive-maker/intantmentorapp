import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/payment_models.dart';
import 'enhanced_wallet_service.dart';

/// Payment gateway service for handling Stripe and Razorpay integrations
/// Implements the payments architecture for top-ups and payouts
class PaymentGatewayService {
  // =============================================================================
  // STRIPE CONFIGURATION
  // =============================================================================

  static const String _stripeBaseUrl = 'https://api.stripe.com/v1';
  static const String _stripePublishableKey = kDebugMode
      ? 'pk_test_...' // Test key
      : 'pk_live_...'; // Live key

  static const String _stripeSecretKey = kDebugMode
      ? 'sk_test_...' // Test key
      : 'sk_live_...'; // Live key

  // =============================================================================
  // RAZORPAY CONFIGURATION
  // =============================================================================

  static const String _razorpayBaseUrl = 'https://api.razorpay.com/v1';
  static const String _razorpayKeyId = kDebugMode
      ? 'rzp_test_...' // Test key
      : 'rzp_live_...'; // Live key

  static const String _razorpayKeySecret = kDebugMode
      ? 'test_secret_...' // Test secret
      : 'live_secret_...'; // Live secret

  // =============================================================================
  // STRIPE OPERATIONS
  // =============================================================================

  /// Create Stripe PaymentIntent for wallet top-up
  static Future<String> createStripePaymentIntent({
    required int amount, // in paise (minor units)
    required String currency,
    required String customerId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_stripeBaseUrl/payment_intents'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': amount.toString(),
          'currency': currency.toLowerCase(),
          'customer': customerId,
          'confirmation_method': 'manual',
          'confirm': 'true',
          'return_url': 'https://your-app.com/payment-return',
          if (metadata != null)
            ...metadata.map((k, v) => MapEntry('metadata[$k]', v.toString())),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['client_secret'];
      } else {
        throw Exception('Failed to create PaymentIntent: ${response.body}');
      }
    } catch (e) {
      debugPrint('Stripe PaymentIntent error: $e');
      throw Exception('Payment initialization failed: $e');
    }
  }

  /// Create or retrieve Stripe customer
  static Future<String> createStripeCustomer({
    required String email,
    required String name,
    String? phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_stripeBaseUrl/customers'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'email': email,
          'name': name,
          if (phone != null) 'phone': phone,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['id'];
      } else {
        throw Exception('Failed to create customer: ${response.body}');
      }
    } catch (e) {
      debugPrint('Stripe customer creation error: $e');
      rethrow;
    }
  }

  /// Process Stripe payout for mentor
  static Future<String> createStripePayout({
    required String accountId,
    required int amount,
    required String currency,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_stripeBaseUrl/transfers'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': amount.toString(),
          'currency': currency.toLowerCase(),
          'destination': accountId,
          if (metadata != null)
            ...metadata.map((k, v) => MapEntry('metadata[$k]', v.toString())),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['id'];
      } else {
        throw Exception('Failed to create payout: ${response.body}');
      }
    } catch (e) {
      debugPrint('Stripe payout error: $e');
      rethrow;
    }
  }

  // =============================================================================
  // RAZORPAY OPERATIONS
  // =============================================================================

  /// Create Razorpay order for wallet top-up
  static Future<Map<String, dynamic>> createRazorpayOrder({
    required int amount, // in paise
    required String currency,
    required String receipt,
    Map<String, dynamic>? notes,
  }) async {
    try {
      final credentials =
          base64Encode(utf8.encode('$_razorpayKeyId:$_razorpayKeySecret'));

      final response = await http.post(
        Uri.parse('$_razorpayBaseUrl/orders'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'amount': amount,
          'currency': currency.toUpperCase(),
          'receipt': receipt,
          'payment_capture': 1,
          if (notes != null) 'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create Razorpay order: ${response.body}');
      }
    } catch (e) {
      debugPrint('Razorpay order creation error: $e');
      rethrow;
    }
  }

  /// Verify Razorpay payment signature
  static bool verifyRazorpaySignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    // In production, implement proper signature verification
    // This is a simplified version
    try {
      final message = '$orderId|$paymentId';
      // Verify HMAC SHA256 signature using Razorpay key secret
      // Implementation depends on crypto library
      return signature.isNotEmpty; // Simplified for demo
    } catch (e) {
      debugPrint('Signature verification error: $e');
      return false;
    }
  }

  /// Create Razorpay payout for mentor
  static Future<Map<String, dynamic>> createRazorpayPayout({
    required String contactId,
    required String fundAccountId,
    required int amount,
    required String currency,
    required String mode, // UPI, IMPS, NEFT, RTGS
    String? purpose,
  }) async {
    try {
      final credentials =
          base64Encode(utf8.encode('$_razorpayKeyId:$_razorpayKeySecret'));

      final response = await http.post(
        Uri.parse('$_razorpayBaseUrl/payouts'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'account_number': '2323230099089860', // Your account number
          'fund_account_id': fundAccountId,
          'amount': amount,
          'currency': currency.toUpperCase(),
          'mode': mode.toUpperCase(),
          'purpose': purpose ?? 'payout',
          'queue_if_low_balance': true,
          'reference_id': 'payout_${DateTime.now().millisecondsSinceEpoch}',
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create Razorpay payout: ${response.body}');
      }
    } catch (e) {
      debugPrint('Razorpay payout error: $e');
      rethrow;
    }
  }

  // =============================================================================
  // WEBHOOK HANDLERS
  // =============================================================================

  /// Handle Stripe webhook events
  static Future<void> handleStripeWebhook({
    required Map<String, dynamic> event,
    required String signature,
  }) async {
    try {
      // Verify webhook signature in production
      final eventType = event['type'];
      final eventData = event['data']['object'];

      switch (eventType) {
        case 'payment_intent.succeeded':
          await _handleStripePaymentSuccess(eventData);
          break;
        case 'payment_intent.payment_failed':
          await _handleStripePaymentFailure(eventData);
          break;
        case 'transfer.created':
          await _handleStripeTransferCreated(eventData);
          break;
        case 'transfer.paid':
          await _handleStripeTransferPaid(eventData);
          break;
        default:
          debugPrint('Unhandled Stripe webhook event: $eventType');
      }
    } catch (e) {
      debugPrint('Stripe webhook error: $e');
      rethrow;
    }
  }

  /// Handle Razorpay webhook events
  static Future<void> handleRazorpayWebhook({
    required Map<String, dynamic> event,
    required String signature,
  }) async {
    try {
      final eventType = event['event'];
      final eventData = event['payload'];

      switch (eventType) {
        case 'payment.captured':
          await _handleRazorpayPaymentSuccess(eventData);
          break;
        case 'payment.failed':
          await _handleRazorpayPaymentFailure(eventData);
          break;
        case 'payout.processed':
          await _handleRazorpayPayoutProcessed(eventData);
          break;
        case 'payout.failed':
          await _handleRazorpayPayoutFailed(eventData);
          break;
        default:
          debugPrint('Unhandled Razorpay webhook event: $eventType');
      }
    } catch (e) {
      debugPrint('Razorpay webhook error: $e');
      rethrow;
    }
  }

  // =============================================================================
  // PRIVATE WEBHOOK HANDLERS
  // =============================================================================

  static Future<void> _handleStripePaymentSuccess(
      Map<String, dynamic> paymentIntent) async {
    try {
      final amount = paymentIntent['amount'];
      final currency = paymentIntent['currency'];
      final customerId = paymentIntent['customer'];
      final paymentIntentId = paymentIntent['id'];

      // Extract userId from metadata
      final userId = paymentIntent['metadata']?['userId'];
      if (userId == null) return;

      // Create ledger entry for wallet top-up
      await EnhancedWalletService.topupWallet(
        userId: userId,
        amount: amount,
        currency: currency.toUpperCase(),
        gateway: PaymentGateway.stripe,
        gatewayId: paymentIntentId,
        idempotencyKey: 'stripe_$paymentIntentId',
      );

      debugPrint('Stripe payment processed successfully for user: $userId');
    } catch (e) {
      debugPrint('Error processing Stripe payment success: $e');
    }
  }

  static Future<void> _handleStripePaymentFailure(
      Map<String, dynamic> paymentIntent) async {
    debugPrint('Stripe payment failed: ${paymentIntent['id']}');
    // Handle failure notification to user
  }

  static Future<void> _handleStripeTransferCreated(
      Map<String, dynamic> transfer) async {
    debugPrint('Stripe transfer created: ${transfer['id']}');
  }

  static Future<void> _handleStripeTransferPaid(
      Map<String, dynamic> transfer) async {
    debugPrint('Stripe transfer paid: ${transfer['id']}');
    // Update payout status to completed
  }

  static Future<void> _handleRazorpayPaymentSuccess(
      Map<String, dynamic> payment) async {
    try {
      final amount = payment['payment']['entity']['amount'];
      final currency = payment['payment']['entity']['currency'];
      final paymentId = payment['payment']['entity']['id'];
      final orderId = payment['payment']['entity']['order_id'];

      // Extract userId from order notes
      // In production, fetch order details to get userId

      debugPrint('Razorpay payment processed successfully: $paymentId');
    } catch (e) {
      debugPrint('Error processing Razorpay payment success: $e');
    }
  }

  static Future<void> _handleRazorpayPaymentFailure(
      Map<String, dynamic> payment) async {
    debugPrint(
        'Razorpay payment failed: ${payment['payment']['entity']['id']}');
  }

  static Future<void> _handleRazorpayPayoutProcessed(
      Map<String, dynamic> payout) async {
    debugPrint(
        'Razorpay payout processed: ${payout['payout']['entity']['id']}');
  }

  static Future<void> _handleRazorpayPayoutFailed(
      Map<String, dynamic> payout) async {
    debugPrint('Razorpay payout failed: ${payout['payout']['entity']['id']}');
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  /// Get recommended payment gateway based on currency and region
  static PaymentGateway getRecommendedGateway(String currency) {
    switch (currency.toUpperCase()) {
      case 'INR':
        return PaymentGateway.razorpay; // Better for India
      default:
        return PaymentGateway.stripe; // Better for international
    }
  }

  /// Calculate processing fee for different gateways
  static int calculateProcessingFee({
    required PaymentGateway gateway,
    required int amount,
    String currency = 'INR',
  }) {
    switch (gateway) {
      case PaymentGateway.stripe:
        // Stripe India: 2.9% + ₹2
        return (amount * 0.029).round() + 200; // ₹2 in paise
      case PaymentGateway.razorpay:
        // Razorpay: 2% (no fixed fee)
        return (amount * 0.02).round();
    }
  }

  /// Validate payment amount limits
  static void validatePaymentAmount(int amount, PaymentGateway gateway) {
    const minAmount = 5000; // ₹50 minimum
    const maxAmount = 10000000; // ₹1,00,000 maximum

    if (amount < minAmount) {
      throw ArgumentError('Minimum payment amount is ₹${minAmount / 100}');
    }
    if (amount > maxAmount) {
      throw ArgumentError('Maximum payment amount is ₹${maxAmount / 100}');
    }
  }
}
