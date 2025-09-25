import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/core/error/app_error.dart';
import 'package:instant_mentor_demo/core/utils/result.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test helper functions and utilities
class TestHelpers {
  /// Set up SharedPreferences for testing
  static void setupSharedPreferences() {
    SharedPreferences.setMockInitialValues({});
  }

  /// Create a mock user for testing
  static Map<String, dynamic> createMockUser({
    String? id,
    String? name,
    String? email,
    String? role,
    DateTime? createdAt,
  }) {
    return {
      'id': id ?? 'test_id_${DateTime.now().millisecondsSinceEpoch}',
      'name': name ?? 'Test User',
      'email': email ?? 'test@example.com',
      'role': role ?? 'student',
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'lastLoginAt': DateTime.now().toIso8601String(),
      'isActive': true,
    };
  }

  /// Create a mock token for testing
  static Map<String, dynamic> createMockToken({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return {
      'accessToken': accessToken ?? 'mock_access_token',
      'refreshToken': refreshToken ?? 'mock_refresh_token',
      'expiresAt': (expiresAt ?? DateTime.now().add(const Duration(hours: 1)))
          .toIso8601String(),
    };
  }

  /// Create a mock session for testing
  static Map<String, dynamic> createMockSession({
    Map<String, dynamic>? user,
    Map<String, dynamic>? token,
  }) {
    return {
      'user': user ?? createMockUser(),
      'token': token ?? createMockToken(),
    };
  }

  /// Wait for async operations with timeout
  static Future<T> waitForAsync<T>(Future<T> future,
      {Duration timeout = const Duration(seconds: 5)}) {
    return future.timeout(timeout);
  }

  /// Group test wrapper with common setup
  static void testGroup(String description, void Function() body) {
    group(description, () {
      setUp(() {
        setupSharedPreferences();
      });

      body();
    });
  }
}

/// Custom matchers for testing
class AppMatchers {
  /// Matcher for successful Result
  static Matcher isSuccess() => const TypeMatcher<Success>();

  /// Matcher for failed Result
  static Matcher isFailure() => const TypeMatcher<Failure>();

  /// Matcher for ValidationError
  static Matcher isValidationError() => const TypeMatcher<ValidationError>();

  /// Matcher for AuthError
  static Matcher isAuthError() => const TypeMatcher<AuthError>();

  /// Matcher for NetworkError
  static Matcher isNetworkError() => const TypeMatcher<NetworkError>();
}

/// Test data generators
class TestData {
  /// Valid student login credentials
  static const validStudentCredentials = {
    'email': 'student@student.com',
    'password': 'password123',
  };

  /// Valid mentor login credentials
  static const validMentorCredentials = {
    'email': 'mentor@mentor.com',
    'password': 'password123',
  };

  /// Valid student registration data
  static const validStudentRegistration = {
    'name': 'John Student',
    'email': 'john@student.com',
    'password': 'password123',
    'role': 'student',
  };

  /// Valid mentor registration data
  static const validMentorRegistration = {
    'name': 'Jane Mentor',
    'email': 'jane@mentor.com',
    'password': 'password123',
    'role': 'mentor',
  };

  /// Invalid credentials for testing error cases
  static const invalidCredentials = [
    {
      'description': 'empty email',
      'email': '',
      'password': 'password123',
    },
    {
      'description': 'empty password',
      'email': 'student@student.com',
      'password': '',
    },
    {
      'description': 'invalid email domain',
      'email': 'student@gmail.com',
      'password': 'password123',
    },
    {
      'description': 'short password',
      'email': 'student@student.com',
      'password': '12',
    },
  ];

  /// Invalid registration data for testing error cases
  static const invalidRegistrationData = [
    {
      'description': 'empty name',
      'name': '',
      'email': 'student@student.com',
      'password': 'password123',
      'role': 'student',
    },
    {
      'description': 'empty email',
      'name': 'Test User',
      'email': '',
      'password': 'password123',
      'role': 'student',
    },
    {
      'description': 'weak password',
      'name': 'Test User',
      'email': 'student@student.com',
      'password': 'weak',
      'role': 'student',
    },
    {
      'description': 'wrong domain for student',
      'name': 'Test User',
      'email': 'student@mentor.com',
      'password': 'password123',
      'role': 'student',
    },
    {
      'description': 'wrong domain for mentor',
      'name': 'Test User',
      'email': 'mentor@student.com',
      'password': 'password123',
      'role': 'mentor',
    },
  ];
}

/// Extensions for easier testing
extension ResultTestExtension<T> on Result<T> {
  /// Assert that result is successful and return data
  T expectSuccess() {
    expect(isSuccess, isTrue,
        reason: 'Expected success but got failure: ${error?.message}');
    return data!;
  }

  /// Assert that result is failure and return error
  AppError expectFailure() {
    expect(isFailure, isTrue,
        reason: 'Expected failure but got success: $data');
    return error!;
  }
}
