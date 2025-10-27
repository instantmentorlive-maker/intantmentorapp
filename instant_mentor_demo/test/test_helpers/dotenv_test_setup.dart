import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:instant_mentor_demo/core/providers/auth_provider.dart';
import 'package:instant_mentor_demo/core/services/session_management_service.dart';

/// Ensure dotenv is loaded in unit tests and provide minimal defaults
Future<void> ensureTestDotenvLoaded() async {
  try {
    // Prefer loading repo .env when present
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Fallback: attempt a generic load (some versions of dotenv support this)
    try {
      await dotenv.load();
    } catch (_) {}
  }

  // Provide minimal values so code that reads these keys doesn't throw
  dotenv.env['SUPABASE_URL'] = dotenv.env['SUPABASE_URL'] ?? 'http://localhost';
  dotenv.env['SUPABASE_ANON_KEY'] =
      dotenv.env['SUPABASE_ANON_KEY'] ?? 'test_anon_key';
}

/// A tiny fake AuthNotifier that extends StateNotifier so it works with
/// Riverpod's StateNotifierProvider in tests. We implement only the methods
/// used by most widget tests; it's safe to extend later if tests need more.
class FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  FakeAuthNotifier(super.state);

  @override
  Future<void> signIn(
      {required String email, required String password}) async {}

  @override
  void clearError() {
    state = state.copyWith();
  }

  @override
  Future<void> signUp(
      {required String email,
      required String password,
      required String fullName,
      Map<String, dynamic>? additionalData}) async {}

  @override
  Future<void> signOut({bool forced = false}) async {}

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<void> setNewPassword(String newPassword) async {}

  @override
  Future<void> sendEmailOTP(String email,
      {bool shouldCreateUser = true}) async {}

  @override
  Future<void> verifyEmailOTP(
      {required String email, required String otp}) async {}

  @override
  Future<void> resendEmailOTP(String email) async {}

  @override
  Future<void> sendPhoneOTP(String phoneNumber) async {}

  @override
  Future<void> verifyPhoneOTP(
      {required String phone, required String otp}) async {}

  @override
  Future<void> resendPhoneOTP(String phoneNumber) async {}

  @override
  Future<void> updateProfile(Map<String, dynamic> profileData) async {}

  @override
  void clearNewMentorSignupFlag() {}

  @override
  void clearNewStudentSignupFlag() {}

  @override
  Future<List<ActiveSession>> getActiveSessions() async => [];

  @override
  Future<void> revokeSession(String sessionId) async {}

  @override
  Future<void> revokeAllOtherSessions() async {}

  @override
  Future<void> forceLogoutAllDevices() async {}
}

/// Returns a list of common provider overrides used by unit/widget tests.
List<Override> providerOverridesForUnitTests(FakeAuthNotifier fake) {
  return [
    authProvider.overrideWithProvider(
      StateNotifierProvider<AuthNotifier, AuthState>((ref) => fake),
    ),
  ];
}
