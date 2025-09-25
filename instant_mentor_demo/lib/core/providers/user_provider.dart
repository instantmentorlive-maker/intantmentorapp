import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';

class UserNotifier extends StateNotifier<User?> {
  UserNotifier() : super(null);

  void switchRole() {
    if (state != null) {
      if (state!.role == UserRole.student) {
        state = state!.copyWith(role: UserRole.mentor);
      } else {
        state = state!.copyWith(role: UserRole.student);
      }
    }
  }

  void updateUser(User user) {
    state = user;
  }

  void logout() {
    state = null;
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required bool isStudent,
  }) async {
    // TODO: Implement actual signup logic with your backend
    await Future.delayed(const Duration(seconds: 1)); // Simulated API call

    state = User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      role: isStudent ? UserRole.student : UserRole.mentor,
      createdAt: DateTime.now(),
    );
  }
}

final userProvider = StateNotifierProvider<UserNotifier, User?>((ref) {
  return UserNotifier();
});

// Helper provider to check current role
final currentRoleProvider = Provider<UserRole?>((ref) {
  final user = ref.watch(userProvider);
  return user?.role;
});

// Helper provider to check if user is student
final isStudentProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == UserRole.student;
});

// Helper provider to check if user is mentor
final isMentorProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == UserRole.mentor;
});
