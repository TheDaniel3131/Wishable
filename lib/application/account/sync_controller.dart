/// [SyncController] — orchestrates Wish sync (auth spec, Option B — R12).
///
/// A Riverpod [Notifier] exposing [SyncState]. It drives the Drift-free
/// [SyncService] interface and the local [WishRepository] / [CategoryRepository]
/// to converge local and remote state. It never imports the backend SDK.
///
/// A sync cycle (R12.1):
///   1. If offline, set [SyncOffline] and stop (changes accumulate locally,
///      R12.3).
///   2. Pull remote changes since the last watermark, translating each remote
///      record's category NAME into a local category id (get-or-create).
///   3. Merge via the pure [mergeSync] (last-write-wins by `updatedAtUtc`,
///      tombstone for delete-vs-edit, R12.2) and apply the resulting upserts
///      and deletions to the local database.
///   4. Push local Wishes (projecting their categoryId to the category NAME).
///
/// A failed sync leaves the local database consistent and surfaces a
/// non-blocking [SyncError]; the next cycle retries (R12.4).
library wishable.application.account.sync_controller;

import 'package:riverpod/riverpod.dart';

import '../../data/account/sync_service.dart';
import '../../domain/account/accounts.dart';
import '../../domain/category.dart';
import '../../domain/wish.dart';
import '../providers.dart';
import 'account_providers.dart';

/// Observes connectivity so a sync is attempted only when online. Injected so
/// tests can force online/offline deterministically.
abstract interface class ConnectivityProbe {
  Future<bool> isOnline();
}

/// Drives Wish synchronization, exposing [SyncState].
final class SyncController extends Notifier<SyncState> {
  SyncService get _sync => ref.read(syncServiceProvider);
  ConnectivityProbe get _connectivity => ref.read(connectivityProbeProvider);

  DateTime? _watermark;

  @override
  SyncState build() => const SyncIdle();

  /// Runs one full sync cycle. Only meaningful while signed in; a signed-out
  /// controller is a no-op (R13: account governs sync).
  Future<void> sync() async {
    final bool signedIn = ref.read(accountControllerProvider) is SignedIn;
    if (!signedIn) {
      state = const SyncIdle();
      return;
    }

    if (!await _connectivity.isOnline()) {
      state = const SyncOffline();
      return;
    }

    state = const Syncing();
    try {
      await _pullAndApply();
      await _pushLocal();
      _watermark = DateTime.now().toUtc();
      state = SyncIdle(lastSyncedUtc: _watermark);
    } catch (error) {
      // Leave the local DB consistent; surface a non-blocking error (R12.4).
      state = SyncError(_describe(error));
    }
  }

  /// Pulls remote changes, resolves categories, merges, and applies locally.
  Future<void> _pullAndApply() async {
    final List<RemoteChange> changes = _watermark == null
        ? await _sync.fullReconcile()
        : await _sync.pullRemoteChanges(_watermark);

    // Translate each RemoteChange (category carried by NAME in categoryId) into
    // a pure RemoteDelta whose Wish carries a resolved local categoryId.
    final List<RemoteDelta> deltas = <RemoteDelta>[];
    for (final RemoteChange c in changes) {
      if (c.deletedId != null) {
        deltas.add(RemoteDelta.delete(c.deletedId!, c.updatedAtUtc));
        continue;
      }
      final Wish remote = c.wish!;
      final String categoryName = remote.categoryId; // NAME per adapter note
      final Category category =
          await ref.read(categoryRepositoryProvider).getOrCreateByName(
                categoryName.isEmpty ? 'Uncategorized' : categoryName,
              );
      deltas.add(RemoteDelta.upsert(remote.copyWith(categoryId: category.id)));
    }

    final List<Wish> local = await ref.read(wishRepositoryProvider).getAll();
    final MergeResult result = mergeSync(
      local: local,
      localTombstones: const <LocalTombstone>[],
      remote: deltas,
    );

    // Apply the converged set: upsert winners, delete losers. We compute the
    // new full local set and replace it in one transaction for consistency.
    final Map<String, Wish> byId = <String, Wish>{
      for (final Wish w in local) w.id: w
    };
    for (final Wish w in result.upserts) {
      byId[w.id] = w;
    }
    for (final String id in result.deletions) {
      byId.remove(id);
    }
    await ref.read(wishRepositoryProvider).replaceAll(byId.values.toList());
  }

  /// Pushes local Wishes to the backend, projecting each wish's categoryId to
  /// its category NAME (symmetric with the pull mapping).
  Future<void> _pushLocal() async {
    final List<Wish> local = await ref.read(wishRepositoryProvider).getAll();
    final List<Category> categories =
        await ref.read(categoryRepositoryProvider).getAll();
    final Map<String, String> nameById = <String, String>{
      for (final Category c in categories) c.id: c.name,
    };
    final List<Wish> projected = <Wish>[
      for (final Wish w in local)
        w.copyWith(categoryId: nameById[w.categoryId] ?? w.categoryId),
    ];
    await _sync.pushLocalChanges(projected, const <String>[]);
  }

  String _describe(Object error) =>
      'Sync could not complete. Your changes are saved locally and will sync '
      'later.';
}
