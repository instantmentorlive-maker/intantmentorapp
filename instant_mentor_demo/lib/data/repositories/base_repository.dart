import '../../core/models/user.dart';
import '../../core/utils/result.dart';

/// Base interface for authentication repository
abstract class AuthRepository {
  /// Sign in with email and password
  Future<Result<Session>> signIn(LoginCredentials credentials);
  
  /// Sign up with user registration data
  Future<Result<Session>> signUp(RegisterData registerData);
  
  /// Sign out the current user
  Future<Result<void>> signOut();
  
  /// Refresh the authentication token
  Future<Result<AuthToken>> refreshToken(String refreshToken);
  
  /// Get the current user session
  Future<Session?> getCurrentSession();
  
  /// Check if user is authenticated
  Future<bool> isAuthenticated();
  
  /// Clear all authentication data
  Future<void> clearAuthData();
}
