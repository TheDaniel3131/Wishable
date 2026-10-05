/// Riverpod providers for the app-lock auth feature (auth spec, Option A —
/// R8.1).
///
/// ## Interface-only exposure
///
/// The store and biometric providers are typed as their ABSTRACT interfaces
/// ([AuthStore], [BiometricAuthenticator]). The concrete, plugin-backed
/// implementations ([SecureAuthStore], [LocalAuthBiometric]) appear ONLY inside
/// the provider bodies here — the single composition seam — so the controller
/// and the presentation layer depend on Drift-free, plugin-free interfaces and
/// never import `flutter_secure_storage` or `local_auth`.
///
/// The pure domain collaborators ([PasscodeHasher], [LockoutPolicy]) and a
/// [Clock] are also exposed so tests can override them with deterministic
/// fakes.
library wishable.application.auth.auth_providers;

import 'package:riverpod/riverpod.dart';

import '../../data/auth/auth_store.dart';
import '../../data/auth/biometric_authenticator.dart';
import '../../data/auth/local_auth_biometric.dart';
import '../../data/auth/secure_auth_store.dart';
import '../../domain/auth/auth.dart';
import 'auth_controller.dart';

/// A source of the current time, injectable so tests can control the clock the
/// lockout policy reads (R4).
typedef Clock = DateTime Function();

/// Default wall-clock, in UTC.
DateTime _utcNow() => DateTime.now().toUtc();

/// Provides the current-time function. Overridden in tests.
final Provider<Clock> clockProvider = Provider<Clock>(
  (Ref ref) => _utcNow,
  name: 'auth.clockProvider',
);

/// Provides the [AuthStore], backed by [SecureAuthStore]. Typed as the
/// interface so consumers never see the plugin.
final Provider<AuthStore> authStoreProvider = Provider<AuthStore>(
  (Ref ref) => SecureAuthStore(),
  name: 'auth.authStoreProvider',
);

/// Provides the [BiometricAuthenticator], backed by [LocalAuthBiometric].
final Provider<BiometricAuthenticator> biometricAuthenticatorProvider =
    Provider<BiometricAuthenticator>(
  (Ref ref) => LocalAuthBiometric(),
  name: 'auth.biometricAuthenticatorProvider',
);

/// Provides the pure passcode hasher (KDF verifier).
final Provider<PasscodeHasher> passcodeHasherProvider =
    Provider<PasscodeHasher>(
  (Ref ref) => const PasscodeHasher(),
  name: 'auth.passcodeHasherProvider',
);

/// Provides the pure lockout policy (brute-force backoff).
final Provider<LockoutPolicy> lockoutPolicyProvider = Provider<LockoutPolicy>(
  (Ref ref) => const LockoutPolicy(),
  name: 'auth.lockoutPolicyProvider',
);

/// The app-lock controller and its [AuthState].
final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(
  AuthController.new,
  name: 'auth.authControllerProvider',
);
