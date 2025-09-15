import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error/app_error.dart';
import '../../../core/models/user.dart';
import '../../../data/repositories/base_repository.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/result.dart';
import '../../../core/providers/user_provider.dart';

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
      errorMessage: errorMessage ?? this.errorMessage,
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

  /// Initialize authentication state
  Future<void> _initializeAuth() async {
    try {
      final session = await _authRepository.getCurrentSession();
      if (session != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          isStudent: session.user.role.isStudent,
        );
        // Populate user provider so UI can render user-dependent screens
        _ref.read(userProvider.notifier).updateUser(session.user);
      } else {
        state = AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      debugPrint('AuthNotifier: Error initializing auth: $e');
      state = AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Sign up with email and password
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    debugPrint('🔵 AuthNotifier: Starting signup process...');
    debugPrint('🔵 Email: $email, Role: $role');

    state = AuthState(status: AuthStatus.loading);

    try {
      // Create signup credentials
      final credentials = RegisterData(
        name: fullName,
        email: email,
        password: password,
        role: role,
      );

      debugPrint('🔵 AuthNotifier: Calling repository signup...');

      // Call repository
      final result = await _authRepository.signUp(credentials);

      debugPrint(
          '🔵 AuthNotifier: Repository result - Success: ${result.isSuccess}');

      if (result.isSuccess && result.data != null) {
        final session = result.data!;

        debugPrint('🟢 AuthNotifier: Signup successful!');
        debugPrint(
            '🟢 User: ${session.user.email}, Role: ${session.user.role}');

        // Update state with success
        state = AuthState(
          status: AuthStatus.authenticated,
          isStudent: session.user.role.isStudent,
        );

        // Update user provider with the new user
        _ref.read(userProvider.notifier).updateUser(session.user);

        debugPrint(
            '🟢 AuthNotifier: State updated - Status: ${state.status}, IsStudent: ${state.isStudent}');
      } else {
        // Handle sign up failure
        final appError = result.error ??
            const AuthError(
                message: 'Sign up failed. Please try again.',
                code: 'SIGNUP_FAILED');

        debugPrint('🔴 AuthNotifier: Signup failed: ${appError.message}');

        state = AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: appError.message,
          isStudent: true,
        );

        throw appError;
      }
    } catch (e) {
      debugPrint('🔴 AuthNotifier: Signup exception: $e');

      if (e is! AppError) {
        final appError = ErrorHandler.handleError(e);
        state = AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: appError.message,
          isStudent: true,
        );
        throw appError;
      }

      rethrow;
    }
  }

  /// Sign in with email and password
  Future<void> login({
    required String email,
    required String password,
  }) async {
    debugPrint('🔵 AuthNotifier: Starting login process...');
    debugPrint('🔵 Email: $email');

    try {
      // Set loading state
      state = state.copyWith(
        status: AuthStatus.loading,
        errorMessage: null,
      );

      // Create login credentials
      final credentials = LoginCredentials(
        email: email,
        password: password,
      );

      debugPrint('🔵 AuthNotifier: Calling repository login...');

      // Call repository
      final result = await _authRepository.signIn(credentials);

      debugPrint(
          '🔵 AuthNotifier: Repository result - Success: ${result.isSuccess}');

      if (result.isSuccess && result.data != null) {
        final session = result.data!;

        debugPrint('🟢 AuthNotifier: Login successful!');
        debugPrint(
            '🟢 User: ${session.user.email}, Role: ${session.user.role}');

        state = AuthState(
          status: AuthStatus.authenticated,
          isStudent: session.user.role.isStudent,
          errorMessage: null,
        );

        // Update user provider with the logged-in user
        _ref.read(userProvider.notifier).updateUser(session.user);

        debugPrint(
            '🟢 AuthNotifier: State updated - Status: ${state.status}, IsStudent: ${state.isStudent}');
      } else {
        final error = result.error!;

        debugPrint('🔴 AuthNotifier: Login failed: ${error.message}');

        state = AuthState(
          status: AuthStatus.error,
          errorMessage: error.message,
          isStudent: true, // Default to student for error state
        );

        // Re-throw the error for UI handling
        throw error;
      }
    } catch (e) {
      debugPrint('🔴 AuthNotifier: Login exception: $e');

      if (e is! AppError) {
        final appError = ErrorHandler.handleError(e);
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: appError.message,
          isStudent: true,
        );
        throw appError;
      }

      rethrow;
    }
  }

  void logout() async {
    debugPrint('AuthNotifier: Logout started...');

    try {
      // Call repository to sign out
      await _authRepository.signOut();

      // Update state
      state = AuthState(status: AuthStatus.unauthenticated);

      // Clear user data
      _ref.read(userProvider.notifier).logout();

      debugPrint('AuthNotifier: Logout successful');
    } catch (e) {
      debugPrint('AuthNotifier: Logout failed: $e');
      // Still update state even if repository call fails
      state = AuthState(status: AuthStatus.unauthenticated);
      _ref.read(userProvider.notifier).logout();
    }
  }
}
