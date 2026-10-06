/// [AuthController] — the app-lock view-model (auth spec, Option A).
///
/// A Riverpod [Notifier] exposing the current [AuthState]. It orchestrates the
/// pure domain collaborators (policy, hasher, lockout) over the Drift-free
/// [AuthStore] and [BiometricAuthenticator] interfaces, and performs NO network
/// I/O (R8.1). It never imports a plugin — only the interfaces from the data
/// barrel and the pure domain types.
///
/// State flow (R1, R2, R4, R6):
///   - On build it starts in a transient locked-ish state and asynchronously
///     reads the store: no credentials -> [AuthUnconfigured] (always usable,
///     R1.1); credentials present -> [AuthLocked] (locked on cold start, R6.2).
///   - [enroll] validates and stores a passcode, then unlocks (R1).
///   - [unlock] / [unlockBiometric] authenticate and unlock, applying the
///     lockout policy and backoff on failure (R2, R3, R4).
///   - [changePasscode] / [disable] require current authentication first (R5).
///   - [lock] re-locks (invoked by the auto-lock observer, R6).
library wishable.application.auth.auth_controller;

import 'package:riverpod/riverpod.dart';

import '../../data/auth/auth_store.dart';
import '../../data/auth/biometric_authenticator.dart';
import '../../domain/auth/auth.dart';
import 'auth_providers.dart';

/// The result of an enroll / unlock / change / disable attempt, surfaced to the
/// UI so it can show inline feedback without inspecting [AuthState] directly.
sealed class AuthOutcome {
  const AuthOutcome();
}

/// The operation succeeded.
final class AuthSuccess extends AuthOutcome {
  const AuthSuccess();
}

/// The passcode failed validation (policy or confirmation mismatch) — carries a
/// user-facing, secret-free message (R1.3, R1.4).
final class AuthInvalid extends AuthOutcome {
  const AuthInvalid(this.message);
  final String message;
}

/// Authentication failed (wrong passcode / biometric). Non-revealing (R2.3).
final class AuthRejected extends AuthOutcome {
  const AuthRejected(this.message);
  final String message;
}

/// The attempt was refused because a lockout cooldown is active (R4.2).
final class AuthLockedOut extends AuthOutcome {
  const AuthLockedOut(this.remaining);
  final Duration remaining;
}

/// Drives the app lock. See the library doc for the state flow.
final class AuthController extends Notifier<AuthState> {
  AuthStore get _store => ref.read(authStoreProvider);
  BiometricAuthenticator get _biometrics =>
      ref.read(biometricAuthenticatorProvider);
  PasscodeHasher get _hasher => ref.read(passcodeHasherProvider);
  LockoutPolicy get _lockout => ref.read(lockoutPolicyProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  AuthState build() {
    // Start optimistically unconfigured so a never-enrolled user is never
    // blocked while the async read runs; _initialize corrects to Locked if a
    // passcode exists. (A fresh, unconfigured store resolves to the same
    // state.)
    _initialize();
    return const AuthUnconfigured();
  }

  /// Reads the store to decide the initial state (R1.1, R6.2).
  Future<void> _initialize() async {
    final AuthCredentials? creds = await _store.readCredentials();
    if (creds == null) {
      state = const AuthUnconfigured();
      return;
    }
    final AuthFailureState failures = await _store.readFailureState();
    state = _lockedOrCoolingDown(failures);
  }

  /// Whether a passcode is currently enrolled (drives Settings UI).
  Future<bool> isEnrolled() async => (await _store.readCredentials()) != null;

  /// Reads the stored credentials' metadata (kind, biometricEnabled,
  /// lockTimeout) for the lock screen / settings, or null if unconfigured.
  Future<AuthCredentials?> currentCredentials() => _store.readCredentials();

  /// Enrolls a new passcode and unlocks on success (R1).
  Future<AuthOutcome> enroll(
    String passcode,
    PasscodeKind kind, {
    required String confirmation,
    bool biometricEnabled = false,
    Duration lockTimeout = Duration.zero,
  }) async {
    final PasscodeValidation v =
        PasscodePolicy.validate(passcode, kind, confirmation: confirmation);
    if (v is PasscodeInvalid) {
      return AuthInvalid(v.message);
    }
    final AuthCredentials creds = _hasher.enroll(
      passcode,
      kind,
      biometricEnabled: biometricEnabled,
      lockTimeout: lockTimeout,
    );
    await _store.writeCredentials(creds);
    await _store.writeFailureState(AuthFailureState.none);
    state = const AuthUnlocked();
    return const AuthSuccess();
  }

  /// Attempts to unlock with [passcode], applying the lockout policy (R2, R4).
  Future<AuthOutcome> unlock(String passcode) async {
    final AuthCredentials? creds = await _store.readCredentials();
    if (creds == null) {
      // Nothing to unlock against; treat as unconfigured.
      state = const AuthUnconfigured();
      return const AuthSuccess();
    }

    final AuthFailureState failures = await _store.readFailureState();
    final LockoutDecision decision = _lockout.evaluate(failures, _now());
    if (decision is LockoutCoolingDown) {
      state = AuthCoolingDown(
        until: decision.until,
        failedAttempts: failures.consecutiveFailures,
      );
      return AuthLockedOut(decision.remaining);
    }

    if (_hasher.verify(passcode, creds)) {
      await _store.writeFailureState(AuthFailureState.none);
      state = const AuthUnlocked();
      return const AuthSuccess();
    }

    // Wrong passcode: record the failure and re-evaluate for cooldown (R2.3,
    // R4). The error is deliberately non-revealing.
    final AuthFailureState updated = failures.recordFailure(_now());
    await _store.writeFailureState(updated);
    state = _lockedOrCoolingDown(updated);
    if (state is AuthCoolingDown) {
      return AuthLockedOut((state as AuthCoolingDown).remaining(_now()));
    }
    return const AuthRejected('Incorrect passcode.');
  }

  /// Attempts a biometric unlock, falling back to passcode on any failure
  /// (R3.2, R3.3). Returns success only when the prompt succeeds.
  Future<AuthOutcome> unlockBiometric() async {
    final AuthCredentials? creds = await _store.readCredentials();
    if (creds == null || !creds.biometricEnabled) {
      return const AuthRejected('Biometric unlock is not available.');
    }
    if (!await _biometrics.isAvailable()) {
      return const AuthRejected('Biometric unlock is not available.');
    }
    final bool ok = await _biometrics.authenticate('Unlock Wishable');
    if (ok) {
      await _store.writeFailureState(AuthFailureState.none);
      state = const AuthUnlocked();
      return const AuthSuccess();
    }
    // Biometric failure does NOT count toward the passcode lockout; the user
    // simply falls back to the passcode.
    return const AuthRejected('Biometric authentication was not successful.');
  }

  /// Changes the passcode after verifying [current] (R5.1).
  Future<AuthOutcome> changePasscode({
    required String current,
    required String next,
    required String confirmation,
    PasscodeKind? kind,
  }) async {
    final AuthCredentials? creds = await _store.readCredentials();
    if (creds == null) {
      return const AuthRejected('No passcode is set.');
    }
    if (!_hasher.verify(current, creds)) {
      return const AuthRejected('Current passcode is incorrect.');
    }
    final PasscodeKind newKind = kind ?? creds.kind;
    final PasscodeValidation v =
        PasscodePolicy.validate(next, newKind, confirmation: confirmation);
    if (v is PasscodeInvalid) {
      return AuthInvalid(v.message);
    }
    final AuthCredentials updated = _hasher.enroll(
      next,
      newKind,
      biometricEnabled: creds.biometricEnabled,
      lockTimeout: creds.lockTimeout,
    );
    await _store.writeCredentials(updated);
    await _store.writeFailureState(AuthFailureState.none);
    state = const AuthUnlocked();
    return const AuthSuccess();
  }

  /// Disables the app lock after verifying [current] (R5.2).
  Future<AuthOutcome> disable(String current) async {
    final AuthCredentials? creds = await _store.readCredentials();
    if (creds == null) {
      state = const AuthUnconfigured();
      return const AuthSuccess();
    }
    if (!_hasher.verify(current, creds)) {
      return const AuthRejected('Current passcode is incorrect.');
    }
    await _store.clearCredentials();
    state = const AuthUnconfigured();
    return const AuthSuccess();
  }

  /// Updates the biometric-enabled preference (requires an enrolled passcode).
  Future<void> setBiometricEnabled(bool enabled) async {
    final AuthCredentials? creds = await _store.readCredentials();
    if (creds == null) return;
    await _store.writeCredentials(creds.copyWith(biometricEnabled: enabled));
  }

  /// Updates the auto-lock timeout preference (R6.3).
  Future<void> setLockTimeout(Duration timeout) async {
    final AuthCredentials? creds = await _store.readCredentials();
    if (creds == null) return;
    await _store.writeCredentials(creds.copyWith(lockTimeout: timeout));
  }

  /// Re-locks the app (invoked by the auto-lock observer, R6). A no-op when
  /// unconfigured.
  Future<void> lock() async {
    final AuthCredentials? creds = await _store.readCredentials();
    if (creds == null) {
      state = const AuthUnconfigured();
      return;
    }
    final AuthFailureState failures = await _store.readFailureState();
    state = _lockedOrCoolingDown(failures);
  }

  /// Maps a failure state to either [AuthLocked] or [AuthCoolingDown] depending
  /// on whether a cooldown is currently active.
  AuthState _lockedOrCoolingDown(AuthFailureState failures) {
    final LockoutDecision decision = _lockout.evaluate(failures, _now());
    if (decision is LockoutCoolingDown) {
      return AuthCoolingDown(
        until: decision.until,
        failedAttempts: failures.consecutiveFailures,
      );
    }
    return AuthLocked(failedAttempts: failures.consecutiveFailures);
  }
}
