/// Riverpod providers for the remote-account + sync feature (auth spec,
/// Option B — R14).
///
/// ## Interface-only exposure + inert-when-unconfigured
///
/// [accountAuthServiceProvider] and [syncServiceProvider] are typed as their
/// abstract interfaces. The concrete PocketBase adapters are constructed only
/// inside the provider bodies here (the composition seam), and ONLY when a
/// backend URL is configured. When unconfigured, the providers resolve to inert
/// no-op implementations so the app is fully offline-first: signed-out, no
/// network, and the local Wishes graph never touches the remote layer (R14.1,
/// R14.3).
///
/// This file imports the PocketBase adapter + SDK bootstrap under
/// `data/account/remote/`, which is permitted at the composition root. The
/// controllers and the presentation layer depend only on the interfaces.
library wishable.application.account.account_providers;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod/riverpod.dart';

import '../../data/account/account_auth_service.dart';
import '../../data/account/remote/pocketbase_auth_service.dart';
import '../../data/account/remote/pocketbase_client.dart';
import '../../data/account/remote/pocketbase_sync_service.dart';
import '../../data/account/session_store.dart';
import '../../data/account/sync_service.dart';
import '../../domain/account/accounts.dart';
import '../../domain/wish.dart';
import 'account_controller.dart';
import 'sync_controller.dart';

/// Lazily-built shared PocketBase client, or null when unconfigured.
final Provider<PocketBase?> _pocketBaseClientProvider = Provider<PocketBase?>(
  (Ref ref) =>
      isPocketBaseConfigured ? createPocketBaseClient(kPocketBaseUrl) : null,
  name: 'account._pocketBaseClientProvider',
);

/// The session token store (secure storage).
final Provider<SessionStore> sessionStoreProvider = Provider<SessionStore>(
  (Ref ref) => SecureSessionStore(),
  name: 'account.sessionStoreProvider',
);

/// The [AccountAuthService]: PocketBase when configured, else an inert no-op
/// that stays signed-out (R14.1).
final Provider<AccountAuthService> accountAuthServiceProvider =
    Provider<AccountAuthService>(
  (Ref ref) {
    final PocketBase? client = ref.watch(_pocketBaseClientProvider);
    if (client == null) {
      return const _InertAuthService();
    }
    return PocketbaseAuthService(
      client,
      sessionStore: ref.watch(sessionStoreProvider),
    );
  },
  name: 'account.accountAuthServiceProvider',
);

/// The [SyncService]: PocketBase when configured, else an inert no-op.
final Provider<SyncService> syncServiceProvider = Provider<SyncService>(
  (Ref ref) {
    final PocketBase? client = ref.watch(_pocketBaseClientProvider);
    if (client == null) {
      return const _InertSyncService();
    }
    return PocketbaseSyncService(client);
  },
  name: 'account.syncServiceProvider',
);

/// Observes connectivity via `connectivity_plus`.
final Provider<ConnectivityProbe> connectivityProbeProvider =
    Provider<ConnectivityProbe>(
  (Ref ref) => const _ConnectivityPlusProbe(),
  name: 'account.connectivityProbeProvider',
);

/// The account session controller.
final NotifierProvider<AccountController, AccountSession>
    accountControllerProvider =
    NotifierProvider<AccountController, AccountSession>(
  AccountController.new,
  name: 'account.accountControllerProvider',
);

/// The sync controller.
final NotifierProvider<SyncController, SyncState> syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(
  SyncController.new,
  name: 'account.syncControllerProvider',
);

// --- Inert (unconfigured) implementations ----------------------------------

/// An [AccountAuthService] used when no backend is configured: always
/// signed-out, no network (R14.1).
final class _InertAuthService implements AccountAuthService {
  const _InertAuthService();

  @override
  Future<AccountSession> restore() async => const SignedOut();
  @override
  Future<AccountSession> signInEmail(String email, String password) async =>
      const AccountSessionError('Remote accounts are not configured.');
  @override
  Future<AccountSession> signUpEmail(String email, String password) async =>
      const AccountSessionError('Remote accounts are not configured.');
  @override
  Future<AccountSession> signInOAuth(OAuthProvider provider) async =>
      const AccountSessionError('Remote accounts are not configured.');
  @override
  Future<void> signOut() async {}
  @override
  Stream<AccountSession> sessionChanges() =>
      const Stream<AccountSession>.empty();
}

/// A [SyncService] used when no backend is configured: no-op (R14.3).
final class _InertSyncService implements SyncService {
  const _InertSyncService();

  @override
  Future<void> pushLocalChanges(
      List<Wish> wishes, List<String> deletedIds) async {}
  @override
  Future<List<RemoteChange>> pullRemoteChanges(DateTime? since) async =>
      const <RemoteChange>[];
  @override
  Future<List<RemoteChange>> fullReconcile() async => const <RemoteChange>[];
  @override
  Future<void> pushLocalImages(
      List<LocalImageUpload> uploads, List<String> deletedIds) async {}
  @override
  Future<List<RemoteImageChange>> pullRemoteImages(DateTime? since) async =>
      const <RemoteImageChange>[];
}

/// Connectivity probe backed by `connectivity_plus`.
final class _ConnectivityPlusProbe implements ConnectivityProbe {
  const _ConnectivityPlusProbe();

  @override
  Future<bool> isOnline() async {
    final List<ConnectivityResult> result =
        await Connectivity().checkConnectivity();
    return result.any((ConnectivityResult r) => r != ConnectivityResult.none);
  }
}
