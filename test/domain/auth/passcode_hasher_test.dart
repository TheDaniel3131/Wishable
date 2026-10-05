// Feature: auth, Property 1: Passcode verifier round-trip
//
// Property-based test for auth task 3.1.
//
// Property 1: For any valid passcode, verifying the SAME passcode against the
// credentials produced by `enroll` succeeds, and verifying a DIFFERENT
// passcode fails.
// Validates: Requirements 1.5 (store only a non-reversible verifier), 2.4
// (constant-time verify).
//
// The hasher is pure Dart (PBKDF2-HMAC-SHA256 over `package:crypto`), so this
// runs entirely in memory. A low iteration count is injected to keep the
// property run fast; correctness of the round-trip does not depend on the
// cost factor.

import 'package:glados/glados.dart';
import 'package:wishable/domain/auth/auth_credentials.dart';
import 'package:wishable/domain/auth/passcode_hasher.dart';
import 'package:wishable/domain/auth/passcode_policy.dart';

const PasscodeHasher _fastHasher = PasscodeHasher(
  // Deliberately low cost so the property suite stays fast; the algorithm is
  // identical to production.
  kdf: KdfParams(iterations: 50),
);

void main() {
  // Round-trip: enroll(p) then verify(p) is always true.
  Glados<String>(any.nonEmptyLetters).test(
    'verify succeeds for the enrolled passcode',
    (String raw) {
      // Normalize into a policy-valid password (>= 6 chars) so enrollment is
      // meaningful; the hasher itself accepts any non-empty string.
      final String passcode = raw.length >= kMinPasswordLength
          ? raw
          : raw.padRight(kMinPasswordLength, 'x');
      final AuthCredentials creds =
          _fastHasher.enroll(passcode, PasscodeKind.password);
      expect(_fastHasher.verify(passcode, creds), isTrue);
    },
  );

  // Round-trip negative: a different passcode never verifies.
  Glados2<String, String>(any.nonEmptyLetters, any.nonEmptyLetters).test(
    'verify fails for a different passcode',
    (String a, String b) {
      final String p = a.padRight(kMinPasswordLength, 'x');
      final String q = b.padRight(kMinPasswordLength, 'y');
      if (p == q) {
        return; // Skip the degenerate equal case; covered by the positive test.
      }
      final AuthCredentials creds =
          _fastHasher.enroll(p, PasscodeKind.password);
      expect(_fastHasher.verify(q, creds), isFalse);
    },
  );

  test('verifier is not the passcode and salt is random per enrollment', () {
    final AuthCredentials a =
        _fastHasher.enroll('secret123', PasscodeKind.password);
    final AuthCredentials b =
        _fastHasher.enroll('secret123', PasscodeKind.password);
    // Same passcode, different salts -> different verifiers (R1.5).
    expect(a.salt, isNot(equals(b.salt)));
    expect(a.verifier, isNot(equals(b.verifier)));
    // The stored verifier bytes are not a trivial encoding of the passcode.
    expect(String.fromCharCodes(a.verifier), isNot(contains('secret123')));
  });

  test('constantTimeEquals matches only identical byte sequences', () {
    expect(
      PasscodeHasher.constantTimeEquals(<int>[1, 2, 3], <int>[1, 2, 3]),
      isTrue,
    );
    expect(
      PasscodeHasher.constantTimeEquals(<int>[1, 2, 3], <int>[1, 2, 4]),
      isFalse,
    );
    expect(
      PasscodeHasher.constantTimeEquals(<int>[1, 2], <int>[1, 2, 3]),
      isFalse,
    );
  });
}
