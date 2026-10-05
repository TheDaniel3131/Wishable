// Account controller tests (auth task 15).
//
// Validates: Requirements 10 (sign-up/in success & failure), 11.1/11.2
// (session restore), 11.3 (sign-out keeps local data / clears session).
//
// Drives the real AccountController over a fake AccountAuthService; no SDK, no
// network.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:wishable/application/account/account.dart';
import 'package:wishable/data/account/account_auth_service.dart';
import 'package:wishable/domain/account/accounts.dart';

class FakeAuthService implements AccountAuthService {
  FakeAuthService({this.restoreResult = const SignedOut()});

  AccountSession restoreResult;
  bool signOutCalled = false;
  final StreamController<AccountSession> _changes =
      StreamController<AccountSession>.broadcast();

  // Scriptable results.
  AccountSession Function(String email, String password)? onSignIn;
  AccountSession Function(String email, String password)? onSignUp;
  AccountSession Function(OAuthProvider provider)? onOAuth;

  @override
  Future<AccountSession> restore() async => restoreResult;

  @override
  Future<AccountSession> signInEmail(String email, String password) async =>
      (onSignIn ?? (_, __) => SignedIn(Account(id: 'u1', email: email)))(
          email, password);

  @override
  Future<AccountSession> signUpEmail(String email, String password) async =>
      (onSignUp ?? (_, __) => SignedIn(Account(id: 'u1', email: email)))(
          email, password);

  @override
  Future<AccountSession> signInOAuth(OAuthProvider provider) async =>
      (onOAuth ??
          (_) => const SignedIn(Account(id: 'u1', email: 'o@x.io')))(provider);

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    _changes.add(const SignedOut());
  }

  @override
  Stream<AccountSession> sessionChanges() => _changes.stream;
}

void main() {
  late FakeAuthService auth;

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: <Override>[
          accountAuthServiceProvider.overrideWithValue(auth),
        ],
      );

  setUp(() => auth = FakeAuthService());

  test('starts signed out when no session is restorable (R11.1)', () async {
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    c.read(accountControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(accountControllerProvider), isA<SignedOut>());
  });

  test('restores a persisted session on build (R11.1, R11.2)', () async {
    auth.restoreResult = const SignedIn(Account(id: 'u1', email: 'a@b.io'));
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    c.read(accountControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(accountControllerProvider), isA<SignedIn>());
  });

  test('sign-in success transitions to SignedIn (R10.2)', () async {
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    final AccountController ctrl = c.read(accountControllerProvider.notifier);
    final AccountSession r = await ctrl.signInEmail('a@b.io', 'password');
    expect(r, isA<SignedIn>());
    expect(c.read(accountControllerProvider), isA<SignedIn>());
  });

  test('sign-in failure surfaces an error and stays signed out (R10.3)',
      () async {
    auth.onSignIn = (_, __) => const AccountSessionError('bad credentials');
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    final AccountController ctrl = c.read(accountControllerProvider.notifier);
    final AccountSession r = await ctrl.signInEmail('a@b.io', 'wrong');
    expect(r, isA<AccountSessionError>());
    expect(c.read(accountControllerProvider), isA<AccountSessionError>());
  });

  test('sign-up success transitions to SignedIn (R10.1)', () async {
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    final AccountController ctrl = c.read(accountControllerProvider.notifier);
    expect(await ctrl.signUpEmail('new@b.io', 'password'), isA<SignedIn>());
  });

  test('OAuth sign-in success transitions to SignedIn (R10.1)', () async {
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    final AccountController ctrl = c.read(accountControllerProvider.notifier);
    expect(await ctrl.signInOAuth(OAuthProvider.google), isA<SignedIn>());
  });

  test('sign-out clears the session (R11.3)', () async {
    auth.restoreResult = const SignedIn(Account(id: 'u1', email: 'a@b.io'));
    final ProviderContainer c = makeContainer();
    addTearDown(c.dispose);
    final AccountController ctrl = c.read(accountControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await ctrl.signOut();
    expect(auth.signOutCalled, isTrue);
    expect(c.read(accountControllerProvider), isA<SignedOut>());
  });
}
