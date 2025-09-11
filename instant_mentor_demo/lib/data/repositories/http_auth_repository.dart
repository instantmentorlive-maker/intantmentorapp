import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/models/user.dart';
import '../../core/utils/result.dart';
import '../../core/error/app_error.dart';
import '../../core/network/network_client.dart';
import '../../core/network/network_error_handler.dart';
import '../../core/utils/logger.dart';
import 'base_repository.dart';
import '../../core/network/enhanced_network_client.dart';

/// HTTP-based authentication repository implementation
class HttpAuthRepository implements AuthRepository {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'current_user';
  static const String _sessionKey = 'current_session';
  
  // Use the general client for most APIs
  final Dio _dio = NetworkClient.instance;
  // Use a fast, no-retry client for auth to avoid long hangs due to
  // retries/offline queueing/CORS on web. Short timeouts to surface errors.
  late final Dio _authDio = EnhancedNetworkClient.createSpecializedClient(
    timeout: const Duration(seconds: 15),
    enableCache: false,
    enableRetry: false,
  );
  // AppConfig available via AppConfig.instance if needed
  
  @override
  Future<Result<Session>> signIn(LoginCredentials credentials) async {
    try {
      Logger.auth('Attempting sign in for ${credentials.email}');
      
  final response = await _authDio.post(
        '/auth/login',
        data: credentials.toJson(),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        // Parse response
        final authToken = AuthToken.fromJson(data['token']);
        final user = User.fromJson(data['user']);
        final session = Session(user: user, token: authToken);
        
        // Store session securely
        await _storeSession(session);
        
        Logger.auth('Sign in successful for ${user.role.name}');
        return Success(session);
      } else {
        Logger.auth('Sign in failed: ${response.statusMessage}');
        return Failure(AuthError.invalidCredentials());
      }
    } catch (error) {
      Logger.error('Sign in error: $error');
      return NetworkErrorHandler.handleError<Session>(error);
    }
  }
  
  @override
  Future<Result<Session>> signUp(RegisterData registerData) async {
    try {
      Logger.auth('Attempting sign up for ${registerData.email}');
      
  final response = await _authDio.post(
        '/auth/register',
        data: registerData.toJson(),
      );
      
      if (response.statusCode == 201) {
        final data = response.data;
        
        // Parse response
        final authToken = AuthToken.fromJson(data['token']);
        final user = User.fromJson(data['user']);
        final session = Session(user: user, token: authToken);
        
        // Store session securely
        await _storeSession(session);
        
        Logger.auth('Sign up successful for ${user.name}');
        return Success(session);
      } else {
        Logger.auth('Sign up failed: ${response.statusMessage}');
        return Failure(AuthError.invalidCredentials());
      }
    } catch (error) {
      Logger.error('Sign up error: $error');
      return NetworkErrorHandler.handleError<Session>(error);
    }
  }
  
  @override
  Future<Result<void>> signOut() async {
    try {
      Logger.auth('Attempting sign out');
      
      // Call logout endpoint to invalidate server-side session
  await _authDio.post('/auth/logout');
      
      // Clear local data
      await clearAuthData();
      
      Logger.auth('Sign out successful');
      return const Success(null);
    } catch (error) {
      Logger.warning('Sign out error (continuing anyway): $error');
      // Even if server request fails, clear local data
      await clearAuthData();
      return const Success(null);
    }
  }
  
  @override
  Future<Result<AuthToken>> refreshToken(String refreshToken) async {
    try {
      Logger.auth('Attempting token refresh');
      
  final response = await _authDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final newToken = AuthToken.fromJson(data['token']);
        
        // Store new tokens
        await _secureStorage.write(key: _tokenKey, value: newToken.accessToken);
        await _secureStorage.write(key: _refreshTokenKey, value: newToken.refreshToken);
        
        Logger.auth('Token refresh successful');
        return Success(newToken);
      } else {
        Logger.auth('Token refresh failed');
        await clearAuthData(); // Clear invalid tokens
        return Failure(AuthError.sessionExpired());
      }
    } catch (error) {
      Logger.error('Token refresh error: $error');
      await clearAuthData(); // Clear invalid tokens
      return NetworkErrorHandler.handleError<AuthToken>(error);
    }
  }
  
  @override
  Future<Session?> getCurrentSession() async {
    try {
      final sessionJson = await _secureStorage.read(key: _sessionKey);
      if (sessionJson == null) return null;
      
      final session = Session.fromJson(json.decode(sessionJson));
      
      // Check if token is expired
      if (session.token.isExpired) {
        Logger.auth('Session expired, attempting refresh');
        
        // Try to refresh token
        final refreshResult = await refreshToken(session.token.refreshToken);
        if (refreshResult.isSuccess) {
          // Update session with new token
          final newSession = session.copyWith(token: refreshResult.data!);
          await _storeSession(newSession);
          return newSession;
        } else {
          // Refresh failed, clear session
          await clearAuthData();
          return null;
        }
      }
      
      return session;
    } catch (error) {
      Logger.error('Get current session error: $error');
      await clearAuthData(); // Clear corrupted data
      return null;
    }
  }
  
  @override
  Future<bool> isAuthenticated() async {
    final session = await getCurrentSession();
    return session != null && !session.token.isExpired;
  }
  
  @override
  Future<void> clearAuthData() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userKey);
    await _secureStorage.delete(key: _sessionKey);
    Logger.auth('Auth data cleared');
  }
  
  /// Store session data securely
  Future<void> _storeSession(Session session) async {
    await _secureStorage.write(key: _tokenKey, value: session.token.accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: session.token.refreshToken);
    await _secureStorage.write(key: _userKey, value: json.encode(session.user.toJson()));
    await _secureStorage.write(key: _sessionKey, value: json.encode(session.toJson()));
  }
  
  /// Get user profile from server
  Future<Result<User>> getUserProfile() async {
    try {
      Logger.auth('Fetching user profile');
      
  final response = await _dio.get('/auth/profile');
      
      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);
        Logger.auth('User profile fetched successfully');
        return Success(user);
      } else {
        return Failure(AuthError.sessionExpired());
      }
    } catch (error) {
      Logger.error('Get user profile error: $error');
      return NetworkErrorHandler.handleError<User>(error);
    }
  }
  
  /// Update user profile
  Future<Result<User>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      Logger.auth('Updating user profile');
      
  final response = await _dio.put(
        '/auth/profile',
        data: profileData,
      );
      
      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);
        
        // Update stored session
        final currentSession = await getCurrentSession();
        if (currentSession != null) {
          final updatedSession = currentSession.copyWith(user: user);
          await _storeSession(updatedSession);
        }
        
        Logger.auth('User profile updated successfully');
        return Success(user);
      } else {
        return Failure(ValidationError.invalidFormat('profile', 'data'));
      }
    } catch (error) {
      Logger.error('Update profile error: $error');
      return NetworkErrorHandler.handleError<User>(error);
    }
  }
  
  /// Change user password
  Future<Result<void>> changePassword(String currentPassword, String newPassword) async {
    try {
      Logger.auth('Attempting password change');
      
  final response = await _dio.put(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      
      if (response.statusCode == 200) {
        Logger.auth('Password change successful');
        return const Success(null);
      } else {
        return Failure(AuthError.invalidCredentials());
      }
    } catch (error) {
      Logger.error('Change password error: $error');
      return NetworkErrorHandler.handleError<void>(error);
    }
  }
  
  /// Request password reset
  Future<Result<void>> requestPasswordReset(String email) async {
    try {
      Logger.auth('Requesting password reset for $email');
      
  final response = await _dio.post(
        '/auth/forgot-password',
        data: {'email': email},
      );
      
      if (response.statusCode == 200) {
        Logger.auth('Password reset requested successfully');
        return const Success(null);
      } else {
        return Failure(AuthError.accountNotFound());
      }
    } catch (error) {
      Logger.error('Request password reset error: $error');
      return NetworkErrorHandler.handleError<void>(error);
    }
  }
  
  /// Reset password with token
  Future<Result<void>> resetPassword(String token, String newPassword) async {
    try {
      Logger.auth('Resetting password with token');
      
  final response = await _dio.post(
        '/auth/reset-password',
        data: {
          'token': token,
          'password': newPassword,
        },
      );
      
      if (response.statusCode == 200) {
        Logger.auth('Password reset successful');
        return const Success(null);
      } else {
        return Failure(ValidationError.invalidFormat('token', 'reset token'));
      }
    } catch (error) {
      Logger.error('Reset password error: $error');
      return NetworkErrorHandler.handleError<void>(error);
    }
  }
}
