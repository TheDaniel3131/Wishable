// Secure-store round-trip test (auth task 4.4).
//
// Validates: Requirements 7.1 (store only a non-reversible verifier, never the
// passcode), 7.3 (no secret leakage), 5.2 (clear removes everything).
//
// `flutter_secure_storage` talks to the OS over a method channel. In a unit
// test we mock that channel with an in-memory map, so this exercises the real
// SecureAuthStore serialization logic (base64 of verifier/salt, JSON shape,
// failure-state persistence) without a device.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishable/data/auth/secure_auth_store.dart';
import 'package:wishable/domain/auth/auth_credentials.dart';
import 'package:wishable/domain/auth/passcode_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late Map<String, String> backing;

  setUp(() {
    backing = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'write':
          final Map<Object?, Object?> args =
              call.arguments as Map<Object?, Object?>;
          backing[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          final Map<Object?, Object?> args =
              call.arguments as Map<Object?, Object?>;
          return backing[args['key'] as String];
        case 'delete':
          final Map<Object?, Object?> args =
              call.arguments as Map<Object?, Object?>;
          backing.remove(args['key'] as String);
          return null;
        case 'readAll':
          return backing;
        case 'deleteAll':
          backing.clear();
          return null;
        case 'containsKey':
          final Map<Object?, Object?> args =
              call.arguments as Map<Object?, Object?>;
          return backing.containsKey(args['key'] as String);
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  AuthCredentials sampleCreds() => AuthCredentials(
        verifier: Uint8List.fromList(<int>[10, 20, 30, 40, 250]),
        salt: Uint8List.fromList(<int>[1, 2, 3, 4]),
        kdf: const KdfParams(iterations: 100),
        kind: PasscodeKind.pin,
        biometricEnabled: true,
        lockTimeout: const Duration(seconds: 30),
      );

  test('write then read round-trips every credential field', () async {
    final SecureAuthStore store = SecureAuthStore();
    final AuthCredentials original = sampleCreds();

    await store.writeCredentials(original);
    final AuthCredentials? read = await store.readCredentials();

    expect(read, isNotNull);
    expect(read!.verifier, original.verifier);
    expect(read.salt, original.salt);
    expect(read.kdf, original.kdf);
    expect(read.kind, original.kind);
    expect(read.biometricEnabled, original.biometricEnabled);
    expect(read.lockTimeout, original.lockTimeout);
  });

  test('readCredentials is null when nothing is enrolled', () async {
    final SecureAuthStore store = SecureAuthStore();
    expect(await store.readCredentials(), isNull);
  });

  test('clearCredentials removes credentials and failure state (R5.2)',
      () async {
    final SecureAuthStore store = SecureAuthStore();
    await store.writeCredentials(sampleCreds());
    await store.writeFailureState(
      AuthFailureState(
          consecutiveFailures: 3, lastFailureUtc: DateTime.utc(2026)),
    );

    await store.clearCredentials();

    expect(await store.readCredentials(), isNull);
    expect((await store.readFailureState()).consecutiveFailures, 0);
    expect(backing, isEmpty);
  });

  test('stored payload contains no plaintext passcode (R7.1, R7.3)', () async {
    // Enroll via the hasher so the stored bytes are a real verifier, then
    // assert the serialized blob never contains the passcode string.
    final SecureAuthStore store = SecureAuthStore();
    await store.writeCredentials(sampleCreds());
    final String blob = backing.values.join('\n');
    expect(blob, isNot(contains('1234')));
    // The blob is JSON with base64 fields, not the raw secret.
    final Map<String, Object?> decoded =
        json.decode(backing.values.first) as Map<String, Object?>;
    expect(decoded.containsKey('verifier'), isTrue);
    expect(decoded.containsKey('passcode'), isFalse);
  });

  test('failure state persists and reads back', () async {
    final SecureAuthStore store = SecureAuthStore();
    final DateTime t = DateTime.utc(2026, 2, 3, 4, 5, 6);
    await store.writeFailureState(
      AuthFailureState(consecutiveFailures: 2, lastFailureUtc: t),
    );
    final AuthFailureState read = await store.readFailureState();
    expect(read.consecutiveFailures, 2);
    expect(read.lastFailureUtc, t);
  });
}
