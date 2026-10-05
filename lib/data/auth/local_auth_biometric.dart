/// [LocalAuthBiometric] — the `local_auth`-backed [BiometricAuthenticator]
/// (auth spec, Option A — R3).
///
/// This is the ONLY auth file that imports `local_auth`; it lives in the data
/// layer so the plugin never leaks upward. Every call is wrapped so that any
/// platform exception, unavailability, or user cancellation becomes a plain
/// `false`, letting the controller fall back to passcode entry (R3.3, R3.4).
library wishable.data.auth.local_auth_biometric;

import 'package:local_auth/local_auth.dart';

import 'biometric_authenticator.dart';

/// Biometric authentication over the platform's `local_auth` plugin.
final class LocalAuthBiometric implements BiometricAuthenticator {
  LocalAuthBiometric([LocalAuthentication? localAuth])
      : _auth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      final bool supported = await _auth.isDeviceSupported();
      if (!supported) {
        return false;
      }
      final bool canCheck = await _auth.canCheckBiometrics;
      return canCheck;
    } catch (_) {
      // Any plugin/platform error means biometrics are effectively
      // unavailable; the UI hides the option and passcode remains (R3.4).
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      // Failure, cancellation, or an unexpected plugin error all fall back to
      // passcode entry; the gate is never bypassed (R3.3).
      return false;
    }
  }
}
