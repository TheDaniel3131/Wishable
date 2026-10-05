/// Passcode verifier derivation + constant-time comparison (auth spec,
/// Option A — R1.5, R2.4, R7).
///
/// Pure Dart: uses `package:crypto` (a pure-Dart package, not a plugin) to
/// implement PBKDF2-HMAC-SHA256. No Flutter, no Drift, no platform plugins, so
/// this lives in the domain layer and is fully unit/property-testable.
///
/// The hasher NEVER stores or returns the passcode. [enroll] turns a passcode
/// into [AuthCredentials] (salt + non-reversible verifier); [verify] re-derives
/// the verifier from a candidate passcode and compares it to the stored one in
/// constant time (R2.4). A deterministic salt source is injectable for tests.
library wishable.domain.auth.passcode_hasher;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'auth_credentials.dart';
import 'passcode_policy.dart';

/// Produces random salt bytes. Abstracted so tests can inject a deterministic
/// source; production uses [SecureRandomSaltSource].
abstract interface class SaltSource {
  Uint8List nextSalt(int length);
}

/// Cryptographically secure salt source backed by [Random.secure].
final class SecureRandomSaltSource implements SaltSource {
  SecureRandomSaltSource([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  @override
  Uint8List nextSalt(int length) {
    final Uint8List bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
}

/// Derives and verifies passcode verifiers with PBKDF2-HMAC-SHA256.
final class PasscodeHasher {
  const PasscodeHasher({
    this.saltSource = const _DefaultSaltSource(),
    this.saltLength = 16,
    this.kdf = const KdfParams(),
  });

  /// Source of per-enrollment salt bytes.
  final SaltSource saltSource;

  /// Salt length in bytes.
  final int saltLength;

  /// KDF parameters applied when deriving a verifier.
  final KdfParams kdf;

  /// Enrolls [passcode] of [kind] into fresh [AuthCredentials]: generates a
  /// random salt and derives the verifier. The passcode is not retained
  /// (R1.5, R7.1).
  AuthCredentials enroll(
    String passcode,
    PasscodeKind kind, {
    bool biometricEnabled = false,
    Duration lockTimeout = Duration.zero,
  }) {
    final Uint8List salt = saltSource.nextSalt(saltLength);
    final Uint8List verifier = _derive(passcode, salt, kdf);
    return AuthCredentials(
      verifier: verifier,
      salt: salt,
      kdf: kdf,
      kind: kind,
      biometricEnabled: biometricEnabled,
      lockTimeout: lockTimeout,
    );
  }

  /// Returns true iff [passcode] re-derives to the stored verifier in [creds].
  /// Uses a constant-time comparison so verification time does not leak how
  /// many leading bytes matched (R2.4).
  bool verify(String passcode, AuthCredentials creds) {
    final Uint8List candidate = _derive(passcode, creds.salt, creds.kdf);
    return constantTimeEquals(candidate, creds.verifier);
  }

  /// PBKDF2-HMAC-SHA256 derivation of [passcode] over [salt].
  static Uint8List _derive(String passcode, Uint8List salt, KdfParams kdf) {
    final List<int> password = utf8.encode(passcode);
    final Hmac hmac = Hmac(sha256, password);
    const int hLen = 32; // SHA-256 output length.
    final int blocks = (kdf.keyLength + hLen - 1) ~/ hLen;
    final Uint8List output = Uint8List(blocks * hLen);

    for (int block = 1; block <= blocks; block++) {
      // U1 = HMAC(password, salt || INT_32_BE(block)).
      final Uint8List saltBlock = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt);
      saltBlock[salt.length] = (block >> 24) & 0xff;
      saltBlock[salt.length + 1] = (block >> 16) & 0xff;
      saltBlock[salt.length + 2] = (block >> 8) & 0xff;
      saltBlock[salt.length + 3] = block & 0xff;

      List<int> u = hmac.convert(saltBlock).bytes;
      final Uint8List t = Uint8List.fromList(u);
      for (int iter = 1; iter < kdf.iterations; iter++) {
        u = hmac.convert(u).bytes;
        for (int i = 0; i < hLen; i++) {
          t[i] ^= u[i];
        }
      }
      output.setRange((block - 1) * hLen, block * hLen, t);
    }
    return Uint8List.sublistView(output, 0, kdf.keyLength);
  }

  /// Constant-time byte comparison. Runs over the full length of [a] regardless
  /// of where a mismatch occurs, so timing does not reveal the match prefix
  /// (R2.4). Lengths differing is folded into the result without early return.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    final int len = a.length;
    int diff = a.length ^ b.length;
    for (int i = 0; i < len; i++) {
      // Guard the index into b without branching on content.
      final int bi = i < b.length ? b[i] : 0;
      diff |= a[i] ^ bi;
    }
    return diff == 0;
  }
}

/// Default salt source used by the const [PasscodeHasher] constructor.
final class _DefaultSaltSource implements SaltSource {
  const _DefaultSaltSource();

  @override
  Uint8List nextSalt(int length) => SecureRandomSaltSource().nextSalt(length);
}
