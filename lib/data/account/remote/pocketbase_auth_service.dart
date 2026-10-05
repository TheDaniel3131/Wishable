/// [PocketbaseAuthService] — the PocketBase [AccountAuthService] adapter
/// (auth spec, Option B — R10, R11).
///
/// The ONLY auth file that imports the `pocketbase` SDK. Maps the backend-
/// agnostic interface onto `pb.collection('users')` auth calls, persists the
/// session token through the [SessionStore] secure seam (R11.1), restores it on
/// launch (R11.1, R11.2), and surfaces session changes.
///
/// Auth method = both: [signInEmail]/[signUpEmail] use `authWithPassword`;
/// [signInOAuth] uses `authWithOAuth2` with an injected URL launcher so this
/// data-layer adapter does not depend on a UI/url-launcher plugin.
library wishable.data.account.remote.pocketbase_auth_service;

import 'dart:async';
import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';

import '../../../domain/account/accounts.dart';
import '../account_auth_service.dart';
import '../session_store.dart';

/// Launches an OAuth2 authorization [url] in the system browser and completes
/// when the flow returns. Injected so the data layer stays UI-plugin-free; the
/// app wires a real launcher (e.g. `url_launcher`) at the composition root.
typedef OAuthUrlLauncher = Future<void> Function(Uri url);

/// PocketBase-backed account authentication.
final class PocketbaseAuthService implements AccountAuthService {
  PocketbaseAuthService(
    this._pb, {
    required SessionStore sessionStore,
    OAuthUrlLauncher? oauthLauncher,
    String usersCollection = 'users',
  })  : _sessions = sessionStore,
        _oauthLauncher = oauthLauncher,
        _usersCollection = usersCollection {
    // Persist/clear the token whenever the SDK's auth store changes (R11.1).
    _pb.authStore.onChange.listen((AuthStoreEvent _) {
      unawaited(_persistCurrent());
      _controller.add(_sessionFromStore());
    });
  }

  final PocketBase _pb;
  final SessionStore _sessions;
  final OAuthUrlLauncher? _oauthLauncher;
  final String _usersCollection;

  final StreamController<AccountSession> _controller =
      StreamController<AccountSession>.broadcast();

  @override
  Future<AccountSession> signUpEmail(String email, String password) async {
    try {
      await _pb.collection(_usersCollection).create(body: <String, dynamic>{
        'email': email,
        'password': password,
        'passwordConfirm': password,
      });
      // After creating the record, authenticate to establish a session.
      return await signInEmail(email, password);
    } catch (error) {
      return AccountSessionError(_describe(error, 'Sign-up failed.'));
    }
  }

  @override
  Future<AccountSession> signInEmail(String email, String password) async {
    try {
      await _pb.collection(_usersCollection).authWithPassword(email, password);
      await _persistCurrent();
      return _sessionFromStore();
    } catch (error) {
      return AccountSessionError(_describe(error, 'Sign-in failed.'));
    }
  }

  @override
  Future<AccountSession> signInOAuth(OAuthProvider provider) async {
    final OAuthUrlLauncher? launch = _oauthLauncher;
    if (launch == null) {
      return const AccountSessionError(
        'OAuth sign-in is not available on this platform.',
      );
    }
    try {
      await _pb.collection(_usersCollection).authWithOAuth2(
            _providerName(provider),
            (Uri url) async => launch(url),
          );
      await _persistCurrent();
      return _sessionFromStore();
    } catch (error) {
      return AccountSessionError(_describe(error, 'OAuth sign-in failed.'));
    }
  }

  @override
  Future<void> signOut() async {
    _pb.authStore.clear();
    await _sessions.clear();
    _controller.add(const SignedOut());
  }

  @override
  Future<AccountSession> restore() async {
    try {
      final String? token = await _sessions.readToken();
      final String? recordJson = await _sessions.readRecord();
      if (token == null || token.isEmpty || recordJson == null) {
        return const SignedOut();
      }
      final RecordModel record =
          RecordModel.fromJson(json.decode(recordJson) as Map<String, dynamic>);
      _pb.authStore.save(token, record);
      if (!_pb.authStore.isValid) {
        return const SignedOut();
      }
      // Refresh the token transparently (R11.2); ignore failure here and fall
      // back to the restored (still-valid) token.
      try {
        await _pb.collection(_usersCollection).authRefresh();
        await _persistCurrent();
      } catch (_) {
        // Keep the restored session; a hard refresh failure is handled on the
        // next authenticated call.
      }
      return _sessionFromStore();
    } catch (error) {
      // A corrupt stored session is treated as signed-out, not a crash.
      return const SignedOut();
    }
  }

  @override
  Stream<AccountSession> sessionChanges() => _controller.stream;

  // --- Helpers -------------------------------------------------------------

  Future<void> _persistCurrent() async {
    if (_pb.authStore.isValid && _pb.authStore.record != null) {
      await _sessions.write(
        _pb.authStore.token,
        json.encode(_pb.authStore.record!.toJson()),
      );
    } else {
      await _sessions.clear();
    }
  }

  AccountSession _sessionFromStore() {
    final RecordModel? record = _pb.authStore.record;
    if (!_pb.authStore.isValid || record == null) {
      return const SignedOut();
    }
    return SignedIn(_accountFromRecord(record));
  }

  Account _accountFromRecord(RecordModel record) {
    final Map<String, dynamic> data = record.toJson();
    return Account(
      id: record.id,
      email: (data['email'] as String?) ?? '',
      displayName: data['name'] as String?,
      verified: (data['verified'] as bool?) ?? false,
    );
  }

  String _providerName(OAuthProvider provider) => switch (provider) {
        OAuthProvider.google => 'google',
        OAuthProvider.apple => 'apple',
        OAuthProvider.github => 'github',
      };

  /// Produces a user-facing, non-sensitive message from a backend error
  /// (R10.3). Never includes tokens or raw payloads.
  String _describe(Object error, String fallback) {
    if (error is ClientException) {
      final Object? message = error.response['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
      if (error.statusCode == 0) {
        return 'You appear to be offline. Check your connection and try again.';
      }
    }
    return fallback;
  }

  /// Releases the session-change stream.
  Future<void> dispose() => _controller.close();
}
