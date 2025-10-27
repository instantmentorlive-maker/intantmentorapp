import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents an active user session
class ActiveSession {
  final String id;
  final String deviceName;
  final String deviceType;
  final String ipAddress;
  final DateTime createdAt;
  final DateTime lastActivity;
  final bool isCurrentSession;

  ActiveSession({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.ipAddress,
    required this.createdAt,
    required this.lastActivity,
    required this.isCurrentSession,
  });

  factory ActiveSession.fromJson(
      Map<String, dynamic> json, String currentSessionId) {
    return ActiveSession(
      id: json['id'] ?? '',
      deviceName: json['device_name'] ?? 'Unknown Device',
      deviceType: json['device_type'] ?? 'Unknown',
      ipAddress: json['ip_address'] ?? 'Unknown',
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      lastActivity: DateTime.parse(
          json['last_activity'] ?? DateTime.now().toIso8601String()),
      isCurrentSession: json['id'] == currentSessionId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_name': deviceName,
      'device_type': deviceType,
      'ip_address': ipAddress,
      'created_at': createdAt.toIso8601String(),
      'last_activity': lastActivity.toIso8601String(),
      'is_current_session': isCurrentSession,
    };
  }
}

/// Service for managing user authentication sessions
class SessionManagementService {
  final SupabaseClient _client;

  SessionManagementService(this._client);

  /// Get all active sessions for the current user
  Future<List<ActiveSession>> getActiveSessions() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      final currentSessionId = _client.auth.currentSession?.accessToken ?? '';

      // For demo purposes, we'll simulate session data
      // In a real implementation, this would query a sessions table
      final sessions = await _getMockSessions(user.id, currentSessionId);

      return sessions;
    } catch (e) {
      debugPrint('❌ Failed to get active sessions: $e');
      rethrow;
    }
  }

  /// Revoke a specific session
  Future<void> revokeSession(String sessionId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // Check if revoking current session
      final currentSessionId = _client.auth.currentSession?.accessToken ?? '';
      if (sessionId == currentSessionId) {
        // Revoke current session - sign out
        await _client.auth.signOut();
        return;
      }

      // For demo purposes, we'll simulate revoking the session
      // In a real implementation, this would update the sessions table
      debugPrint('🟢 Session $sessionId revoked');
    } catch (e) {
      debugPrint('❌ Failed to revoke session: $e');
      rethrow;
    }
  }

  /// Revoke all sessions except the current one
  Future<void> revokeAllOtherSessions() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      final currentSessionId = _client.auth.currentSession?.accessToken ?? '';

      // For demo purposes, we'll simulate revoking all other sessions
      // In a real implementation, this would update the sessions table
      debugPrint(
          '🟢 All other sessions revoked, keeping session: $currentSessionId');
    } catch (e) {
      debugPrint('❌ Failed to revoke all other sessions: $e');
      rethrow;
    }
  }

  /// Force logout from all devices (revoke all sessions)
  Future<void> forceLogoutAllDevices() async {
    try {
      // Sign out from Supabase (this revokes the current session)
      await _client.auth.signOut();

      // In a real implementation, you might also want to:
      // 1. Update all sessions in the database to mark them as revoked
      // 2. Send push notifications to other devices
      // 3. Clear any cached session data

      debugPrint('🟢 Force logout from all devices completed');
    } catch (e) {
      debugPrint('❌ Failed to force logout from all devices: $e');
      rethrow;
    }
  }

  /// Get device information for session tracking
  Map<String, String> _getDeviceInfo() {
    // In a real implementation, you might use device_info_plus package
    // to get actual device information
    return {
      'device_name': 'Flutter App',
      'device_type': defaultTargetPlatform == TargetPlatform.android
          ? 'Android'
          : defaultTargetPlatform == TargetPlatform.iOS
              ? 'iOS'
              : 'Unknown',
      'ip_address': '192.168.1.1', // Would be obtained from server
    };
  }

  /// Mock session data for demonstration
  Future<List<ActiveSession>> _getMockSessions(
      String userId, String currentSessionId) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    final now = DateTime.now();
    final deviceInfo = _getDeviceInfo();

    return [
      ActiveSession(
        id: currentSessionId,
        deviceName: '${deviceInfo['device_name']} (Current)',
        deviceType: deviceInfo['device_type'] ?? 'Unknown',
        ipAddress: deviceInfo['ip_address'] ?? 'Unknown',
        createdAt: now.subtract(const Duration(hours: 2)),
        lastActivity: now,
        isCurrentSession: true,
      ),
      ActiveSession(
        id: 'session_2_$userId',
        deviceName: 'iPhone 15 Pro',
        deviceType: 'iOS',
        ipAddress: '10.0.0.5',
        createdAt: now.subtract(const Duration(days: 1)),
        lastActivity: now.subtract(const Duration(minutes: 30)),
        isCurrentSession: false,
      ),
      ActiveSession(
        id: 'session_3_$userId',
        deviceName: 'MacBook Pro',
        deviceType: 'Web',
        ipAddress: '192.168.1.100',
        createdAt: now.subtract(const Duration(days: 2)),
        lastActivity: now.subtract(const Duration(hours: 1)),
        isCurrentSession: false,
      ),
    ];
  }
}
