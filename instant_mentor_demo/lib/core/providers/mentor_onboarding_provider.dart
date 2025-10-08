import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/models/auth_state.dart';
import '../services/supabase_service.dart';

/// Provider to check if mentor onboarding is completed
final mentorOnboardingStatusProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authProvider);

  // Only check for authenticated mentors
  if (!authState.isAuthenticated ||
      authState.user?.userMetadata?['role'] != 'mentor') {
    return true; // Not a mentor, so onboarding not required
  }

  try {
    final isCompleted =
        await SupabaseService.instance.isMentorOnboardingCompleted();
    return isCompleted;
  } catch (e) {
    // If there's an error checking, assume not completed for safety
    return false;
  }
});

/// Provider that returns true if the user needs to complete mentor onboarding
final needsMentorOnboardingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  final onboardingStatusAsync = ref.watch(mentorOnboardingStatusProvider);

  // Not a mentor, no onboarding needed
  if (!authState.isAuthenticated ||
      authState.user?.userMetadata?['role'] != 'mentor') {
    return false;
  }

  // Still loading onboarding status
  if (onboardingStatusAsync.isLoading) {
    return false; // Don't redirect while loading
  }

  // Has error or onboarding not completed
  return onboardingStatusAsync.value == false;
});
