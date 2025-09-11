import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/core/models/user.dart';
import 'package:instant_mentor_demo/core/utils/result.dart';
import 'package:instant_mentor_demo/core/error/app_error.dart';
import 'package:instant_mentor_demo/data/repositories/mock_auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  group('MockAuthRepository', () {
    late MockAuthRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = MockAuthRepository();
    });

    group('signIn', () {
      test('should return success for valid student credentials', () async {
        // Arrange
        const credentials = LoginCredentials(
          email: 'student@student.com',
          password: 'password123',
        );

        // Act
        final result = await repository.signIn(credentials);

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.data!.user.email, equals('student@student.com'));
        expect(result.data!.user.role, equals(UserRole.student));
        expect(result.data!.token.accessToken, isNotEmpty);
      });

      test('should return success for valid mentor credentials', () async {
        // Arrange
        const credentials = LoginCredentials(
          email: 'mentor@mentor.com',
          password: 'password123',
        );

        // Act
        final result = await repository.signIn(credentials);

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.data!.user.email, equals('mentor@mentor.com'));
        expect(result.data!.user.role, equals(UserRole.mentor));
        expect(result.data!.token.accessToken, isNotEmpty);
      });

      test('should return failure for invalid email format', () async {
        // Arrange
        const credentials = LoginCredentials(
          email: 'invalid@gmail.com',
          password: 'password123',
        );

        // Act
        final result = await repository.signIn(credentials);

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.error, isA<ValidationError>());
      });

      test('should return failure for empty password', () async {
        // Arrange
        const credentials = LoginCredentials(
          email: 'student@student.com',
          password: '',
        );

        // Act
        final result = await repository.signIn(credentials);

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.error, isA<ValidationError>());
      });

      test('should return failure for short password', () async {
        // Arrange
        const credentials = LoginCredentials(
          email: 'student@student.com',
          password: '12',
        );

        // Act
        final result = await repository.signIn(credentials);

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.error, isA<AuthError>());
      });

      test('should return failure for non-existent account', () async {
        // Arrange
        const credentials = LoginCredentials(
          email: 'notfound@student.com',
          password: 'password123',
        );

        // Act
        final result = await repository.signIn(credentials);

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.error, isA<AuthError>());
      });
    });

    group('signUp', () {
      test('should return success for valid student registration', () async {
        // Arrange
        const data = RegisterData(
          name: 'John Student',
          email: 'john@student.com',
          password: 'password123',
          role: UserRole.student,
        );

        // Act
        final result = await repository.signUp(data);

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.data!.user.name, equals('John Student'));
        expect(result.data!.user.email, equals('john@student.com'));
        expect(result.data!.user.role, equals(UserRole.student));
      });

      test('should return success for valid mentor registration', () async {
        // Arrange
        const data = RegisterData(
          name: 'Jane Mentor',
          email: 'jane@mentor.com',
          password: 'securepass',
          role: UserRole.mentor,
        );

        // Act
        final result = await repository.signUp(data);

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.data!.user.name, equals('Jane Mentor'));
        expect(result.data!.user.email, equals('jane@mentor.com'));
        expect(result.data!.user.role, equals(UserRole.mentor));
      });

      test('should return failure for empty name', () async {
        // Arrange
        const data = RegisterData(
          name: '',
          email: 'student@student.com',
          password: 'password123',
          role: UserRole.student,
        );

        // Act
        final result = await repository.signUp(data);

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.error, isA<ValidationError>());
      });

      test('should return failure for empty email', () async {
        // Arrange
        const data = RegisterData(
          name: 'Test User',
          email: '',
          password: 'password123',
          role: UserRole.student,
        );

        // Act
        final result = await repository.signUp(data);

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.error, isA<ValidationError>());
      });

      test('should return failure for empty password', () async {
        // Arrange
        const data = RegisterData(
          name: 'Test User',
          email: 'test@student.com',
          password: '',
          role: UserRole.student,
        );

        // Act
        final result = await repository.signUp(data);

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.error, isA<ValidationError>());
      });

      test('should return failure for weak password', () async {
        // Arrange
        const data = RegisterData(
          name: 'Test User',
          email: 'test@student.com',
          password: 'weak',
          role: UserRole.student,
        );

        // Act
        final result = await repository.signUp(data);

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.error, isA<AuthError>());
      });

      test('should return failure for wrong email domain for student', () async {
        // Arrange
        const data = RegisterData(
          name: 'Test User',
          email: 'test@mentor.com',
          password: 'password123',
          role: UserRole.student,
        );

        // Act
        final result = await repository.signUp(data);

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.error, isA<ValidationError>());
      });

      test('should return failure for wrong email domain for mentor', () async {
        // Arrange
        const data = RegisterData(
          name: 'Test User',
          email: 'test@student.com',
          password: 'password123',
          role: UserRole.mentor,
        );

        // Act
        final result = await repository.signUp(data);

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.error, isA<ValidationError>());
      });

      test('should return failure for existing email', () async {
        // Arrange
        const data = RegisterData(
          name: 'Test User',
          email: 'test@student.com',
          password: 'password123',
          role: UserRole.student,
        );

        // Act
        final result = await repository.signUp(data);

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.error, isA<AuthError>());
      });
    });

    group('signOut', () {
      test('should return success and clear session', () async {
        // Arrange - Sign in first to create a session
        const credentials = LoginCredentials(
          email: 'student@student.com',
          password: 'password123',
        );
        await repository.signIn(credentials);

        // Verify session exists
        final sessionBefore = await repository.getCurrentSession();
        expect(sessionBefore, isNotNull);

        // Act
        final result = await repository.signOut();

        // Assert
        expect(result.isSuccess, isTrue);
        
        // Verify session is cleared
        final sessionAfter = await repository.getCurrentSession();
        expect(sessionAfter, isNull);
      });
    });

    group('refreshToken', () {
      test('should return success with new token for valid refresh token', () async {
        // Act
        final result = await repository.refreshToken('refresh_123456');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.data!.accessToken, startsWith('access_'));
        expect(result.data!.refreshToken, startsWith('refresh_'));
      });

      test('should return failure for empty refresh token', () async {
        // Act
        final result = await repository.refreshToken('');

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.error, isA<AuthError>());
      });

      test('should return failure for invalid refresh token', () async {
        // Act
        final result = await repository.refreshToken('invalid_token');

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.error, isA<AuthError>());
      });
    });

    group('getCurrentSession', () {
      test('should return null when no session exists', () async {
        // Act
        final result = await repository.getCurrentSession();

        // Assert
        expect(result, isNull);
      });

      test('should return session after successful login', () async {
        // Arrange
        const credentials = LoginCredentials(
          email: 'mentor@mentor.com',
          password: 'password123',
        );
        
        // Sign in first
        await repository.signIn(credentials);

        // Act
        final result = await repository.getCurrentSession();

        // Assert
        expect(result, isNotNull);
        expect(result!.user.email, equals('mentor@mentor.com'));
        expect(result.user.role, equals(UserRole.mentor));
      });

      test('should return null for expired session', () async {
        // Arrange - Create a session with expired token
        const credentials = LoginCredentials(
          email: 'student@student.com',
          password: 'password123',
        );
        await repository.signIn(credentials);

        // Manually set an expired session in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final expiredToken = AuthToken(
          accessToken: 'expired_access',
          refreshToken: 'expired_refresh',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        final user = User(
          id: 'test_id',
          name: 'Test User',
          email: 'test@student.com',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );
        final expiredSession = Session(user: user, token: expiredToken);
        // Use proper JSON encoding instead of string concatenation
        final sessionJson = expiredSession.toJson();
        await prefs.setString('user_session', jsonEncode(sessionJson));

        // Act
        final result = await repository.getCurrentSession();

        // Assert
        expect(result, isNull);
      });
    });

    group('isAuthenticated', () {
      test('should return false when no session exists', () async {
        // Act
        final result = await repository.isAuthenticated();

        // Assert
        expect(result, isFalse);
      });

      test('should return true when valid session exists', () async {
        // Arrange
        const credentials = LoginCredentials(
          email: 'student@student.com',
          password: 'password123',
        );
        await repository.signIn(credentials);

        // Act
        final result = await repository.isAuthenticated();

        // Assert
        expect(result, isTrue);
      });

      test('should return false after sign out', () async {
        // Arrange
        const credentials = LoginCredentials(
          email: 'student@student.com',
          password: 'password123',
        );
        await repository.signIn(credentials);
        await repository.signOut();

        // Act
        final result = await repository.isAuthenticated();

        // Assert
        expect(result, isFalse);
      });
    });

    group('clearAuthData', () {
      test('should clear all authentication data', () async {
        // Arrange
        const credentials = LoginCredentials(
          email: 'student@student.com',
          password: 'password123',
        );
        await repository.signIn(credentials);

        // Verify session exists
        expect(await repository.isAuthenticated(), isTrue);

        // Act
        await repository.clearAuthData();

        // Assert
        expect(await repository.isAuthenticated(), isFalse);
        final session = await repository.getCurrentSession();
        expect(session, isNull);
      });
    });
  });
}
