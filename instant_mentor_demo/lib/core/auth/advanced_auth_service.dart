import 'package:local_auth/local_auth.dart';
import '../utils/logger.dart';
import '../utils/result.dart';
import '../error/app_error.dart';
import '../models/user.dart';
import '../auth/biometric_service.dart';
import '../session/session_manager_service.dart';
import '../../data/repositories/base_repository.dart';

/// Advanced authentication service with biometric and multi-session support
class AdvancedAuthService {
  static final AdvancedAuthService _instance = AdvancedAuthService._internal();
  factory AdvancedAuthService() => _instance;
  AdvancedAuthService._internal();

  final BiometricService _biometricService = BiometricService();
  final SessionManagerService _sessionManager = SessionManagerService();
  AuthRepository? _authRepository;
  
  /// Initialize with auth repository
  void initialize(AuthRepository authRepository) {
    _authRepository = authRepository;
    Logger.info('AdvancedAuthService: Initialized');
  }
  
  /// Sign in with credentials and optional biometric setup
  Future<Result<Session>> signIn(
    LoginCredentials credentials, {
    bool setupBiometric = false,
    bool rememberMe = false,
    bool autoLogin = false,
  }) async {
    if (_authRepository == null) {
      return Failure(
        AppGeneralError.unknown('Authentication service not initialized'),
      );
    }
    
    try {
      Logger.info('AdvancedAuthService: Signing in user ${credentials.email}');
      
      // Perform sign in
      final signInResult = await _authRepository!.signIn(credentials);
      if (signInResult.isFailure) {
        return Failure(signInResult.error!);
      }
      
      final session = signInResult.data!;
      
      // Store session with enhanced features
      final storeResult = await _sessionManager.storeSession(session);
      if (storeResult.isFailure) {
        Logger.warning('AdvancedAuthService: Could not store session - ${storeResult.error}');
      }
      
      // Set preferences
      await _sessionManager.setRememberMeEnabled(rememberMe);
      await _sessionManager.setAutoLoginEnabled(autoLogin);
      
      // Setup biometric if requested and available
      if (setupBiometric) {
        final biometricResult = await _setupBiometricAuth(session);
        if (biometricResult.isFailure) {
          Logger.warning('AdvancedAuthService: Could not setup biometric - ${biometricResult.error}');
        }
      }
      
      Logger.info('AdvancedAuthService: Sign in successful for ${session.user.email}');
      return Success(session);
      
    } catch (e) {
      Logger.error('AdvancedAuthService: Error during sign in - $e');
      return Failure(
        AppGeneralError.unknown('Sign in failed: $e'),
      );
    }
  }
  
  /// Sign in using biometric authentication
  Future<Result<Session>> signInWithBiometric() async {
    try {
      Logger.info('AdvancedAuthService: Attempting biometric sign in');
      
      // Check if biometric is enabled
      final biometricEnabledResult = await _sessionManager.isBiometricEnabled();
      if (biometricEnabledResult.isFailure || !biometricEnabledResult.data!) {
        return Failure(
          AuthError(
            message: 'Biometric authentication is not enabled.',
            code: 'BIOMETRIC_NOT_ENABLED',
          ),
        );
      }
      
      // Perform biometric authentication
      final authResult = await _biometricService.authenticate(
        reason: 'Please verify your identity to access your account',
        useErrorDialogs: true,
        stickyAuth: true,
      );
      
      if (authResult.isFailure) {
        return Failure(authResult.error!);
      }
      
      if (!authResult.data!) {
        return Failure(
          AuthError(
            message: 'Biometric authentication was not successful.',
            code: 'BIOMETRIC_AUTH_FAILED',
          ),
        );
      }
      
      // Get current session
      final sessionResult = await _sessionManager.getCurrentSession();
      if (sessionResult.isFailure) {
        return Failure(sessionResult.error!);
      }
      
      if (sessionResult.data == null) {
        return Failure(
          AuthError(
            message: 'No saved session found. Please sign in with your credentials.',
            code: 'NO_SAVED_SESSION',
          ),
        );
      }
      
      Logger.info('AdvancedAuthService: Biometric sign in successful');
      return Success(sessionResult.data!);
      
    } catch (e) {
      Logger.error('AdvancedAuthService: Error during biometric sign in - $e');
      return Failure(
        AppGeneralError.unknown('Biometric sign in failed: $e'),
      );
    }
  }
  
  /// Attempt auto-login
  Future<Result<Session?>> attemptAutoLogin() async {
    try {
      Logger.info('AdvancedAuthService: Attempting auto-login');
      
      // Check if auto-login is enabled
      final autoLoginEnabledResult = await _sessionManager.isAutoLoginEnabled();
      if (autoLoginEnabledResult.isFailure || !autoLoginEnabledResult.data!) {
        Logger.info('AdvancedAuthService: Auto-login is disabled');
        return Success(null);
      }
      
      // Get current session
      final sessionResult = await _sessionManager.getCurrentSession();
      if (sessionResult.isFailure) {
        Logger.warning('AdvancedAuthService: Auto-login failed - ${sessionResult.error}');
        return Success(null);
      }
      
      if (sessionResult.data == null) {
        Logger.info('AdvancedAuthService: No saved session for auto-login');
        return Success(null);
      }
      
      final session = sessionResult.data!;
      
      // Validate session is still valid
      if (_authRepository != null) {
        final isAuthenticatedResult = await _authRepository!.isAuthenticated();
        if (!isAuthenticatedResult) {
          Logger.info('AdvancedAuthService: Saved session is no longer valid');
          await _sessionManager.clearSession(session.token.accessToken);
          return Success(null);
        }
      }
      
      Logger.info('AdvancedAuthService: Auto-login successful for ${session.user.email}');
      return Success(session);
      
    } catch (e) {
      Logger.error('AdvancedAuthService: Error during auto-login - $e');
      return Success(null); // Don't fail the app, just don't auto-login
    }
  }
  
  /// Setup biometric authentication
  Future<Result<void>> setupBiometricAuth(Session session) async {
    return await _setupBiometricAuth(session);
  }
  
  /// Internal biometric setup
  Future<Result<void>> _setupBiometricAuth(Session session) async {
    try {
      Logger.info('AdvancedAuthService: Setting up biometric authentication');
      
      // Check if biometrics are available
      final availabilityResult = await _biometricService.isAvailable();
      if (availabilityResult.isFailure || !availabilityResult.data!) {
        return Failure(
          AuthError(
            message: 'Biometric authentication is not available on this device.',
            code: 'BIOMETRIC_NOT_AVAILABLE',
          ),
        );
      }
      
      // Check if biometrics are enrolled
      final enrolledResult = await _biometricService.hasEnrolledBiometrics();
      if (enrolledResult.isFailure || !enrolledResult.data!) {
        return Failure(
          AuthError(
            message: 'No biometrics are enrolled on this device. Please set up fingerprint or face recognition in your device settings.',
            code: 'BIOMETRIC_NOT_ENROLLED',
          ),
        );
      }
      
      // Test biometric authentication
      final authResult = await _biometricService.authenticate(
        reason: 'Please verify your biometric to enable biometric sign in',
        useErrorDialogs: true,
        stickyAuth: true,
      );
      
      if (authResult.isFailure) {
        return Failure(authResult.error!);
      }
      
      if (!authResult.data!) {
        return Failure(
          AuthError(
            message: 'Biometric setup was cancelled or failed.',
            code: 'BIOMETRIC_SETUP_FAILED',
          ),
        );
      }
      
      // Enable biometric authentication
      await _sessionManager.setBiometricEnabled(true);
      
      Logger.info('AdvancedAuthService: Biometric authentication setup complete');
      return Success(null);
      
    } catch (e) {
      Logger.error('AdvancedAuthService: Error setting up biometric auth - $e');
      return Failure(
        AppGeneralError.unknown('Failed to setup biometric authentication: $e'),
      );
    }
  }
  
  /// Disable biometric authentication
  Future<Result<void>> disableBiometricAuth() async {
    try {
      await _sessionManager.setBiometricEnabled(false);
      Logger.info('AdvancedAuthService: Biometric authentication disabled');
      return Success(null);
    } catch (e) {
      Logger.error('AdvancedAuthService: Error disabling biometric auth - $e');
      return Failure(
        AppGeneralError.unknown('Failed to disable biometric authentication: $e'),
      );
    }
  }
  
  /// Sign out from current session
  Future<Result<void>> signOut() async {
    if (_authRepository == null) {
      return Failure(
        AppGeneralError.unknown('Authentication service not initialized'),
      );
    }
    
    try {
      Logger.info('AdvancedAuthService: Signing out');
      
      // Get current session to identify it
      final sessionResult = await _sessionManager.getCurrentSession();
      String? sessionId;
      if (sessionResult.isSuccess && sessionResult.data != null) {
        sessionId = sessionResult.data!.token.accessToken;
      }
      
      // Clear from auth repository
      final signOutResult = await _authRepository!.signOut();
      if (signOutResult.isFailure) {
        Logger.warning('AdvancedAuthService: Repository sign out failed - ${signOutResult.error}');
      }
      
      // Clear current session
      if (sessionId != null) {
        await _sessionManager.clearSession(sessionId);
      }
      
      Logger.info('AdvancedAuthService: Sign out complete');
      return Success(null);
      
    } catch (e) {
      Logger.error('AdvancedAuthService: Error during sign out - $e');
      return Failure(
        AppGeneralError.unknown('Sign out failed: $e'),
      );
    }
  }
  
  /// Sign out from all sessions
  Future<Result<void>> signOutFromAllSessions() async {
    if (_authRepository == null) {
      return Failure(
        AppGeneralError.unknown('Authentication service not initialized'),
      );
    }
    
    try {
      Logger.info('AdvancedAuthService: Signing out from all sessions');
      
      // Clear from auth repository
      final signOutResult = await _authRepository!.signOut();
      if (signOutResult.isFailure) {
        Logger.warning('AdvancedAuthService: Repository sign out failed - ${signOutResult.error}');
      }
      
      // Clear all sessions
      await _sessionManager.clearAllSessions();
      
      // Reset authentication preferences
      await _sessionManager.setBiometricEnabled(false);
      await _sessionManager.setRememberMeEnabled(false);
      await _sessionManager.setAutoLoginEnabled(false);
      
      Logger.info('AdvancedAuthService: Sign out from all sessions complete');
      return Success(null);
      
    } catch (e) {
      Logger.error('AdvancedAuthService: Error signing out from all sessions - $e');
      return Failure(
        AppGeneralError.unknown('Sign out from all sessions failed: $e'),
      );
    }
  }
  
  /// Get current session
  Future<Result<Session?>> getCurrentSession() async {
    return await _sessionManager.getCurrentSession();
  }
  
  /// Check authentication status
  Future<Result<bool>> isAuthenticated() async {
    try {
      final sessionResult = await getCurrentSession();
      if (sessionResult.isFailure) {
        return Success(false);
      }
      
      if (sessionResult.data == null) {
        return Success(false);
      }
      
      // Double-check with auth repository if available
      if (_authRepository != null) {
        final repoResult = await _authRepository!.isAuthenticated();
        return Success(repoResult);
      }
      
      return Success(true);
      
    } catch (e) {
      Logger.error('AdvancedAuthService: Error checking authentication - $e');
      return Success(false);
    }
  }
  
  /// Get all user sessions
  Future<Result<List<EnhancedSession>>> getAllSessions() async {
    return await _sessionManager.getAllSessions();
  }
  
  /// Switch to different session
  Future<Result<void>> switchToSession(String sessionId) async {
    return await _sessionManager.switchToSession(sessionId);
  }
  
  /// Check if biometric authentication is available
  Future<Result<bool>> isBiometricAvailable() async {
    return await _biometricService.isAvailable();
  }
  
  /// Check if biometric authentication is enabled
  Future<Result<bool>> isBiometricEnabled() async {
    return await _sessionManager.isBiometricEnabled();
  }
  
  /// Get available biometric types
  Future<Result<List<BiometricType>>> getAvailableBiometrics() async {
    return await _biometricService.getAvailableBiometrics();
  }
}
