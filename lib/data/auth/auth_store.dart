/// The [AuthStore] abstract interface (auth spec, Option A — R7.1).
///
/// A Drift-free, plugin-free boundary for persisting the app-lock credentials
/// and failure state. The application layer depends on this interface only; the
/// concrete [SecureAuthStore] (backed by `flutter_secure_storage`) lives in the
/// data layer and is the only code that imports the plugin.
///
/// The store persists a NON-REVERSIBLE verifier plus its derivation parameters
/// and user preferences — never the passcode (R1.5, R7.1). The failure state is
/// stored separately so a wrong attempt never rewrites the verifier (R4).
library wishable.data.auth.auth_store;

import '../../domain/auth/auth_credentials.dart';

/// Persists app-lock credentials and failure state in a platform-appropriate
/// secure location.
abstract interface class AuthStore {
  /// Reads the stored credentials, or `null` when no passcode is enrolled
  /// (the unconfigured state, R1.1).
  Future<AuthCredentials?> readCredentials();

  /// Writes [credentials], replacing any existing enrollment (R1, R5.1).
  Future<void> writeCredentials(AuthCredentials credentials);

  /// Removes all stored credentials, returning the app to the unconfigured
  /// state (R5.2).
  Future<void> clearCredentials();

  /// Reads the current unlock-failure state (R4).
  Future<AuthFailureState> readFailureState();

  /// Writes the unlock-failure state (R4).
  Future<void> writeFailureState(AuthFailureState state);
}
