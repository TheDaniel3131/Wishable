/// Application-layer auth barrel (auth spec, Option A).
///
/// Exposes the [AuthController], its [AuthState]/[AuthOutcome] types, and the
/// interface-typed providers. Depends only on the Drift-free, plugin-free
/// interfaces from the data barrel and the pure domain auth types.
library wishable.application.auth;

export 'auth_controller.dart';
export 'auth_providers.dart';
