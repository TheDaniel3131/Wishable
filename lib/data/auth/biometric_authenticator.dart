/// The [BiometricAuthenticator] abstract interface (auth spec, Option A — R3).
///
/// Drift-free, plugin-free boundary over the platform biometric prompt. The
/// application layer depends on this interface only; the concrete
/// [LocalAuthBiometric] (backed by `local_auth`) lives in the data layer.
library wishable.data.auth.biometric_authenticator;

/// Abstracts the platform biometric prompt so the controller can offer
/// fingerprint/face unlock without importing a plugin, and so tests can fake it.
abstract interface class BiometricAuthenticator {
  /// Whether this device/OS can perform a biometric check right now (hardware
  /// present and at least one biometric enrolled). Returns `false` where
  /// unsupported, e.g. most web contexts (R3.4).
  Future<bool> isAvailable();

  /// Prompts for biometric authentication, showing [reason] to the user.
  /// Returns `true` only on success; `false` on failure, cancellation, or
  /// unavailability, so the caller falls back to the passcode (R3.2, R3.3).
  Future<bool> authenticate(String reason);
}
