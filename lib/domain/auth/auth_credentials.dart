/// Stored app-lock credentials (auth spec, Option A — R1.5, R7.1).
///
/// Pure domain value type. Carries only a NON-REVERSIBLE verifier plus the
/// parameters needed to re-derive and compare it — never the passcode itself.
/// The data layer persists this in the platform secure store; nothing here is
/// a secret that could reconstruct the passcode.
library wishable.domain.auth.auth_credentials;

import 'dart:typed_data';

import 'passcode_policy.dart';

/// Default PBKDF2 iteration count for the local app-lock passcode verifier.
///
/// Tuned for a responsive on-device gate: fast enough that enroll/unlock does
/// not visibly freeze the UI (notably on web, where pure-Dart PBKDF2 is
/// single-threaded and markedly slower), while still slowing bulk guessing.
const int kDefaultKdfIterations = 25000;

/// Key-derivation parameters recorded alongside the verifier so a future
/// cost/algorithm change can re-derive old credentials correctly.
class KdfParams {
  const KdfParams({
    this.algorithm = 'pbkdf2-hmac-sha256',
    this.iterations = kDefaultKdfIterations,
    this.keyLength = 32,
  });

  /// Identifier of the KDF used to produce the verifier.
  final String algorithm;

  /// Iteration/cost count.
  ///
  /// This protects a LOCAL on-device app-lock passcode, whose threat model is
  /// "someone picked up the unlocked device" — not an attacker brute-forcing a
  /// stolen server password database. A deliberately slow server-grade cost
  /// (100k+) is unnecessary here and froze the UI on web (pure-Dart PBKDF2 runs
  /// single-threaded and is several times slower compiled to JS). The default
  /// is tuned to stay responsive while still slowing bulk guessing; the stored
  /// value travels with each credential so it can be raised later without
  /// breaking existing enrollments.
  final int iterations;

  /// Derived key length in bytes.
  final int keyLength;

  Map<String, Object?> toMap() => <String, Object?>{
        'algorithm': algorithm,
        'iterations': iterations,
        'keyLength': keyLength,
      };

  factory KdfParams.fromMap(Map<String, Object?> map) => KdfParams(
        algorithm: (map['algorithm'] as String?) ?? 'pbkdf2-hmac-sha256',
        iterations: (map['iterations'] as int?) ?? kDefaultKdfIterations,
        keyLength: (map['keyLength'] as int?) ?? 32,
      );

  @override
  bool operator ==(Object other) =>
      other is KdfParams &&
      other.algorithm == algorithm &&
      other.iterations == iterations &&
      other.keyLength == keyLength;

  @override
  int get hashCode => Object.hash(algorithm, iterations, keyLength);
}

/// The persisted app-lock credentials.
///
/// [verifier] is the KDF output of the passcode over [salt]; comparing a
/// re-derived verifier in constant time is how an unlock attempt is checked
/// (R2.4). [kind] records whether the passcode is a PIN or password so the
/// lock screen can show the right input. [biometricEnabled] and [lockTimeout]
/// are user preferences stored with the credentials.
class AuthCredentials {
  const AuthCredentials({
    required this.verifier,
    required this.salt,
    required this.kdf,
    required this.kind,
    this.biometricEnabled = false,
    this.lockTimeout = Duration.zero,
  });

  /// Non-reversible KDF output of the passcode (R1.5).
  final Uint8List verifier;

  /// Random per-enrollment salt mixed into the KDF.
  final Uint8List salt;

  /// Parameters used to derive [verifier].
  final KdfParams kdf;

  /// Whether the enrolled passcode is a PIN or a password.
  final PasscodeKind kind;

  /// Whether biometric unlock is enabled for this install (R3).
  final bool biometricEnabled;

  /// Idle time before the app auto-locks (R6). Zero means lock immediately on
  /// background.
  final Duration lockTimeout;

  AuthCredentials copyWith({
    Uint8List? verifier,
    Uint8List? salt,
    KdfParams? kdf,
    PasscodeKind? kind,
    bool? biometricEnabled,
    Duration? lockTimeout,
  }) {
    return AuthCredentials(
      verifier: verifier ?? this.verifier,
      salt: salt ?? this.salt,
      kdf: kdf ?? this.kdf,
      kind: kind ?? this.kind,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      lockTimeout: lockTimeout ?? this.lockTimeout,
    );
  }
}

/// The mutable failure state used by the lockout policy (R4). Stored separately
/// from the credentials so a wrong attempt never rewrites the verifier.
class AuthFailureState {
  const AuthFailureState({this.consecutiveFailures = 0, this.lastFailureUtc});

  /// Count of consecutive failed unlocks since the last success.
  final int consecutiveFailures;

  /// Timestamp (UTC) of the most recent failure, or null if none.
  final DateTime? lastFailureUtc;

  static const AuthFailureState none = AuthFailureState();

  AuthFailureState recordFailure(DateTime nowUtc) => AuthFailureState(
        consecutiveFailures: consecutiveFailures + 1,
        lastFailureUtc: nowUtc,
      );

  @override
  bool operator ==(Object other) =>
      other is AuthFailureState &&
      other.consecutiveFailures == consecutiveFailures &&
      other.lastFailureUtc == lastFailureUtc;

  @override
  int get hashCode => Object.hash(consecutiveFailures, lastFailureUtc);
}
