import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/user.dart' as domain; // Domain user model
import 'user_provider.dart'; // Domain user provider

/// Authentication state
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

/// Authentication notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseService _supabaseService;
  final Ref _ref;

  AuthNotifier(this._ref, this._supabaseService) : super(const AuthState()) {
    // Delay initialization to ensure all providers are ready
    Future.microtask(() => _initializeAuth());
  }

  /// Map Supabase user to domain user and update userProvider
  Future<void> _syncDomainUser(User? supabaseUser) async {
    // Use Future.microtask to avoid updating during provider initialization
    await Future.microtask(() {
      if (supabaseUser == null) {
        _ref.read(userProvider.notifier).logout();
        return;
      }

      // Extract metadata
      final meta = supabaseUser.userMetadata ?? {};
      final fullName = (meta['full_name'] ??
              meta['name'] ??
              supabaseUser.email?.split('@').first ??
              'User')
          .toString();
      final roleString =
          (meta['role'] ?? meta['user_role'] ?? 'student').toString();
      domain.UserRole role;
      try {
        role = domain.UserRole.fromString(roleString);
      } catch (_) {
        role = domain.UserRole.student; // default fallback
      }

      final existing = _ref.read(userProvider);
      // Only update if changed or null
      if (existing == null || existing.id != supabaseUser.id) {
        _ref.read(userProvider.notifier).updateUser(
              domain.User(
                id: supabaseUser.id,
                name: fullName,
                email: supabaseUser.email ?? '',
                role: role,
                createdAt: DateTime.now(),
                lastLoginAt: DateTime.now(),
              ),
            );
      }
    });
  }

  /// Initialize authentication state
  void _initializeAuth() {
    final currentUser = _supabaseService.currentUser;
    state = state.copyWith(
      user: currentUser,
      isAuthenticated: currentUser != null,
    );

    // Defer user sync to avoid initialization conflicts
    if (currentUser != null) {
      _syncDomainUser(currentUser);
    }

    // Listen to auth state changes (Supabase emits AuthState objects via onAuthStateChange)
    _supabaseService.authStateChanges.listen((authEvent) {
      final newUser = authEvent.session?.user;
      state = state.copyWith(
        user: newUser,
        isAuthenticated: newUser != null,
        error: null,
      );
      _syncDomainUser(newUser);
    });
  }

  /// Sign up with email and password
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    Map<String, dynamic>? additionalData,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final metadata = {
        'full_name': fullName,
        ...?additionalData,
      };

      final response = await _supabaseService.signUpWithEmail(
        email: email,
        password: password,
        metadata: metadata,
      );

      if (response.user != null) {
        // Send welcome email - TEMPORARILY DISABLED
        // await _emailService.sendWelcomeEmail(
        //   userEmail: email,
        //   userName: fullName,
        // );

        // Create user profile - handle failure gracefully
        try {
          await _supabaseService.upsertUserProfile(
            profileData: {
              'full_name': fullName,
              'email': email,
              ...?additionalData,
            },
          );
        } catch (profileError) {
          debugPrint('🔴 Profile creation failed: $profileError');
          // Continue with signup even if profile creation fails
        }

        state = state.copyWith(
          user: response.user,
          isAuthenticated: true,
          isLoading: false,
        );
        _syncDomainUser(response.user); // sync domain user model
      }
    } on AuthException catch (e) {
      // Handle AuthException with clean message
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      // Handle other errors with generic message
      String errorMessage = 'Signup failed. Please try again.';

      // Extract meaningful error message from Supabase errors
      if (e.toString().contains('User already registered')) {
        errorMessage =
            'An account with this email already exists. Please sign in instead.';
      } else if (e.toString().contains('email rate limit')) {
        errorMessage =
            'Too many signup attempts. Please wait before trying again.';
      } else if (e.toString().contains('password')) {
        errorMessage =
            'Password does not meet requirements. Please use at least 6 characters.';
      }

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
    }
  }

  /// Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _supabaseService.signInWithEmail(
        email: email,
        password: password,
      );

      if (response.user != null) {
        state = state.copyWith(
          user: response.user,
          isAuthenticated: true,
          isLoading: false,
        );
        _syncDomainUser(response.user); // sync domain user model
      }
    } on AuthException catch (e) {
      // Handle AuthException with clean message
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      // Handle other errors with generic message
      String errorMessage = 'Login failed. Please try again.';

      // Extract meaningful error message from Supabase errors
      if (e.toString().contains('Invalid login credentials')) {
        errorMessage =
            'Invalid email or password. Please check your credentials.';
      } else if (e.toString().contains('Email not confirmed')) {
        errorMessage = 'Please verify your email address before signing in.';
      } else if (e.toString().contains('Too many requests')) {
        errorMessage =
            'Too many login attempts. Please wait before trying again.';
      }

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _supabaseService.signOut();
      state = state.copyWith(
        user: null,
        isAuthenticated: false,
        isLoading: false,
      );
      _syncDomainUser(null); // clear domain user
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _supabaseService.resetPassword(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Set new password for the currently authenticated user
  Future<void> setNewPassword(String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Supabase updates password for current session user
      await _supabaseService.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      state = state.copyWith(isLoading: false);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send email OTP for verification
  Future<void> sendEmailOTP(String email,
      {bool shouldCreateUser = true}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _supabaseService.sendEmailOTP(email);
      state = state.copyWith(isLoading: false);
    } on AuthApiException catch (e) {
      // Gracefully degrade to informing the UI when OTP is disabled
      final msg = e.message.toLowerCase();
      if (msg.contains('otp_disabled') ||
          msg.contains('signups not allowed for otp')) {
        state = state.copyWith(
          isLoading: false,
          error:
              'Email OTP is disabled for this project. Use password sign-in instead.',
        );
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Verify email OTP
  Future<void> verifyEmailOTP({
    required String email,
    required String otp,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _supabaseService.verifyEmailOTP(email: email, otp: otp);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Resend email OTP
  Future<void> resendEmailOTP(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _supabaseService.resendEmailOTP(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Send phone OTP for verification
  Future<void> sendPhoneOTP(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _supabaseService.sendPhoneOTP(phoneNumber);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Verify phone OTP
  Future<void> verifyPhoneOTP({
    required String phone,
    required String otp,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _supabaseService.verifyPhoneOTP(phone: phone, otp: otp);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Resend phone OTP
  Future<void> resendPhoneOTP(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _supabaseService.resendPhoneOTP(phoneNumber);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Update user profile
  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _supabaseService.upsertUserProfile(profileData: profileData);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Providers
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService.instance;
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthNotifier(ref, supabaseService);
});

/// User profile provider
final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authState = ref.watch(authProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);

  if (!authState.isAuthenticated) return null;

  return await supabaseService.getUserProfile();
});

/// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user;
});

/// Authentication status provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isAuthenticated;
});
