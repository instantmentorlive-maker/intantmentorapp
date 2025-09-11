import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/advanced_auth_service.dart';
import '../session/session_manager_service.dart';
import '../utils/result.dart';
import 'repository_providers.dart';

/// Provider for Advanced Authentication Service
final advancedAuthServiceProvider = Provider<AdvancedAuthService>((ref) {
  final authService = AdvancedAuthService();
  final authRepository = ref.read(authRepositoryProvider);
  authService.initialize(authRepository);
  return authService;
});

/// Provider for biometric availability
final biometricAvailabilityProvider = FutureProvider<bool>((ref) async {
  final authService = ref.read(advancedAuthServiceProvider);
  final result = await authService.isBiometricAvailable();
  return result.isSuccess ? result.data! : false;
});

/// Provider for biometric enabled status
final biometricEnabledProvider = FutureProvider<bool>((ref) async {
  final authService = ref.read(advancedAuthServiceProvider);
  final result = await authService.isBiometricEnabled();
  return result.isSuccess ? result.data! : false;
});

/// Provider for current authentication status
final authenticationStatusProvider = FutureProvider<bool>((ref) async {
  final authService = ref.read(advancedAuthServiceProvider);
  final result = await authService.isAuthenticated();
  return result.isSuccess ? result.data! : false;
});

/// Provider for current session
final currentSessionProvider = FutureProvider((ref) async {
  final authService = ref.read(advancedAuthServiceProvider);
  final result = await authService.getCurrentSession();
  return result.isSuccess ? result.data : null;
});

/// Provider for all user sessions
final allSessionsProvider = FutureProvider((ref) async {
  final authService = ref.read(advancedAuthServiceProvider);
  final result = await authService.getAllSessions();
  return result.isSuccess ? result.data! : <EnhancedSession>[];
});
