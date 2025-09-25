import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/core/error/app_error.dart';
import 'package:instant_mentor_demo/core/utils/result.dart';

void main() {
  group('Result<T>', () {
    group('Success', () {
      test('should create success result with data', () {
        // Arrange
        const data = 'test data';

        // Act
        const result = Success(data);

        // Assert
        expect(result.data, equals(data));
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
      });

      test('should handle null data', () {
        // Act
        const result = Success<String?>(null);

        // Assert
        expect(result.data, isNull);
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
      });
    });

    group('Failure', () {
      test('should create failure result with error', () {
        // Arrange
        final error = AuthError.invalidCredentials();

        // Act
        final result = Failure<String>(error);

        // Assert
        expect(result.error, equals(error));
        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
      });
    });

    group('ResultExtension', () {
      test('map should transform success data', () {
        // Arrange
        const result = Success(42);

        // Act
        final mapped = result.map((data) => data.toString());

        // Assert
        expect(mapped.isSuccess, isTrue);
        expect(mapped.data, equals('42'));
      });

      test('map should preserve failure', () {
        // Arrange
        final error = ValidationError.required('test');
        final result = Failure<int>(error);

        // Act
        final mapped = result.map((data) => data.toString());

        // Assert
        expect(mapped.isFailure, isTrue);
        expect(mapped.error, equals(error));
      });

      test('mapAsync should transform success data asynchronously', () async {
        // Arrange
        const result = Success(42);

        // Act
        final mapped = await result.mapAsync((data) async => data.toString());

        // Assert
        expect(mapped.isSuccess, isTrue);
        expect(mapped.data, equals('42'));
      });

      test('mapAsync should preserve failure', () async {
        // Arrange
        final error = NetworkError.noConnection();
        final result = Failure<int>(error);

        // Act
        final mapped = await result.mapAsync((data) async => data.toString());

        // Assert
        expect(mapped.isFailure, isTrue);
        expect(mapped.error, equals(error));
      });

      test('onSuccess should execute callback for success result', () {
        // Arrange
        const result = Success('test');
        bool callbackExecuted = false;
        String? receivedData;

        // Act
        result.onSuccess((data) {
          callbackExecuted = true;
          receivedData = data;
        });

        // Assert
        expect(callbackExecuted, isTrue);
        expect(receivedData, equals('test'));
      });

      test('onSuccess should not execute callback for failure result', () {
        // Arrange
        final error = ValidationError.tooShort('password', 8);
        final result = Failure<String>(error);
        bool callbackExecuted = false;

        // Act
        result.onSuccess((data) => callbackExecuted = true);

        // Assert
        expect(callbackExecuted, isFalse);
      });

      test('onError should execute callback for failure result', () {
        // Arrange
        final error = AuthError.accountNotFound();
        final result = Failure<String>(error);
        bool callbackExecuted = false;
        AppError? receivedError;

        // Act
        result.onError((err) {
          callbackExecuted = true;
          receivedError = err;
        });

        // Assert
        expect(callbackExecuted, isTrue);
        expect(receivedError, equals(error));
      });

      test('onError should not execute callback for success result', () {
        // Arrange
        const result = Success('test data');
        bool callbackExecuted = false;

        // Act
        result.onError((error) => callbackExecuted = true);

        // Assert
        expect(callbackExecuted, isFalse);
      });

      test('data getter should return data for success', () {
        // Arrange
        const result = Success('test data');

        // Act
        final data = result.data;

        // Assert
        expect(data, equals('test data'));
      });

      test('data getter should return null for failure', () {
        // Arrange
        final result = Failure<String>(AuthError.sessionExpired());

        // Act
        final data = result.data;

        // Assert
        expect(data, isNull);
      });

      test('error getter should return error for failure', () {
        // Arrange
        final error = NetworkError.timeout();
        final result = Failure<String>(error);

        // Act
        final resultError = result.error;

        // Assert
        expect(resultError, equals(error));
      });

      test('error getter should return null for success', () {
        // Arrange
        const result = Success('test data');

        // Act
        final error = result.error;

        // Assert
        expect(error, isNull);
      });
    });
  });

  group('ResultUtils', () {
    test('success should create Success result', () {
      // Act
      final result = ResultUtils.success('test');

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.data, equals('test'));
    });

    test('failure should create Failure result', () {
      // Arrange
      final error = ValidationError.required('field');

      // Act
      final result = ResultUtils.failure<String>(error);

      // Assert
      expect(result.isFailure, isTrue);
      expect(result.error, equals(error));
    });

    test('tryCall should return Success for successful operation', () {
      // Act
      final result = ResultUtils.tryCall(() => 'success');

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.data, equals('success'));
    });

    test('tryCall should return Failure for throwing operation', () {
      // Act
      final result =
          ResultUtils.tryCall<String>(() => throw Exception('test error'));

      // Assert
      expect(result.isFailure, isTrue);
      expect(result.error, isNotNull);
    });

    test('tryCallAsync should return Success for successful async operation',
        () async {
      // Act
      final result =
          await ResultUtils.tryCallAsync(() async => 'async success');

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.data, equals('async success'));
    });

    test('tryCallAsync should return Failure for throwing async operation',
        () async {
      // Act
      final result = await ResultUtils.tryCallAsync<String>(
          () async => throw Exception('async error'));

      // Assert
      expect(result.isFailure, isTrue);
      expect(result.error, isNotNull);
    });
  });
}
