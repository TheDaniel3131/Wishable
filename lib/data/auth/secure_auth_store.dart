/// [SecureAuthStore] — the `flutter_secure_storage`-backed [AuthStore]
/// (auth spec, Option A — R7.1, R7.2).
///
/// This is the ONLY auth file that imports `flutter_secure_storage`; it lives
/// in the data layer so the plugin never leaks into the application or
/// presentation layers. It persists the credentials as a JSON document under a
/// single key, encoding the binary verifier and salt as base64. It stores only
/// the non-reversible verifier and its parameters — never the passcode (R1.5,
/// R7.1) — and nothing is written to the Drift database in cleartext.
///
/// On platforms with a native secure store (iOS Keychain, Android Keystore-
/// backed EncryptedSharedPreferences, macOS Keychain, Windows credential
/// store, Linux libsecret) the data is protected by the OS. On web, the plugin
/// falls back to (less protected) browser storage; the stored value is still
/// only the verifier, and the Settings UI documents the reduced protection
/// (R7.2).
library wishable.data.auth.secure_auth_store;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/auth/auth_credentials.dart';
import '../../domain/auth/passcode_policy.dart';
import 'auth_store.dart';

/// Secure-store-backed implementation of [AuthStore].
final class SecureAuthStore implements AuthStore {
  SecureAuthStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  /// Key under which the credentials JSON is stored.
  static const String _credentialsKey = 'wishable.auth.credentials.v1';

  /// Key under which the failure-state JSON is stored.
  static const String _failureKey = 'wishable.auth.failures.v1';

  @override
  Future<AuthCredentials?> readCredentials() async {
    final String? raw = await _storage.read(key: _credentialsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Map<String, Object?> map =
          json.decode(raw) as Map<String, Object?>;
      return _credentialsFromMap(map);
    } catch (_) {
      // A corrupt/unreadable payload is treated as "no credentials" rather
      // than crashing the app; the user can re-enroll. Never log the payload.
      return null;
    }
  }

  @override
  Future<void> writeCredentials(AuthCredentials credentials) async {
    final String raw = json.encode(_credentialsToMap(credentials));
    await _storage.write(key: _credentialsKey, value: raw);
  }

  @override
  Future<void> clearCredentials() async {
    await _storage.delete(key: _credentialsKey);
    await _storage.delete(key: _failureKey);
  }

  @override
  Future<AuthFailureState> readFailureState() async {
    final String? raw = await _storage.read(key: _failureKey);
    if (raw == null || raw.isEmpty) {
      return AuthFailureState.none;
    }
    try {
      final Map<String, Object?> map =
          json.decode(raw) as Map<String, Object?>;
      final int failures = (map['failures'] as int?) ?? 0;
      final String? lastIso = map['lastFailureUtc'] as String?;
      return AuthFailureState(
        consecutiveFailures: failures,
        lastFailureUtc: lastIso == null ? null : DateTime.parse(lastIso),
      );
    } catch (_) {
      return AuthFailureState.none;
    }
  }

  @override
  Future<void> writeFailureState(AuthFailureState state) async {
    final String raw = json.encode(<String, Object?>{
      'failures': state.consecutiveFailures,
      'lastFailureUtc': state.lastFailureUtc?.toUtc().toIso8601String(),
    });
    await _storage.write(key: _failureKey, value: raw);
  }

  // --- Serialization -------------------------------------------------------

  static Map<String, Object?> _credentialsToMap(AuthCredentials c) {
    return <String, Object?>{
      'verifier': base64.encode(c.verifier),
      'salt': base64.encode(c.salt),
      'kdf': c.kdf.toMap(),
      'kind': c.kind.name,
      'biometricEnabled': c.biometricEnabled,
      'lockTimeoutMs': c.lockTimeout.inMilliseconds,
    };
  }

  static AuthCredentials _credentialsFromMap(Map<String, Object?> map) {
    final PasscodeKind kind = PasscodeKind.values.firstWhere(
      (PasscodeKind k) => k.name == map['kind'],
      orElse: () => PasscodeKind.password,
    );
    return AuthCredentials(
      verifier: Uint8List.fromList(base64.decode(map['verifier'] as String)),
      salt: Uint8List.fromList(base64.decode(map['salt'] as String)),
      kdf: KdfParams.fromMap((map['kdf'] as Map<String, Object?>?) ?? const <String, Object?>{}),
      kind: kind,
      biometricEnabled: (map['biometricEnabled'] as bool?) ?? false,
      lockTimeout: Duration(milliseconds: (map['lockTimeoutMs'] as int?) ?? 0),
    );
  }
}
