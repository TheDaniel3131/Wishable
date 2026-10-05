/// Presentation-layer auth barrel (auth spec, Option A).
///
/// The [AuthGate] (installed in `main.dart`), the [LockScreen], and the
/// [PasscodeSetupView] (shown from Settings). Depends only on the application
/// layer and the pure domain auth types; never imports Drift or a plugin.
library wishable.presentation.auth;

export 'auth_gate.dart';
export 'lock_screen.dart';
export 'passcode_setup_view.dart';
