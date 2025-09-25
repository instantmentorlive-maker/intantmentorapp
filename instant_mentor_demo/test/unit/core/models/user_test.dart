import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/core/models/user.dart';

void main() {
  group('UserRole', () {
    test('should have correct string representations', () {
      expect(UserRole.student.name, equals('student'));
      expect(UserRole.mentor.name, equals('mentor'));
    });

    test('isStudent should return true for student role', () {
      expect(UserRole.student.isStudent, isTrue);
      expect(UserRole.mentor.isStudent, isFalse);
    });

    test('isMentor should return true for mentor role', () {
      expect(UserRole.mentor.isMentor, isTrue);
      expect(UserRole.student.isMentor, isFalse);
    });

    test('should parse from string correctly', () {
      expect(UserRole.fromString('student'), equals(UserRole.student));
      expect(UserRole.fromString('STUDENT'), equals(UserRole.student));
      expect(UserRole.fromString('mentor'), equals(UserRole.mentor));
      expect(UserRole.fromString('MENTOR'), equals(UserRole.mentor));
    });

    test('should throw on invalid string', () {
      expect(
          () => UserRole.fromString('invalid'), throwsA(isA<ArgumentError>()));
    });
  });

  group('LoginCredentials', () {
    test('should create instance with email and password', () {
      // Arrange & Act
      const credentials = LoginCredentials(
        email: 'test@student.com',
        password: 'password123',
      );

      // Assert
      expect(credentials.email, equals('test@student.com'));
      expect(credentials.password, equals('password123'));
    });

    test('should serialize to JSON correctly', () {
      // Arrange
      const credentials = LoginCredentials(
        email: 'mentor@mentor.com',
        password: 'securepass',
      );

      // Act
      final json = credentials.toJson();

      // Assert
      expect(json['email'], equals('mentor@mentor.com'));
      expect(json['password'], equals('securepass'));
    });
  });

  group('RegisterData', () {
    test('should create instance with all required fields', () {
      // Arrange & Act
      const data = RegisterData(
        name: 'John Doe',
        email: 'john@student.com',
        password: 'password123',
        role: UserRole.student,
      );

      // Assert
      expect(data.name, equals('John Doe'));
      expect(data.email, equals('john@student.com'));
      expect(data.password, equals('password123'));
      expect(data.role, equals(UserRole.student));
    });

    test('should serialize to JSON correctly', () {
      // Arrange
      const data = RegisterData(
        name: 'Jane Smith',
        email: 'jane@mentor.com',
        password: 'mypassword',
        role: UserRole.mentor,
      );

      // Act
      final json = data.toJson();

      // Assert
      expect(json['name'], equals('Jane Smith'));
      expect(json['email'], equals('jane@mentor.com'));
      expect(json['password'], equals('mypassword'));
      expect(json['role'], equals('mentor'));
    });
  });

  group('AuthToken', () {
    test('should create instance with all fields', () {
      // Arrange
      final expiresAt = DateTime(2025, 12, 31);

      // Act
      final token = AuthToken(
        accessToken: 'access123',
        refreshToken: 'refresh456',
        expiresAt: expiresAt,
      );

      // Assert
      expect(token.accessToken, equals('access123'));
      expect(token.refreshToken, equals('refresh456'));
      expect(token.expiresAt, equals(expiresAt));
    });

    test('isExpired should return false for non-expired token', () {
      // Arrange
      final token = AuthToken(
        accessToken: 'access123',
        refreshToken: 'refresh456',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      // Act & Assert
      expect(token.isExpired, isFalse);
    });

    test('isExpired should return true for expired token', () {
      // Arrange
      final token = AuthToken(
        accessToken: 'access123',
        refreshToken: 'refresh456',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      // Act & Assert
      expect(token.isExpired, isTrue);
    });

    test('isNearExpiry should return false for token not near expiry', () {
      // Arrange
      final token = AuthToken(
        accessToken: 'access123',
        refreshToken: 'refresh456',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      // Act & Assert
      expect(token.isNearExpiry, isFalse);
    });

    test('isNearExpiry should return true for token near expiry', () {
      // Arrange
      final token = AuthToken(
        accessToken: 'access123',
        refreshToken: 'refresh456',
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      );

      // Act & Assert
      expect(token.isNearExpiry, isTrue);
    });

    test('should serialize to/from JSON correctly', () {
      // Arrange
      final expiresAt = DateTime(2025, 8, 14, 12, 30, 45);
      final token = AuthToken(
        accessToken: 'access_token_123',
        refreshToken: 'refresh_token_456',
        expiresAt: expiresAt,
      );

      // Act
      final json = token.toJson();
      final fromJson = AuthToken.fromJson(json);

      // Assert
      expect(json['accessToken'], equals('access_token_123'));
      expect(json['refreshToken'], equals('refresh_token_456'));
      expect(json['expiresAt'], equals(expiresAt.toIso8601String()));
      expect(fromJson.accessToken, equals(token.accessToken));
      expect(fromJson.refreshToken, equals(token.refreshToken));
      expect(fromJson.expiresAt, equals(token.expiresAt));
    });
  });

  group('User', () {
    test('should create instance with required fields', () {
      // Arrange
      final createdAt = DateTime(2025);
      final lastLoginAt = DateTime(2025, 8, 14);

      // Act
      final user = User(
        id: 'user123',
        name: 'Test User',
        email: 'test@student.com',
        role: UserRole.student,
        createdAt: createdAt,
        lastLoginAt: lastLoginAt,
      );

      // Assert
      expect(user.id, equals('user123'));
      expect(user.name, equals('Test User'));
      expect(user.email, equals('test@student.com'));
      expect(user.role, equals(UserRole.student));
      expect(user.createdAt, equals(createdAt));
      expect(user.lastLoginAt, equals(lastLoginAt));
    });

    test('should serialize to/from JSON correctly', () {
      // Arrange
      final createdAt = DateTime(2025, 1, 1, 10, 30);
      final lastLoginAt = DateTime(2025, 8, 14, 15, 45);
      final user = User(
        id: 'mentor456',
        name: 'Mentor User',
        email: 'mentor@mentor.com',
        role: UserRole.mentor,
        createdAt: createdAt,
        lastLoginAt: lastLoginAt,
      );

      // Act
      final json = user.toJson();
      final fromJson = User.fromJson(json);

      // Assert
      expect(json['id'], equals('mentor456'));
      expect(json['name'], equals('Mentor User'));
      expect(json['email'], equals('mentor@mentor.com'));
      expect(json['role'], equals('mentor'));
      expect(json['createdAt'], equals(createdAt.toIso8601String()));
      expect(json['lastLoginAt'], equals(lastLoginAt.toIso8601String()));
      expect(fromJson.id, equals(user.id));
      expect(fromJson.name, equals(user.name));
      expect(fromJson.email, equals(user.email));
      expect(fromJson.role, equals(user.role));
      expect(fromJson.createdAt, equals(user.createdAt));
      expect(fromJson.lastLoginAt, equals(user.lastLoginAt));
    });
  });

  group('Session', () {
    test('should create instance with user and token', () {
      // Arrange
      final user = User(
        id: 'user123',
        name: 'Test User',
        email: 'test@student.com',
        role: UserRole.student,
        createdAt: DateTime(2025),
        lastLoginAt: DateTime(2025, 8, 14),
      );
      final token = AuthToken(
        accessToken: 'access123',
        refreshToken: 'refresh456',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      // Act
      final session = Session(user: user, token: token);

      // Assert
      expect(session.user, equals(user));
      expect(session.token, equals(token));
    });

    test('isValid should return true when token is valid', () {
      // Arrange
      final user = User(
        id: 'user123',
        name: 'Test User',
        email: 'test@student.com',
        role: UserRole.student,
        createdAt: DateTime(2025),
        lastLoginAt: DateTime(2025, 8, 14),
      );
      final token = AuthToken(
        accessToken: 'access123',
        refreshToken: 'refresh456',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final session = Session(user: user, token: token);

      // Act & Assert
      expect(session.isValid, isTrue);
    });

    test('isValid should return false when token is expired', () {
      // Arrange
      final user = User(
        id: 'user123',
        name: 'Test User',
        email: 'test@student.com',
        role: UserRole.student,
        createdAt: DateTime(2025),
        lastLoginAt: DateTime(2025, 8, 14),
      );
      final token = AuthToken(
        accessToken: 'access123',
        refreshToken: 'refresh456',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final session = Session(user: user, token: token);

      // Act & Assert
      expect(session.isValid, isFalse);
    });

    test('should serialize to/from JSON correctly', () {
      // Arrange
      final createdAt = DateTime(2025);
      final lastLoginAt = DateTime(2025, 8, 14);
      final expiresAt = DateTime(2025, 12, 31);

      final user = User(
        id: 'user789',
        name: 'Session User',
        email: 'session@student.com',
        role: UserRole.student,
        createdAt: createdAt,
        lastLoginAt: lastLoginAt,
      );
      final token = AuthToken(
        accessToken: 'session_access',
        refreshToken: 'session_refresh',
        expiresAt: expiresAt,
      );
      final session = Session(user: user, token: token);

      // Act
      final json = session.toJson();
      final fromJson = Session.fromJson(json);

      // Assert
      expect(json.containsKey('user'), isTrue);
      expect(json.containsKey('token'), isTrue);
      expect(fromJson.user.id, equals(session.user.id));
      expect(fromJson.user.name, equals(session.user.name));
      expect(fromJson.user.email, equals(session.user.email));
      expect(fromJson.token.accessToken, equals(session.token.accessToken));
      expect(fromJson.token.refreshToken, equals(session.token.refreshToken));
      expect(fromJson.token.expiresAt, equals(session.token.expiresAt));
    });
  });
}
