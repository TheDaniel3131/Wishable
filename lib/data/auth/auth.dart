/// Data-layer auth barrel (auth spec, Option A).
///
/// Exposes the Drift-free, plugin-free interfaces ([AuthStore],
/// [BiometricAuthenticator]) and their concrete, plugin-backed implementations
/// ([SecureAuthStore], [LocalAuthBiometric]). The concretes are wired only at
/// the composition root (application/providers); application/presentation code
/// depends on the interfaces. The plugin imports (`flutter_secure_storage`,
/// `local_auth`) are confined to the concrete files here, never above the data
/// layer.
library wishable.data.auth;

export 'auth_store.dart';
export 'biometric_authenticator.dart';
export 'local_auth_biometric.dart';
export 'secure_auth_store.dart';
