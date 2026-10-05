/// The [AccountAuthService] abstract interface (auth spec, Option B — R10, R11).
///
/// Backend-agnostic boundary for remote account authentication. The application
/// layer depends on this interface only; the concrete adapter (PocketBase)
/// lives under `data/account/remote/` and is the sole importer of the backend
/// SDK, so the SDK never leaks above the data layer (offline-first test, R14.2).
///
/// Auth method = both: [signUpEmail]/[signInEmail] for email+password and
/// [signInOAuth] for OAuth2 providers.
library wishable.data.account.account_auth_service;

import '../../domain/account/accounts.dart';

/// Supported OAuth2 providers (extend as the backend enables more).
enum OAuthProvider { google, apple, github }

/// Authenticates a remote account and manages its session.
abstract interface class AccountAuthService {
  /// Registers a new account with [email] + [password] and establishes a
  /// session (R10.1).
  Future<AccountSession> signUpEmail(String email, String password);

  /// Signs in with [email] + [password] (R10.2).
  Future<AccountSession> signInEmail(String email, String password);

  /// Signs in with an OAuth2 [provider] (R10.1, R10.2).
  Future<AccountSession> signInOAuth(OAuthProvider provider);

  /// Signs out, clearing the local session; local Wishes are untouched (R11.3).
  Future<void> signOut();

  /// Restores a persisted session on launch (from the secure token store),
  /// refreshing the token if needed (R11.1, R11.2). Returns [SignedOut] when
  /// there is no valid session.
  Future<AccountSession> restore();

  /// Emits session changes (sign-in / sign-out / refresh) so controllers can
  /// react (R11).
  Stream<AccountSession> sessionChanges();
}
