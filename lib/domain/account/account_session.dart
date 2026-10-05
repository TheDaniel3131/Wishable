/// The remote-account session state (auth spec, Option B — R10, R11).
///
/// Pure domain type. The application layer's `AccountController` exposes an
/// [AccountSession]; the UI renders sign-in vs signed-in from it. Independent
/// of the local app-lock [AuthState] (R13): being signed in does not unlock the
/// app, and unlocking does not sign in.
library wishable.domain.account.account_session;

import 'account.dart';

/// Base type for the account session. Sealed for exhaustive handling.
sealed class AccountSession {
  const AccountSession();
}

/// No account is signed in; the app runs purely locally/offline (R14.3).
final class SignedOut extends AccountSession {
  const SignedOut();

  @override
  bool operator ==(Object other) => other is SignedOut;
  @override
  int get hashCode => (SignedOut).hashCode;
}

/// An account is signed in (R10.2). [account] carries the identity; tokens are
/// held in secure storage, not here.
final class SignedIn extends AccountSession {
  const SignedIn(this.account);

  final Account account;

  @override
  bool operator ==(Object other) =>
      other is SignedIn && other.account == account;
  @override
  int get hashCode => Object.hash(SignedIn, account);
}

/// A sign-in/up/refresh attempt failed; carries a user-facing, non-sensitive
/// message (R10.3, R11.4).
final class AccountSessionError extends AccountSession {
  const AccountSessionError(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      other is AccountSessionError && other.message == message;
  @override
  int get hashCode => Object.hash(AccountSessionError, message);
}
