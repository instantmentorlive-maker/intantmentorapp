import 'package:flutter_test/flutter_test.dart';
import 'package:instant_mentor_demo/core/utils/form_validators.dart';

void main() {
  group('FormValidators.email', () {
    test('returns required message for empty when required', () {
      expect(FormValidators.email(''), isNotNull);
    });

    test('accepts valid email', () {
      expect(FormValidators.email('test@example.com'), isNull);
    });

    test('rejects invalid format', () {
      expect(FormValidators.email('not-an-email'), isNotNull);
    });

    test('allowedDomains restricts emails', () {
      expect(
          FormValidators.email('user@other.com',
              allowedDomains: ['@student.com']),
          isNotNull);
      expect(
          FormValidators.email('user@student.com',
              allowedDomains: ['@student.com']),
          isNull);
    });
  });

  group('PasswordStrengthChecker', () {
    test('weak password', () {
      final s = PasswordStrengthChecker.getStrength('abc');
      expect(s, PasswordStrength.weak);
    });

    test('strong password', () {
      final s = PasswordStrengthChecker.getStrength('Abcdef1!234');
      expect(s, anyOf(PasswordStrength.good, PasswordStrength.strong));
    });
  });

  group('FormValidators.name', () {
    test('rejects numbers by default', () {
      expect(FormValidators.name('John2'), isNotNull);
    });

    test('accepts valid name', () {
      expect(FormValidators.name("O'Connor"), isNull);
    });
  });
}
