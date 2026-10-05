/// [SessionStore] — persists the remote-account session token (auth spec,
/// Option B — R11.1).
///
/// Session tokens are secrets, so they live in `flutter_secure_storage` via the
/// same seam as the passcode verifier — never in the Drift database and never
/// in cleartext. The interface is backend-agnostic (a token string plus the
/// serialized auth-record payload); only the adapter interprets the payload.
///
/// This file imports `flutter_secure_storage`, which is permitted in the data
/// layer. It is kept separate from the PocketBase SDK adapter so the token
/// storage mechanism is reusable and independently testable.
library wishable.data.account.session_store;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists and restores the remote-account session token + auth payload.
abstract interface class SessionStore {
  Future<String?> readToken();
  Future<String?> readRecord();
  Future<void> write(String token, String record);
  Future<void> clear();
}

/// `flutter_secure_storage`-backed [SessionStore].
final class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'wishable.account.token.v1';
  static const String _recordKey = 'wishable.account.record.v1';

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<String?> readRecord() => _storage.read(key: _recordKey);

  @override
  Future<void> write(String token, String record) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _recordKey, value: record);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _recordKey);
  }
}
