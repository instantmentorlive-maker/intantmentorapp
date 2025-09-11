import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../config/app_config.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/repositories/mock_auth_repository.dart';
import '../../data/repositories/http_auth_repository.dart';

/// Provider for the authentication repository
/// Automatically switches between mock and HTTP implementation based on environment
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = AppConfig.instance;
  
  // Use mock implementation in development for testing
  if (config.isDevelopment) {
    return MockAuthRepository();
  }
  
  // Use HTTP implementation for staging and production
  return HttpAuthRepository();
});

/// Provider for mock auth repository (for testing)
final mockAuthRepositoryProvider = Provider<MockAuthRepository>((ref) {
  return MockAuthRepository();
});

/// Provider for HTTP auth repository (for production)
final httpAuthRepositoryProvider = Provider<HttpAuthRepository>((ref) {
  return HttpAuthRepository();
});

/// Provider for checking if user is authenticated
final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final authRepository = ref.read(authRepositoryProvider);
  return await authRepository.isAuthenticated();
});

/// Provider for getting current session
final currentSessionProvider = FutureProvider<Session?>((ref) async {
  final authRepository = ref.read(authRepositoryProvider);
  return await authRepository.getCurrentSession();
});
