import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user.dart' as domain; // Domain user model
import '../services/supabase_service.dart';
import 'sessions_provider.dart'; // demoSessionsProvider
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
  bool _isInitializing = true;

  AuthNotifier(this._ref, this._supabaseService) : super(const AuthState()) {
    // Delay initialization to ensure all providers are ready
    Future.microtask(() => _initializeAuth());

    // Set initialization flag to false after a reasonable delay
    Future.delayed(const Duration(seconds: 3), () {
      _isInitializing = false;
      debugPrint('🔐 AuthProvider: Initialization period ended');
    });
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
      final roleString = (meta['role'] ?? meta['user_role'] ?? '').toString();
      domain.UserRole role;

      if (roleString.isEmpty || roleString == 'null') {
        // No role in metadata, default to mentor for existing users
        // This handles users created before role system was implemented
        role = domain.UserRole.mentor;
        debugPrint(
            '🔍 AuthProvider: No role metadata found, defaulting to mentor for existing user');
      } else {
        try {
          role = domain.UserRole.fromString(roleString);
        } catch (_) {
          // Invalid role string, default to mentor
          role = domain.UserRole.mentor;
          debugPrint(
              '🔍 AuthProvider: Invalid role metadata, defaulting to mentor');
        }
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

        // Migrate any demo sessions created while unauthenticated to this user id
        try {
          _ref
              .read(demoSessionsProvider.notifier)
              .migrateSessionsToUser(supabaseUser.id);
        } catch (e) {
          debugPrint('Failed to migrate demo sessions: $e');
        }

        // Ensure user profile exists in database
        _ensureUserProfileExists(supabaseUser, fullName, roleString);
      }
    });
  }

  /// Ensure user profile exists in the database
  Future<void> _ensureUserProfileExists(
      User supabaseUser, String fullName, String role) async {
    try {
      final existingProfile = await _supabaseService.getUserProfile();
      if (existingProfile == null) {
        debugPrint(
            '🔵 AuthProvider: Creating missing user profile for ${supabaseUser.id}');
        await _supabaseService.upsertUserProfile(
          profileData: {
            'full_name': fullName,
            'email': supabaseUser.email,
          },
        );
        debugPrint('🟢 AuthProvider: User profile created successfully');
      }

      // Create mentor profile if user is a mentor
      if (role == 'mentor') {
        await _ensureMentorProfileExists(supabaseUser, fullName);
      }
    } catch (e) {
      debugPrint('⚠️ AuthProvider: Failed to ensure user profile exists: $e');
      // Don't fail auth sync if profile creation fails
    }
  }

  /// Ensure mentor profile exists in the database
  Future<void> _ensureMentorProfileExists(
      User supabaseUser, String fullName) async {
    try {
      // Check if mentor profile exists
      final existingMentorProfile = await SupabaseService.instance.client
          .from('mentor_profiles')
          .select('id')
          .eq('user_id', supabaseUser.id)
          .maybeSingle();

      if (existingMentorProfile == null) {
        debugPrint(
            '🔵 AuthProvider: Creating missing mentor profile for ${supabaseUser.id}');
        await SupabaseService.instance.client.from('mentor_profiles').insert({
          'user_id': supabaseUser.id,
          'title': 'Mentor',
          'subjects': [],
          'years_experience': 0,
          'hourly_rate': 0,
          'is_available': true,
          'is_verified': false,
        });
        debugPrint('🟢 AuthProvider: Mentor profile created successfully');
      }
    } catch (e) {
      debugPrint('⚠️ AuthProvider: Failed to ensure mentor profile exists: $e');
    }
  }

  /// Initialize authentication state
  void _initializeAuth() {
    final currentUser = _supabaseService.currentUser;
    debugPrint(
        '🔐 AuthProvider: Initializing auth - Current user: ${currentUser?.id}');

    state = state.copyWith(
      user: currentUser,
      isAuthenticated: currentUser != null,
    );

    // Defer user sync to avoid initialization conflicts
    if (currentUser != null) {
      _syncDomainUser(currentUser);
    } else {
      // For a clean user experience, don't auto-login with demo account
      // This prevents error states from appearing on the login screen
      debugPrint('🔐 AuthProvider: No current user, ready for manual login');
    }

    // Listen to auth state changes (Supabase emits AuthState objects via onAuthStateChange)
    _supabaseService.authStateChanges.listen((authEvent) {
      final userId = authEvent.session?.user.id ?? 'null';
      debugPrint(
          '🔐 AuthProvider: Auth event received - Event: ${authEvent.event}, User: $userId');

      final newUser = authEvent.session?.user;
      final wasAuthenticated = state.isAuthenticated;
      final isNowAuthenticated = newUser != null;

      // Ignore SIGNED_OUT events during initialization unless explicitly forced
      if (authEvent.event.name == 'SIGNED_OUT' && _isInitializing) {
        debugPrint(
            '🚫 AuthProvider: Ignoring SIGNED_OUT event during initialization');
        return;
      }

      // Log state transitions
      if (wasAuthenticated && !isNowAuthenticated) {
        debugPrint(
            '🔐 AuthProvider: User signed out - Event: ${authEvent.event}');
      } else if (!wasAuthenticated && isNowAuthenticated) {
        debugPrint(
            '🔐 AuthProvider: User signed in - Event: ${authEvent.event}');
      }

      state = state.copyWith(
        user: newUser,
        isAuthenticated: isNowAuthenticated,
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
    state = state.copyWith(isLoading: true);

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

      if (response.user != null && response.session != null) {
        // User is fully authenticated with a session
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
      } else if (response.user != null && response.session == null) {
        // User created but email confirmation required
        debugPrint(
            '🟡 AuthProvider: User created but email confirmation required');
        state = state.copyWith(
          isLoading: false,
          error:
              'Account created successfully! Please check your email and click the confirmation link to complete signup.',
        );
      }
    } on AuthException catch (e) {
      // Handle AuthException with clean message
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      // Handle other errors with raw error message for debugging
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);

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
      // Handle other errors with raw error message for debugging
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Sign out
  Future<void> signOut({bool forced = false}) async {
    // Prevent signout during initialization unless forced
    if (_isInitializing && !forced) {
      debugPrint('🚫 AuthProvider: Blocking signOut during initialization');
      return;
    }

    // Add stack trace to see what's calling signOut
    debugPrint('🔐 AuthProvider: Signing out user... Call stack:');
    debugPrint(StackTrace.current.toString().split('\n').take(5).join('\n'));

    state = state.copyWith(isLoading: true);

    try {
      await _supabaseService.signOut();

      // Clear all auth state
      state = const AuthState(
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
      );

      // Clear domain user
      _ref.read(userProvider.notifier).logout();
      debugPrint('✅ AuthProvider: Successfully signed out');
    } catch (e) {
      debugPrint('❌ AuthProvider: Sign out failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true);

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
    state = state.copyWith(isLoading: true);

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
    state = state.copyWith(isLoading: true);

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
    state = state.copyWith(isLoading: true);

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
    state = state.copyWith(isLoading: true);

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
    state = state.copyWith(isLoading: true);

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
    state = state.copyWith(isLoading: true);

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
    state = state.copyWith(isLoading: true);

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
    state = state.copyWith(isLoading: true);

    try {
      await _supabaseService.upsertUserProfile(profileData: profileData);

      // Profile updated successfully - just update loading state
      // The SupabaseService already updated the auth user metadata
      // We'll let the user data refresh naturally on next auth state check
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
    state = state.copyWith();
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
