/// Auth domain barrel (auth spec, Option A).
///
/// Pure Dart app-lock domain: the [AuthState] machine, the passcode policy,
/// the KDF-based verifier, the lockout policy, and the stored-credentials value
/// types. No Flutter, no Drift, no plugins — fully unit/property-testable.
library wishable.domain.auth;

export 'auth_credentials.dart';
export 'auth_state.dart';
export 'lockout_policy.dart';
export 'passcode_hasher.dart';
export 'passcode_policy.dart';
