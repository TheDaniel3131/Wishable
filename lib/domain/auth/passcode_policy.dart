/// Passcode validation policy (auth spec, Option A — R1.3, R1.4).
///
/// Pure domain logic: no Flutter, no Drift, no plugins. Enforces the kind-
/// specific minimum strength for a passcode and the confirm-match rule used at
/// enrollment and change time.
library wishable.domain.auth.passcode_policy;

/// Whether a passcode is a numeric PIN or an alphanumeric password. The kind
/// determines the minimum-length rule (R1.4).
enum PasscodeKind { pin, password }

/// Minimum PIN length (digits). (R1.4)
const int kMinPinLength = 4;

/// Minimum password length (characters). (R1.4)
const int kMinPasswordLength = 6;

/// The result of validating a passcode (and optional confirmation).
///
/// [PasscodeValid] carries the normalized passcode ready for hashing;
/// [PasscodeInvalid] carries a user-facing, secret-free [message] (R7.3).
sealed class PasscodeValidation {
  const PasscodeValidation();
}

/// The passcode satisfies the policy.
final class PasscodeValid extends PasscodeValidation {
  const PasscodeValid(this.passcode, this.kind);

  /// The accepted passcode (never logged or persisted in cleartext).
  final String passcode;

  /// The kind the passcode was validated as.
  final PasscodeKind kind;
}

/// The passcode (or confirmation) fails the policy.
final class PasscodeInvalid extends PasscodeValidation {
  const PasscodeInvalid(this.message);

  /// A user-facing, secret-free explanation.
  final String message;
}

/// Validates a passcode against the policy for its [kind], optionally checking
/// a [confirmation] re-entry (R1.3, R1.4).
///
/// Rules:
///   - A PIN must be all digits and at least [kMinPinLength] long.
///   - A password must be at least [kMinPasswordLength] characters.
///   - When [confirmation] is provided it must exactly match [passcode].
///
/// This never mutates state and never logs the passcode.
abstract final class PasscodePolicy {
  const PasscodePolicy._();

  /// Validates [passcode] (and [confirmation] if given) for [kind].
  static PasscodeValidation validate(
    String passcode,
    PasscodeKind kind, {
    String? confirmation,
  }) {
    switch (kind) {
      case PasscodeKind.pin:
        if (passcode.isEmpty || !_isAllDigits(passcode)) {
          return const PasscodeInvalid('A PIN must contain only digits.');
        }
        if (passcode.length < kMinPinLength) {
          return const PasscodeInvalid(
            'A PIN must be at least $kMinPinLength digits.',
          );
        }
      case PasscodeKind.password:
        if (passcode.length < kMinPasswordLength) {
          return const PasscodeInvalid(
            'A password must be at least $kMinPasswordLength characters.',
          );
        }
    }

    if (confirmation != null && confirmation != passcode) {
      return const PasscodeInvalid('The entries do not match.');
    }

    return PasscodeValid(passcode, kind);
  }

  static bool _isAllDigits(String s) {
    for (final int unit in s.codeUnits) {
      // '0'..'9' are 0x30..0x39.
      if (unit < 0x30 || unit > 0x39) {
        return false;
      }
    }
    return true;
  }
}
