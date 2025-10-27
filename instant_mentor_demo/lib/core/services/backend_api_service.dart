import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../network/network_client.dart';

/// API service for communicating with FastAPI backend
class BackendApiService {
  static BackendApiService? _instance;
  static BackendApiService get instance => _instance ??= BackendApiService._();

  late final Dio _dio;

  BackendApiService._() {
    _dio = NetworkClient.instance;
  }

  // =============================================================================
  // MENTOR ENDPOINTS
  // =============================================================================

  /// Create a new mentor
  Future<Map<String, dynamic>> createMentor({
    required String name,
    required String email,
    String? phone,
    required double pricePerSessionInr,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConfig.instance.fullApiUrl}/mentor/create',
        data: {
          'name': name,
          'email': email,
          'phone': phone,
          'price_per_session_inr': pricePerSessionInr,
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to create mentor: $e');
    }
  }

  /// Update mentor's session price
  Future<Map<String, dynamic>> updateMentorPrice({
    required int mentorId,
    required double pricePerSessionInr,
  }) async {
    try {
      final response = await _dio.put(
        '${AppConfig.instance.fullApiUrl}/mentor/$mentorId/price',
        data: {
          'price_per_session_inr': pricePerSessionInr,
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to update mentor price: $e');
    }
  }

  /// Attach Razorpay account to mentor
  Future<Map<String, dynamic>> attachMentorAccount({
    required int mentorId,
    required String razorpayAccountId,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConfig.instance.fullApiUrl}/mentor/$mentorId/attach_route_account',
        data: {
          'razorpay_account_id': razorpayAccountId,
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to attach mentor account: $e');
    }
  }

  // =============================================================================
  // STUDENT ENDPOINTS
  // =============================================================================

  /// Create a new student
  Future<Map<String, dynamic>> createStudent({
    required String name,
    required String email,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConfig.instance.fullApiUrl}/student/create',
        data: {
          'name': name,
          'email': email,
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to create student: $e');
    }
  }

  // =============================================================================
  // SESSION ENDPOINTS
  // =============================================================================

  /// Create a new session with payment
  Future<Map<String, dynamic>> createSession({
    required int mentorId,
    required int studentId,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConfig.instance.fullApiUrl}/session/create',
        data: {
          'mentor_id': mentorId,
          'student_id': studentId,
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to create session: $e');
    }
  }

  // =============================================================================
  // PAYMENT ENDPOINTS
  // =============================================================================

  /// Verify payment after successful Razorpay checkout
  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConfig.instance.fullApiUrl}/payment/verify',
        data: {
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_order_id': razorpayOrderId,
          'razorpay_signature': razorpaySignature,
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to verify payment: $e');
    }
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  /// Get full API URL for a given endpoint
  String getApiUrl(String endpoint) {
    return '${AppConfig.instance.fullApiUrl}/$endpoint';
  }
}
