import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/error/app_error.dart';
import '../../core/models/user.dart';
import '../../core/utils/result.dart';
import 'base_repository.dart';

/// Mock implementation of AuthRepository for development
class MockAuthRepository implements AuthRepository {
  static const String _sessionKey = 'user_session';

  /// Mock user database with predefined credentials
  static final Map<String, Map<String, dynamic>> _mockUsers = {
    'student@test.com': {
      'password': 'password123',
      'name': 'Test Student',
      'role': UserRole.student,
      'id': 'user_000001',
    },
    'mentor@test.com': {
      'password': 'mentor123',
      'name': 'Test Mentor',
      'role': UserRole.mentor,
      'id': 'user_000002',
    },
    'admin@test.com': {
      'password': 'admin123',
      'name': 'Test Admin',
      'role': UserRole.student, // Default role for demo
      'id': 'user_000003',
    },
  };

  /// Simulate network delay
  Future<void> _simulateNetworkDelay() async {
    await Future.delayed(Duration(milliseconds: 300 + Random().nextInt(700)));
  }

  /// Generate mock user ID
  String _generateUserId() {
    return 'user_${Random().nextInt(999999).toString().padLeft(6, '0')}';
  }

  /// Generate mock auth token
  AuthToken _generateAuthToken() {
    final random = Random();
    final accessToken = 'access_${random.nextInt(999999999)}';
    final refreshToken = 'refresh_${random.nextInt(999999999)}';
    final expiresAt = DateTime.now().add(const Duration(hours: 1));

    return AuthToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<Result<Session>> signIn(LoginCredentials credentials) async {
    debugPrint(
        'MockAuthRepository: Attempting sign in for ${credentials.email}');

    try {
      await _simulateNetworkDelay();

      // Validate email format
      final emailLower = credentials.email.toLowerCase();

      // Basic email format validation
      if (!emailLower.contains('@') || !emailLower.contains('.')) {
        return Failure(
            ValidationError.invalidFormat('Email', 'valid email address'));
      }

      // Validate password
      if (credentials.password.isEmpty) {
        return Failure(ValidationError.required('Password'));
      }

      if (credentials.password.length < 6) {
        return Failure(AuthError.weakPassword());
      }

      // Check if user exists in mock database
      final userData = _mockUsers[emailLower];
      if (userData == null) {
        debugPrint('MockAuthRepository: User not found for email: $emailLower');
        return Failure(AuthError.invalidCredentials());
      }

      // Validate password
      if (userData['password'] != credentials.password) {
        debugPrint(
            'MockAuthRepository: Invalid password for email: $emailLower');
        return Failure(AuthError.invalidCredentials());
      }

      // Create user from mock data
      final user = User(
        id: userData['id'],
        name: userData['name'],
        email: credentials.email,
        role: userData['role'],
        createdAt:
            DateTime.now().subtract(Duration(days: Random().nextInt(365))),
        lastLoginAt: DateTime.now(),
      );

      final token = _generateAuthToken();
      final session = Session(user: user, token: token);

      // Store session
      await _storeSession(session);

      debugPrint('MockAuthRepository: Sign in successful for ${user.name}');
      return Success(session);
    } catch (e, stackTrace) {
      debugPrint('MockAuthRepository: Sign in failed: $e');
      return Failure(ErrorHandler.handleError(e, stackTrace));
    }
  }

  @override
  Future<Result<Session>> signUp(RegisterData data) async {
    debugPrint('MockAuthRepository: Attempting sign up for ${data.email}');

    try {
      await _simulateNetworkDelay();

      // Validate required fields
      if (data.name.trim().isEmpty) {
        return Failure(ValidationError.required('Name'));
      }

      if (data.email.isEmpty) {
        return Failure(ValidationError.required('Email'));
      }

      if (data.password.isEmpty) {
        return Failure(ValidationError.required('Password'));
      }

      // Validate password strength
      if (data.password.length < 6) {
        return Failure(AuthError.weakPassword());
      }

      // Validate email format
      final emailLower = data.email.toLowerCase();

      // Basic email format validation
      if (!emailLower.contains('@') || !emailLower.contains('.')) {
        return Failure(
            ValidationError.invalidFormat('Email', 'valid email address'));
      }

      // Check if email already exists in mock database
      if (_mockUsers.containsKey(emailLower)) {
        return Failure(AuthError.emailAlreadyExists());
      }

      // For demo purposes, allow signup but store in temporary session only
      // In a real app, you would store this in your backend database
      final userId = _generateUserId();

      // Create new user
      final user = User(
        id: userId,
        name: data.name.trim(),
        email: data.email,
        role: data.role,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      final token = _generateAuthToken();
      final session = Session(user: user, token: token);

      // Store session (in real app, this would also save user to database)
      await _storeSession(session);

      debugPrint('MockAuthRepository: Sign up successful for ${user.name}');
      return Success(session);
    } catch (e, stackTrace) {
      debugPrint('MockAuthRepository: Sign up failed: $e');
      return Failure(ErrorHandler.handleError(e, stackTrace));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    debugPrint('MockAuthRepository: Signing out');

    try {
      await _simulateNetworkDelay();
      await clearAuthData();
      return const Success(null);
    } catch (e, stackTrace) {
      return Failure(ErrorHandler.handleError(e, stackTrace));
    }
  }

  @override
  Future<Result<AuthToken>> refreshToken(String refreshToken) async {
    debugPrint('MockAuthRepository: Refreshing token');

    try {
      await _simulateNetworkDelay();

      // Simulate token validation
      if (refreshToken.isEmpty || !refreshToken.startsWith('refresh_')) {
        return Failure(AuthError.sessionExpired());
      }

      final newToken = _generateAuthToken();

      // Update stored session with new token
      final currentSession = await getCurrentSession();
      if (currentSession != null) {
        final updatedSession = Session(
          user: currentSession.user,
          token: newToken,
        );
        await _storeSession(updatedSession);
      }

      return Success(newToken);
    } catch (e, stackTrace) {
      return Failure(ErrorHandler.handleError(e, stackTrace));
    }
  }

  @override
  Future<Session?> getCurrentSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_sessionKey);

      if (sessionJson == null) {
        return null;
      }

      final sessionMap = jsonDecode(sessionJson) as Map<String, dynamic>;
      final session = Session.fromJson(sessionMap);

      // Check if session is valid
      if (!session.isValid) {
        await clearAuthData();
        return null;
      }

      return session;
    } catch (e) {
      debugPrint('MockAuthRepository: Error getting current session: $e');
      await clearAuthData(); // Clear corrupted data
      return null;
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    final session = await getCurrentSession();
    return session != null;
  }

  @override
  Future<void> clearAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      debugPrint('MockAuthRepository: Auth data cleared');
    } catch (e) {
      debugPrint('MockAuthRepository: Error clearing auth data: $e');
    }
  }

  /// Store session in local storage
  Future<void> _storeSession(Session session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = jsonEncode(session.toJson());
      await prefs.setString(_sessionKey, sessionJson);
      debugPrint('MockAuthRepository: Session stored');
    } catch (e) {
      debugPrint('MockAuthRepository: Error storing session: $e');
      throw Exception('Failed to store session');
    }
  }
}
