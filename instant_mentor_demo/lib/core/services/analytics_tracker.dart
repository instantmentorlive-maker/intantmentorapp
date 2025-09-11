import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

/// Lightweight event tracker for product analytics.
class AnalyticsTracker {
  static AnalyticsTracker? _instance;
  static AnalyticsTracker get instance => _instance ??= AnalyticsTracker._();

  AnalyticsTracker._();

  final SupabaseService _supabase = SupabaseService.instance;

  /// Track a generic event.
  Future<void> track(
    String name, {
    Map<String, dynamic>? props,
    String? userId,
  }) async {
    try {
      final uid = userId ?? _supabase.currentUser?.id;
      await _supabase.client.from('analytics_events').insert({
        'event_name': name,
        'user_id': uid,
        'properties': props ?? {},
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics track failed: $e');
    }
  }

  // Convenience wrappers
  Future<void> sessionCreated(String sessionId, String studentId, String mentorId) =>
      track('session_created', props: {
        'session_id': sessionId,
        'student_id': studentId,
        'mentor_id': mentorId,
      });

  Future<void> sessionStarted(String sessionId) =>
      track('session_started', props: {'session_id': sessionId});

  Future<void> sessionCompleted(String sessionId, int minutes) =>
      track('session_completed', props: {
        'session_id': sessionId,
        'duration_minutes': minutes,
      });

  Future<void> paymentSucceeded(String sessionId, double amount, double mentorNet, double commission) =>
      track('payment_succeeded', props: {
        'session_id': sessionId,
        'amount': amount,
        'mentor_net': mentorNet,
        'commission': commission,
      });

  Future<void> refundIssued(String sessionId, double amount) =>
      track('refund_issued', props: {
        'session_id': sessionId,
        'amount': amount,
      });
}
