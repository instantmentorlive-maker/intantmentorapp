import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/utils/result.dart';
import '../../../data/repositories/base_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final bool isStudent;

  AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.isStudent = true,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    bool? isStudent,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      isStudent: isStudent ?? this.isStudent,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.read(authRepositoryProvider);
  return AuthNotifier(authRepository, ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final Ref _ref;

  AuthNotifier(this._authRepository, this._ref) : super(AuthState()) {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      final session = await _authRepository.getCurrentSession();
      if (session != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          isStudent: session.user.role.isStudent,
        );
        _ref.read(userProvider.notifier).updateUser(session.user);
      } else {
        state = AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      debugPrint('AuthNotifier: Error initializing auth: $e');
      state = AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    state = AuthState(status: AuthStatus.loading);

    try {
      final data = RegisterData(
        name: fullName,
        email: email,
        password: password,
        role: role,
      );

      final result = await _authRepository.signUp(data);

      if (result.isSuccess && result.data != null) {
        final session = result.data!;
        state = AuthState(
          status: AuthStatus.authenticated,
          isStudent: session.user.role.isStudent,
        );
        _ref.read(userProvider.notifier).updateUser(session.user);
      } else {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: result.error?.message ?? 'Sign up failed',
        );
        if (result.error != null) throw result.error!;
      }
    } catch (e) {
      debugPrint('AuthNotifier: Signup failed: $e');
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = AuthState(status: AuthStatus.loading);

    try {
      final credentials = LoginCredentials(
        email: email,
        password: password,
      );

      final result = await _authRepository.signIn(credentials);

      if (result.isSuccess && result.data != null) {
        final session = result.data!;
        state = AuthState(
          status: AuthStatus.authenticated,
          isStudent: session.user.role.isStudent,
        );
        _ref.read(userProvider.notifier).updateUser(session.user);
      } else {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: result.error?.message ?? 'Login failed',
        );
        if (result.error != null) throw result.error!;
      }
    } catch (e) {
      debugPrint('AuthNotifier: Login failed: $e');
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  void logout() async {
    try {
      await _authRepository.signOut();
      state = AuthState(status: AuthStatus.unauthenticated);
      _ref.read(userProvider.notifier).logout();
    } catch (e) {
      debugPrint('AuthNotifier: Logout failed: $e');
      state = AuthState(status: AuthStatus.unauthenticated);
      _ref.read(userProvider.notifier).logout();
    }
  }
}
