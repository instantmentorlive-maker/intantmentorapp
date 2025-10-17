import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/core/utils/result.dart';
import 'package:instant_mentor_demo/core/error/app_error.dart';

void main() {
  group('Result utilities', () {
    test('Success stores data and maps correctly', () {
      final r = ResultUtils.success<int>(42);
      expect(r.isSuccess, isTrue);
      expect(r.data, 42);

      final mapped = r.map((v) => 'value:$v');
      expect(mapped.isSuccess, isTrue);
      expect(mapped.data, 'value:42');
    });

    test('Failure stores error and onError is called', () {
      // AppError is abstract; use a concrete AppError implementation for tests
      final err = AppGeneralError(message: 'boom');
      final r = ResultUtils.failure<int>(err);
      expect(r.isFailure, isTrue);
      expect(r.error, err);

      var seen = false;
      r.onError((e) => seen = e.message == 'boom');
      expect(seen, isTrue);
    });

    test('tryCall wraps exceptions into Failure', () {
      final r = ResultUtils.tryCall<int>(() => throw Exception('x'));
      expect(r.isFailure, isTrue);
      expect(r.error, isA<AppError>());
    });
  });
}
