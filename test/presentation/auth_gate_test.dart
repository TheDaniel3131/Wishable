// Widget test for the app-lock gate (auth task 6.4).
//
// Validates: Requirements 2.1 (locked state withholds the app content),
// and that an unconfigured/unlocked state reveals it.
//
// Uses the real AuthGate over a fake in-memory AuthStore so the controller
// resolves to a deterministic state. The "app" content is a sentinel widget;
// the test asserts it is absent while locked and present while unlocked.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishable/application/auth/auth.dart';
import 'package:wishable/data/auth/auth_store.dart';
import 'package:wishable/data/auth/biometric_authenticator.dart';
import 'package:wishable/domain/auth/auth.dart';
import 'package:wishable/presentation/auth/auth_gate.dart';

class _FakeStore implements AuthStore {
  AuthCredentials? creds;
  AuthFailureState failures = AuthFailureState.none;

  @override
  Future<void> clearCredentials() async => creds = null;
  @override
  Future<AuthCredentials?> readCredentials() async => creds;
  @override
  Future<void> writeCredentials(AuthCredentials c) async => creds = c;
  @override
  Future<AuthFailureState> readFailureState() async => failures;
  @override
  Future<void> writeFailureState(AuthFailureState s) async => failures = s;
}

class _FakeBiometric implements BiometricAuthenticator {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<bool> authenticate(String reason) async => false;
}

const Key _appContent = Key('app-content');

Widget _app(_FakeStore store) {
  return ProviderScope(
    overrides: <Override>[
      authStoreProvider.overrideWithValue(store),
      biometricAuthenticatorProvider.overrideWithValue(_FakeBiometric()),
      passcodeHasherProvider.overrideWithValue(
          const PasscodeHasher(kdf: KdfParams(iterations: 50))),
    ],
    child: const MaterialApp(
      home: LockGuard(
        child: Scaffold(body: Center(child: Text('WISHES', key: _appContent))),
      ),
    ),
  );
}

void main() {
  testWidgets('reveals the app when unconfigured (R1.1)',
      (WidgetTester tester) async {
    final _FakeStore store = _FakeStore(); // no credentials
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.byKey(_appContent), findsOneWidget);
    expect(find.text('Wishable is locked'), findsNothing);
  });

  testWidgets('withholds the app and shows the lock screen when locked (R2.1)',
      (WidgetTester tester) async {
    final _FakeStore store = _FakeStore()
      ..creds = const PasscodeHasher(kdf: KdfParams(iterations: 50))
          .enroll('123456', PasscodeKind.pin);

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    // The lock screen is shown; the app content is NOT in the tree.
    expect(find.text('Wishable is locked'), findsOneWidget);
    expect(find.byKey(_appContent), findsNothing);
  });

  testWidgets('reveals the app after a successful unlock',
      (WidgetTester tester) async {
    final _FakeStore store = _FakeStore()
      ..creds = const PasscodeHasher(kdf: KdfParams(iterations: 50))
          .enroll('123456', PasscodeKind.pin);

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    expect(find.byKey(_appContent), findsNothing);

    // Drive an unlock through the controller element.
    final BuildContext ctx = tester.element(find.byType(LockGuard));
    final ProviderContainer container = ProviderScope.containerOf(ctx);
    final AuthOutcome outcome =
        await container.read(authControllerProvider.notifier).unlock('123456');
    expect(outcome, isA<AuthSuccess>());
    await tester.pumpAndSettle();

    expect(find.byKey(_appContent), findsOneWidget);
  });
}
