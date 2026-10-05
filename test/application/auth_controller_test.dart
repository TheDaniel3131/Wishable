// Auth controller tests (auth task 5.3).
//
// Validates: Requirements 1 (enroll), 2 (unlock), 3 (biometric fallback),
// 4 (lockout), 5 (change/disable), 6.2 (locked on start).
//
// Drives the real [AuthController] over a fake in-memory [AuthStore] and a fake
// [BiometricAuthenticator], with an injected clock so lockout timing is
// deterministic. A low-cost hasher keeps the KDF fast. No device, no plugins.

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:wishable/application/auth/auth.dart';
import 'package:wishable/data/auth/auth_store.dart';
import 'package:wishable/data/auth/biometric_authenticator.dart';
import 'package:wishable/domain/auth/auth.dart';

/// In-memory [AuthStore] fake.
class FakeAuthStore implements AuthStore {
  AuthCredentials? _creds;
  AuthFailureState _failures = AuthFailureState.none;

  /// Test helper: pre-seed credentials as if enrolled on a prior launch.
  void seed(AuthCredentials creds) => _creds = creds;

  @override
  Future<void> clearCredentials() async {
    _creds = null;
    _failures = AuthFailureState.none;
  }

  @override
  Future<AuthCredentials?> readCredentials() async => _creds;

  @override
  Future<void> writeCredentials(AuthCredentials credentials) async {
    _creds = credentials;
  }

  @override
  Future<AuthFailureState> readFailureState() async => _failures;

  @override
  Future<void> writeFailureState(AuthFailureState state) async {
    _failures = state;
  }
}

/// Scriptable biometric fake.
class FakeBiometric implements BiometricAuthenticator {
  FakeBiometric({this.available = true, this.willSucceed = true});
  bool available;
  bool willSucceed;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async => willSucceed;
}

void main() {
  late FakeAuthStore store;
  late FakeBiometric biometric;
  late DateTime now;

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: <Override>[
        authStoreProvider.overrideWithValue(store),
        biometricAuthenticatorProvider.overrideWithValue(biometric),
        // Fast KDF for tests.
        passcodeHasherProvider.overrideWithValue(
          const PasscodeHasher(kdf: KdfParams(iterations: 50)),
        ),
        lockoutPolicyProvider.overrideWithValue(
          const LockoutPolicy(
            threshold: 3,
            baseCooldown: Duration(seconds: 30),
            maxCooldown: Duration(minutes: 5),
          ),
        ),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  }

  setUp(() {
    store = FakeAuthStore();
    biometric = FakeBiometric();
    now = DateTime.utc(2026, 1, 1, 12);
  });

  test('unconfigured when no passcode is enrolled (R1.1)', () async {
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    final AuthController ctrl = c.read(authControllerProvider.notifier);
    // Let _initialize run.
    await Future<void>.delayed(Duration.zero);
    expect(c.read(authControllerProvider), isA<AuthUnconfigured>());
    expect(await ctrl.isEnrolled(), isFalse);
  });

  test('enroll stores a verifier and unlocks (R1)', () async {
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    final AuthController ctrl = c.read(authControllerProvider.notifier);

    final AuthOutcome outcome = await ctrl.enroll(
      '123456',
      PasscodeKind.pin,
      confirmation: '123456',
    );
    expect(outcome, isA<AuthSuccess>());
    expect(c.read(authControllerProvider), isA<AuthUnlocked>());
    expect(await ctrl.isEnrolled(), isTrue);
  });

  test('enroll rejects mismatched confirmation (R1.3)', () async {
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    final AuthController ctrl = c.read(authControllerProvider.notifier);
    final AuthOutcome outcome = await ctrl.enroll(
      '123456',
      PasscodeKind.pin,
      confirmation: '000000',
    );
    expect(outcome, isA<AuthInvalid>());
    expect(await ctrl.isEnrolled(), isFalse);
  });

  test('unlock succeeds with the correct passcode (R2.2)', () async {
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    final AuthController ctrl = c.read(authControllerProvider.notifier);
    await ctrl.enroll('123456', PasscodeKind.pin, confirmation: '123456');
    await ctrl.lock();
    expect(c.read(authControllerProvider), isA<AuthLocked>());

    final AuthOutcome outcome = await ctrl.unlock('123456');
    expect(outcome, isA<AuthSuccess>());
    expect(c.read(authControllerProvider), isA<AuthUnlocked>());
  });

  test('unlock fails with the wrong passcode and counts the failure (R2.3)',
      () async {
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    final AuthController ctrl = c.read(authControllerProvider.notifier);
    await ctrl.enroll('123456', PasscodeKind.pin, confirmation: '123456');
    await ctrl.lock();

    final AuthOutcome outcome = await ctrl.unlock('000000');
    expect(outcome, isA<AuthRejected>());
    expect(c.read(authControllerProvider), isA<AuthLocked>());
  });

  test('lockout cools down after the threshold and clears after the wait (R4)',
      () async {
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    final AuthController ctrl = c.read(authControllerProvider.notifier);
    await ctrl.enroll('123456', PasscodeKind.pin, confirmation: '123456');
    await ctrl.lock();

    // 3 wrong attempts hit the threshold (threshold: 3).
    await ctrl.unlock('000000');
    await ctrl.unlock('000000');
    final AuthOutcome third = await ctrl.unlock('000000');
    expect(third, isA<AuthLockedOut>());
    expect(c.read(authControllerProvider), isA<AuthCoolingDown>());

    // Even a correct passcode is refused during cooldown.
    final AuthOutcome duringCooldown = await ctrl.unlock('123456');
    expect(duringCooldown, isA<AuthLockedOut>());

    // Advance the clock past the cooldown: the correct passcode now works.
    now = now.add(const Duration(minutes: 10));
    final AuthOutcome afterCooldown = await ctrl.unlock('123456');
    expect(afterCooldown, isA<AuthSuccess>());
    expect(c.read(authControllerProvider), isA<AuthUnlocked>());
  });

  test('biometric unlock succeeds when available, else falls back (R3)',
      () async {
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    final AuthController ctrl = c.read(authControllerProvider.notifier);
    await ctrl.enroll(
      '123456',
      PasscodeKind.pin,
      confirmation: '123456',
      biometricEnabled: true,
    );
    await ctrl.lock();

    biometric.willSucceed = true;
    expect(await ctrl.unlockBiometric(), isA<AuthSuccess>());
    expect(c.read(authControllerProvider), isA<AuthUnlocked>());

    // When biometrics fail, it does not unlock (falls back to passcode).
    await ctrl.lock();
    biometric.willSucceed = false;
    expect(await ctrl.unlockBiometric(), isA<AuthRejected>());
    expect(c.read(authControllerProvider), isA<AuthLocked>());
  });

  test('changePasscode requires the current passcode (R5.1)', () async {
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    final AuthController ctrl = c.read(authControllerProvider.notifier);
    await ctrl.enroll('123456', PasscodeKind.pin, confirmation: '123456');

    // Wrong current -> rejected.
    expect(
      await ctrl.changePasscode(
          current: '000000', next: '654321', confirmation: '654321'),
      isA<AuthRejected>(),
    );

    // Correct current -> success, and the new passcode works.
    expect(
      await ctrl.changePasscode(
          current: '123456', next: '654321', confirmation: '654321'),
      isA<AuthSuccess>(),
    );
    await ctrl.lock();
    expect(await ctrl.unlock('654321'), isA<AuthSuccess>());
  });

  test('disable clears credentials after verifying current (R5.2)', () async {
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    final AuthController ctrl = c.read(authControllerProvider.notifier);
    await ctrl.enroll('123456', PasscodeKind.pin, confirmation: '123456');

    expect(await ctrl.disable('000000'), isA<AuthRejected>());
    expect(await ctrl.isEnrolled(), isTrue);

    expect(await ctrl.disable('123456'), isA<AuthSuccess>());
    expect(await ctrl.isEnrolled(), isFalse);
    expect(c.read(authControllerProvider), isA<AuthUnconfigured>());
  });

  test('starts locked on cold start when enrolled (R6.2)', () async {
    // Pre-seed the store as if a passcode was enrolled on a previous launch.
    store.seed(const PasscodeHasher(kdf: KdfParams(iterations: 50))
        .enroll('123456', PasscodeKind.pin));
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    c.read(authControllerProvider); // trigger build/_initialize
    await Future<void>.delayed(Duration.zero);
    expect(c.read(authControllerProvider), isA<AuthLocked>());
  });
}
