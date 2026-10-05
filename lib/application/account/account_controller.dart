/// [AccountController] — the remote-account view-model (auth spec, Option B —
/// R10, R11).
///
/// A Riverpod [Notifier] exposing the current [AccountSession]. It wraps the
/// Drift-free [AccountAuthService] interface; it never imports the PocketBase
/// SDK. Independent of the local app lock [AuthState] (R13): signing in does
/// not unlock the app, and unlocking does not sign in.
///
/// On build it restores any persisted session (R11.1, R11.2). Sign-up / sign-in
/// (email or OAuth) establish a session; sign-out clears it while leaving local
/// Wishes untouched (R11.3). An offline sign-in attempt with no valid session
/// fails gracefully (R10.4); a restored valid session grants local access even
/// when offline.
library wishable.application.account.account_controller;

import 'package:riverpod/riverpod.dart';

import '../../data/account/account_auth_service.dart';
import '../../domain/account/accounts.dart';
import 'account_providers.dart';

/// Drives remote-account authentication, exposing the [AccountSession].
final class AccountController extends Notifier<AccountSession> {
  AccountAuthService get _auth => ref.read(accountAuthServiceProvider);

  @override
  AccountSession build() {
    // React to session changes pushed by the service (token refresh, etc.).
    final sub = _auth.sessionChanges().listen((AccountSession s) {
      state = s;
    });
    ref.onDispose(sub.cancel);
    _restore();
    return const SignedOut();
  }

  Future<void> _restore() async {
    state = await _auth.restore();
  }

  /// Registers a new account with email + password (R10.1).
  Future<AccountSession> signUpEmail(String email, String password) async {
    final AccountSession result = await _auth.signUpEmail(email, password);
    state = result;
    return result;
  }

  /// Signs in with email + password (R10.2).
  Future<AccountSession> signInEmail(String email, String password) async {
    final AccountSession result = await _auth.signInEmail(email, password);
    state = result;
    return result;
  }

  /// Signs in with an OAuth2 [provider] (R10.1, R10.2).
  Future<AccountSession> signInOAuth(OAuthProvider provider) async {
    final AccountSession result = await _auth.signInOAuth(provider);
    state = result;
    return result;
  }

  /// Signs out, clearing the session; local Wishes remain (R11.3).
  Future<void> signOut() async {
    await _auth.signOut();
    state = const SignedOut();
  }

  /// Whether an account is currently signed in.
  bool get isSignedIn => state is SignedIn;
}
