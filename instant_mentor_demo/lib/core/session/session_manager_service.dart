import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger.dart';
import '../utils/result.dart';
import '../error/app_error.dart';
import '../models/user.dart';
import '../device/device_info_service.dart';

/// Enhanced session management with multi-device support
class SessionManagerService {
  static final SessionManagerService _instance = SessionManagerService._internal();
  factory SessionManagerService() => _instance;
  SessionManagerService._internal();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(),
  );
  
  static const String _sessionsKey = 'user_sessions';
  static const String _currentSessionKey = 'current_session_id';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _rememberMeKey = 'remember_me_enabled';
  static const String _autoLoginKey = 'auto_login_enabled';
  
  final DeviceInfoService _deviceService = DeviceInfoService();
  
  /// Store a new session
  Future<Result<void>> storeSession(Session session) async {
    try {
      final deviceResult = await _deviceService.getDeviceInfo();
      if (deviceResult.isFailure) {
        Logger.warning('SessionManagerService: Could not get device info, using basic session');
      }
      
      // Enhance session with device information
      final enhancedSession = EnhancedSession(
        session: session,
        deviceInfo: deviceResult.data,
        loginTimestamp: DateTime.now(),
        lastAccessTimestamp: DateTime.now(),
      );
      
      // Get existing sessions
      final sessionsResult = await getAllSessions();
      final sessions = sessionsResult.isSuccess ? sessionsResult.data! : <EnhancedSession>[];
      
      // Remove any existing session for this user on this device
      sessions.removeWhere((s) => 
        s.session.user.id == session.user.id && 
        s.deviceInfo?.deviceId == deviceResult.data?.deviceId
      );
      
      // Add new session
      sessions.add(enhancedSession);
      
      // Keep only last 5 sessions per user
      final userSessions = sessions.where((s) => s.session.user.id == session.user.id).toList();
      userSessions.sort((a, b) => b.lastAccessTimestamp.compareTo(a.lastAccessTimestamp));
      
      // Remove old sessions
      if (userSessions.length > 5) {
        for (final oldSession in userSessions.skip(5)) {
          sessions.remove(oldSession);
        }
      }
      
      // Store sessions
      final sessionsJson = sessions.map((s) => s.toJson()).toList();
      await _secureStorage.write(key: _sessionsKey, value: jsonEncode(sessionsJson));
      
      // Set as current session
      await _secureStorage.write(key: _currentSessionKey, value: enhancedSession.sessionId);
      
      Logger.info('SessionManagerService: Session stored for user ${session.user.email}');
      return Success(null);
      
    } catch (e) {
      Logger.error('SessionManagerService: Error storing session - $e');
      return Failure(
        AppGeneralError.unknown('Failed to store session: $e'),
      );
    }
  }
  
  /// Get current active session
  Future<Result<Session?>> getCurrentSession() async {
    try {
      final currentSessionId = await _secureStorage.read(key: _currentSessionKey);
      if (currentSessionId == null) {
        return Success(null);
      }
      
      final sessionsResult = await getAllSessions();
      if (sessionsResult.isFailure) {
        return Failure(sessionsResult.error!);
      }
      
      final currentSession = sessionsResult.data!
          .firstWhere((s) => s.sessionId == currentSessionId, orElse: () => throw StateError('Not found'));
      
      // Update last access time
      await _updateSessionAccess(currentSessionId);
      
      Logger.info('SessionManagerService: Retrieved current session for ${currentSession.session.user.email}');
      return Success(currentSession.session);
      
    } on StateError {
      Logger.warning('SessionManagerService: Current session not found');
      await _secureStorage.delete(key: _currentSessionKey);
      return Success(null);
    } catch (e) {
      Logger.error('SessionManagerService: Error getting current session - $e');
      return Failure(
        AppGeneralError.unknown('Failed to get current session: $e'),
      );
    }
  }
  
  /// Get all stored sessions
  Future<Result<List<EnhancedSession>>> getAllSessions() async {
    try {
      final sessionsJson = await _secureStorage.read(key: _sessionsKey);
      if (sessionsJson == null) {
        return Success(<EnhancedSession>[]);
      }
      
      final sessionsList = jsonDecode(sessionsJson) as List<dynamic>;
      final sessions = sessionsList
          .map((json) => EnhancedSession.fromJson(json as Map<String, dynamic>))
          .toList();
      
      return Success(sessions);
      
    } catch (e) {
      Logger.error('SessionManagerService: Error getting sessions - $e');
      return Failure(
        AppGeneralError.unknown('Failed to get sessions: $e'),
      );
    }
  }
  
  /// Get sessions for specific user
  Future<Result<List<EnhancedSession>>> getUserSessions(String userId) async {
    try {
      final allSessionsResult = await getAllSessions();
      if (allSessionsResult.isFailure) {
        return Failure(allSessionsResult.error!);
      }
      
      final userSessions = allSessionsResult.data!
          .where((s) => s.session.user.id == userId)
          .toList();
      
      // Sort by last access time
      userSessions.sort((a, b) => b.lastAccessTimestamp.compareTo(a.lastAccessTimestamp));
      
      return Success(userSessions);
      
    } catch (e) {
      Logger.error('SessionManagerService: Error getting user sessions - $e');
      return Failure(
        AppGeneralError.unknown('Failed to get user sessions: $e'),
      );
    }
  }
  
  /// Clear specific session
  Future<Result<void>> clearSession(String sessionId) async {
    try {
      final sessionsResult = await getAllSessions();
      if (sessionsResult.isFailure) {
        return Failure(sessionsResult.error!);
      }
      
      final sessions = sessionsResult.data!;
      sessions.removeWhere((s) => s.sessionId == sessionId);
      
      final sessionsJson = sessions.map((s) => s.toJson()).toList();
      await _secureStorage.write(key: _sessionsKey, value: jsonEncode(sessionsJson));
      
      // Clear current session if it was the one removed
      final currentSessionId = await _secureStorage.read(key: _currentSessionKey);
      if (currentSessionId == sessionId) {
        await _secureStorage.delete(key: _currentSessionKey);
      }
      
      Logger.info('SessionManagerService: Session cleared');
      return Success(null);
      
    } catch (e) {
      Logger.error('SessionManagerService: Error clearing session - $e');
      return Failure(
        AppGeneralError.unknown('Failed to clear session: $e'),
      );
    }
  }
  
  /// Clear all sessions
  Future<Result<void>> clearAllSessions() async {
    try {
      await _secureStorage.delete(key: _sessionsKey);
      await _secureStorage.delete(key: _currentSessionKey);
      
      Logger.info('SessionManagerService: All sessions cleared');
      return Success(null);
      
    } catch (e) {
      Logger.error('SessionManagerService: Error clearing all sessions - $e');
      return Failure(
        AppGeneralError.unknown('Failed to clear all sessions: $e'),
      );
    }
  }
  
  /// Clear sessions for specific user
  Future<Result<void>> clearUserSessions(String userId) async {
    try {
      final sessionsResult = await getAllSessions();
      if (sessionsResult.isFailure) {
        return Failure(sessionsResult.error!);
      }
      
      final sessions = sessionsResult.data!;
      final currentSessionId = await _secureStorage.read(key: _currentSessionKey);
      bool clearedCurrentSession = false;
      
      sessions.removeWhere((s) {
        if (s.session.user.id == userId) {
          if (s.sessionId == currentSessionId) {
            clearedCurrentSession = true;
          }
          return true;
        }
        return false;
      });
      
      final sessionsJson = sessions.map((s) => s.toJson()).toList();
      await _secureStorage.write(key: _sessionsKey, value: jsonEncode(sessionsJson));
      
      if (clearedCurrentSession) {
        await _secureStorage.delete(key: _currentSessionKey);
      }
      
      Logger.info('SessionManagerService: User sessions cleared');
      return Success(null);
      
    } catch (e) {
      Logger.error('SessionManagerService: Error clearing user sessions - $e');
      return Failure(
        AppGeneralError.unknown('Failed to clear user sessions: $e'),
      );
    }
  }
  
  /// Switch to different session
  Future<Result<void>> switchToSession(String sessionId) async {
    try {
      final sessionsResult = await getAllSessions();
      if (sessionsResult.isFailure) {
        return Failure(sessionsResult.error!);
      }
      
      final sessionExists = sessionsResult.data!.any((s) => s.sessionId == sessionId);
      if (!sessionExists) {
        return Failure(
          AppGeneralError.notFound('Session not found'),
        );
      }
      
      await _secureStorage.write(key: _currentSessionKey, value: sessionId);
      await _updateSessionAccess(sessionId);
      
      Logger.info('SessionManagerService: Switched to session $sessionId');
      return Success(null);
      
    } catch (e) {
      Logger.error('SessionManagerService: Error switching session - $e');
      return Failure(
        AppGeneralError.unknown('Failed to switch session: $e'),
      );
    }
  }
  
  /// Update session access time
  Future<void> _updateSessionAccess(String sessionId) async {
    try {
      final sessionsResult = await getAllSessions();
      if (sessionsResult.isFailure) return;
      
      final sessions = sessionsResult.data!;
      final sessionIndex = sessions.indexWhere((s) => s.sessionId == sessionId);
      
      if (sessionIndex != -1) {
        sessions[sessionIndex] = sessions[sessionIndex].copyWith(
          lastAccessTimestamp: DateTime.now(),
        );
        
        final sessionsJson = sessions.map((s) => s.toJson()).toList();
        await _secureStorage.write(key: _sessionsKey, value: jsonEncode(sessionsJson));
      }
    } catch (e) {
      Logger.warning('SessionManagerService: Could not update session access time - $e');
    }
  }
  
  // Biometric settings
  Future<Result<void>> setBiometricEnabled(bool enabled) async {
    try {
      await _secureStorage.write(key: _biometricEnabledKey, value: enabled.toString());
      Logger.info('SessionManagerService: Biometric enabled set to $enabled');
      return Success(null);
    } catch (e) {
      Logger.error('SessionManagerService: Error setting biometric enabled - $e');
      return Failure(AppGeneralError.unknown('Failed to set biometric setting: $e'));
    }
  }
  
  Future<Result<bool>> isBiometricEnabled() async {
    try {
      final value = await _secureStorage.read(key: _biometricEnabledKey);
      return Success(value == 'true');
    } catch (e) {
      Logger.error('SessionManagerService: Error getting biometric enabled - $e');
      return Success(false); // Default to false on error
    }
  }
  
  // Remember me settings
  Future<Result<void>> setRememberMeEnabled(bool enabled) async {
    try {
      await _secureStorage.write(key: _rememberMeKey, value: enabled.toString());
      Logger.info('SessionManagerService: Remember me set to $enabled');
      return Success(null);
    } catch (e) {
      Logger.error('SessionManagerService: Error setting remember me - $e');
      return Failure(AppGeneralError.unknown('Failed to set remember me: $e'));
    }
  }
  
  Future<Result<bool>> isRememberMeEnabled() async {
    try {
      final value = await _secureStorage.read(key: _rememberMeKey);
      return Success(value == 'true');
    } catch (e) {
      Logger.error('SessionManagerService: Error getting remember me - $e');
      return Success(false); // Default to false on error
    }
  }
  
  // Auto-login settings
  Future<Result<void>> setAutoLoginEnabled(bool enabled) async {
    try {
      await _secureStorage.write(key: _autoLoginKey, value: enabled.toString());
      Logger.info('SessionManagerService: Auto-login set to $enabled');
      return Success(null);
    } catch (e) {
      Logger.error('SessionManagerService: Error setting auto-login - $e');
      return Failure(AppGeneralError.unknown('Failed to set auto-login: $e'));
    }
  }
  
  Future<Result<bool>> isAutoLoginEnabled() async {
    try {
      final value = await _secureStorage.read(key: _autoLoginKey);
      return Success(value == 'true');
    } catch (e) {
      Logger.error('SessionManagerService: Error getting auto-login - $e');
      return Success(false); // Default to false on error
    }
  }
}

/// Enhanced session with device and timing information
class EnhancedSession {
  final Session session;
  final DeviceInfo? deviceInfo;
  final DateTime loginTimestamp;
  final DateTime lastAccessTimestamp;
  final String sessionId;
  
  EnhancedSession({
    required this.session,
    this.deviceInfo,
    required this.loginTimestamp,
    required this.lastAccessTimestamp,
    String? sessionId,
  }) : sessionId = sessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
  
  /// Create copy with updated fields
  EnhancedSession copyWith({
    Session? session,
    DeviceInfo? deviceInfo,
    DateTime? loginTimestamp,
    DateTime? lastAccessTimestamp,
    String? sessionId,
  }) => EnhancedSession(
    session: session ?? this.session,
    deviceInfo: deviceInfo ?? this.deviceInfo,
    loginTimestamp: loginTimestamp ?? this.loginTimestamp,
    lastAccessTimestamp: lastAccessTimestamp ?? this.lastAccessTimestamp,
    sessionId: sessionId ?? this.sessionId,
  );
  
  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'session': {
      'user': session.user.toJson(),
      'token': session.token.toJson(),
    },
    'deviceInfo': deviceInfo?.toJson(),
    'loginTimestamp': loginTimestamp.toIso8601String(),
    'lastAccessTimestamp': lastAccessTimestamp.toIso8601String(),
    'sessionId': sessionId,
  };
  
  /// Create from JSON
  factory EnhancedSession.fromJson(Map<String, dynamic> json) {
    final sessionJson = json['session'] as Map<String, dynamic>;
    return EnhancedSession(
      session: Session(
        user: User.fromJson(sessionJson['user'] as Map<String, dynamic>),
        token: AuthToken.fromJson(sessionJson['token'] as Map<String, dynamic>),
      ),
      deviceInfo: json['deviceInfo'] != null
          ? DeviceInfo.fromJson(json['deviceInfo'] as Map<String, dynamic>)
          : null,
      loginTimestamp: DateTime.parse(json['loginTimestamp'] as String),
      lastAccessTimestamp: DateTime.parse(json['lastAccessTimestamp'] as String),
      sessionId: json['sessionId'] as String,
    );
  }
  
  /// Get device display name
  String get deviceDisplayName {
    if (deviceInfo == null) return 'Unknown Device';
    return '${deviceInfo!.deviceBrand} ${deviceInfo!.deviceModel}';
  }
  
  /// Check if session is from current device
  Future<bool> isCurrentDevice() async {
    final deviceService = DeviceInfoService();
    final currentDeviceResult = await deviceService.getDeviceId();
    if (currentDeviceResult.isFailure || deviceInfo == null) {
      return false;
    }
    return deviceInfo!.deviceId == currentDeviceResult.data!;
  }
  
  @override
  String toString() => 'EnhancedSession(user: ${session.user.email}, device: $deviceDisplayName, lastAccess: $lastAccessTimestamp)';
}
