import '../models/user.dart';
import '../utils/result.dart';

/// Authentication repository interface
abstract class AuthRepository {
  /// Sign in with email and password
  Future<Result<Session>> signIn(LoginCredentials credentials);
  
  /// Sign up with registration data
  Future<Result<Session>> signUp(RegisterData data);
  
  /// Sign out current user
  Future<Result<void>> signOut();
  
  /// Refresh authentication token
  Future<Result<AuthToken>> refreshToken(String refreshToken);
  
  /// Get current session if exists
  Future<Result<Session?>> getCurrentSession();
  
  /// Check if user is authenticated
  Future<bool> isAuthenticated();
  
  /// Clear stored authentication data
  Future<void> clearAuthData();
}
