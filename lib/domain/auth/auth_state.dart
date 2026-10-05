/// The app-lock authentication state (auth spec, Option A).
///
/// Pure domain type — no Flutter, no Drift, no plugins. The [AuthController]
/// (application layer) exposes an [AuthState] and the [AuthGate] (presentation
/// layer) renders the app or the lock screen from it.
///
/// States (requirements R1.1, R2.1, R2.2, R4.2):
///   - [AuthUnconfigured] — no passcode enrolled; the app is always unlocked
///     and behaves exactly as before this feature existed (R1.1).
///   - [AuthLocked]       — a passcode is enrolled and the app is waiting for
///     the user to authenticate (R2.1). [failedAttempts] carries the current
///     consecutive-failure count so the lock screen can hint remaining tries.
///   - [AuthUnlocked]     — the user authenticated this session (R2.2).
///   - [AuthCoolingDown]  — too many failed attempts; unlock is temporarily
///     refused until [until] (R4.2).
library wishable.domain.auth.auth_state;

/// Base type for the app-lock state. Sealed so exhaustive `switch` expressions
/// cover every case.
sealed class AuthState {
  const AuthState();
}

/// No passcode is enrolled; the app is always accessible (R1.1).
final class AuthUnconfigured extends AuthState {
  const AuthUnconfigured();

  @override
  bool operator ==(Object other) => other is AuthUnconfigured;

  @override
  int get hashCode => (AuthUnconfigured).hashCode;
}

/// A passcode is enrolled and the app is locked, awaiting authentication
/// (R2.1). [failedAttempts] is the current consecutive-failure count.
final class AuthLocked extends AuthState {
  const AuthLocked({this.failedAttempts = 0});

  /// Consecutive failed unlock attempts since the last success.
  final int failedAttempts;

  @override
  bool operator ==(Object other) =>
      other is AuthLocked && other.failedAttempts == failedAttempts;

  @override
  int get hashCode => Object.hash(AuthLocked, failedAttempts);
}

/// The user has authenticated for this session (R2.2).
final class AuthUnlocked extends AuthState {
  const AuthUnlocked();

  @override
  bool operator ==(Object other) => other is AuthUnlocked;

  @override
  int get hashCode => (AuthUnlocked).hashCode;
}

/// Unlock is temporarily refused after too many failures until [until] (R4.2).
final class AuthCoolingDown extends AuthState {
  const AuthCoolingDown({required this.until, required this.failedAttempts});

  /// The instant (UTC) at which unlock attempts are accepted again.
  final DateTime until;

  /// The consecutive-failure count that triggered the cooldown.
  final int failedAttempts;

  /// The remaining cooldown relative to [now].
  Duration remaining(DateTime now) {
    final Duration diff = until.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  bool operator ==(Object other) =>
      other is AuthCoolingDown &&
      other.until == until &&
      other.failedAttempts == failedAttempts;

  @override
  int get hashCode => Object.hash(AuthCoolingDown, until, failedAttempts);
}
