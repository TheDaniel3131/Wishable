// Unit tests for the passcode policy (auth task 3.3).
//
// Validates: Requirements 1.3 (confirmation must match), 1.4 (minimum
// strength: PIN >= 4 digits, password >= 6 chars). The policy is pure and
// never mutates state, so an invalid passcode simply returns PasscodeInvalid.

import 'package:flutter_test/flutter_test.dart';
import 'package:wishable/domain/auth/passcode_policy.dart';

void main() {
  group('PIN policy', () {
    test('accepts a 4+ digit numeric PIN', () {
      expect(
        PasscodePolicy.validate('1234', PasscodeKind.pin),
        isA<PasscodeValid>(),
      );
      expect(
        PasscodePolicy.validate('012345', PasscodeKind.pin),
        isA<PasscodeValid>(),
      );
    });

    test('rejects a PIN shorter than the minimum', () {
      expect(
        PasscodePolicy.validate('123', PasscodeKind.pin),
        isA<PasscodeInvalid>(),
      );
    });

    test('rejects a non-numeric PIN', () {
      expect(
        PasscodePolicy.validate('12a4', PasscodeKind.pin),
        isA<PasscodeInvalid>(),
      );
      expect(
        PasscodePolicy.validate('', PasscodeKind.pin),
        isA<PasscodeInvalid>(),
      );
    });
  });

  group('password policy', () {
    test('accepts a 6+ character password', () {
      expect(
        PasscodePolicy.validate('secret', PasscodeKind.password),
        isA<PasscodeValid>(),
      );
    });

    test('rejects a password shorter than the minimum', () {
      expect(
        PasscodePolicy.validate('short', PasscodeKind.password),
        isA<PasscodeInvalid>(),
      );
    });
  });

  group('confirmation', () {
    test('accepts matching confirmation', () {
      expect(
        PasscodePolicy.validate('123456', PasscodeKind.pin,
            confirmation: '123456'),
        isA<PasscodeValid>(),
      );
    });

    test('rejects mismatched confirmation without changing anything', () {
      final PasscodeValidation result = PasscodePolicy.validate(
        '123456',
        PasscodeKind.pin,
        confirmation: '654321',
      );
      expect(result, isA<PasscodeInvalid>());
      expect((result as PasscodeInvalid).message, contains('match'));
    });
  });
}
