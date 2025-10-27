import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// A minimal fake implementation of the SupabaseService surface used in tests.
/// This intentionally implements only the pieces needed by providers and UI
/// in unit/widget tests: currentUser, authStateChanges stream, and simple
/// no-op database helpers.
class FakeSupabaseService {
  // Simulate a signed-out state by default
  User? _user;
  final _authController = StreamController<dynamic>.broadcast();

  FakeSupabaseService({User? initialUser}) {
    _user = initialUser;
    // Emit an initial auth state as a simple map to avoid depending on SDK types
    _authController.add({'type': 'INITIAL', 'user': _user});
  }

  User? get currentUser => _user;

  Stream<dynamic> get authStateChanges => _authController.stream;

  // Simple sign-in simulation
  Future<AuthResponse> signInWithEmail(
      {required String email, required String password}) async {
    // Create a lightweight User using the Supabase SDK type constructor
    final user = User(
      id: 'test_user',
      email: email,
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );

    _user = user;
    // Supabase's AuthResponse is a class from the SDK; construct a minimal one
    final response = AuthResponse(user: user);
    // Emit signed-in event (as simple map)
    _authController.add({'type': 'SIGNED_IN', 'user': _user});
    return response;
  }

  Future<AuthResponse> signUpWithEmail(
      {required String email,
      required String password,
      Map<String, dynamic>? metadata}) async {
    return signInWithEmail(email: email, password: password);
  }

  Future<void> signOut() async {
    _user = null;
    _authController.add({'type': 'SIGNED_OUT', 'user': null});
  }

  /// Lightweight getUserProfile stub
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (_user == null) return null;
    return {
      'id': _user!.id,
      'full_name': _user!.email?.split('@').first ?? 'Test User',
      'email': _user!.email,
      'avatar_url': null,
    };
  }

  /// Lightweight upsert stub
  Future<void> upsertUserProfile(
      {required Map<String, dynamic> profileData}) async {
    // no-op in tests
  }

  // Expose a minimal client-like object for callers that reference client.auth
  // We provide only what tests might access: auth.currentUser and onAuthStateChange
  dynamic get client => _FakeClient(this);
}

class _FakeClient {
  final FakeSupabaseService _parent;
  _FakeClient(this._parent);

  _FakeAuth get auth => _FakeAuth(_parent);
}

class _FakeAuth {
  final FakeSupabaseService _parent;
  _FakeAuth(this._parent);

  User? get currentUser => _parent.currentUser;

  Stream<dynamic> get onAuthStateChange => _parent.authStateChanges;

  Future<void> signOut({SignOutScope? scope}) async => _parent.signOut();
}
