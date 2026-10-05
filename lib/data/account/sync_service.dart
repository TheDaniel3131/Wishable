/// The [SyncService] abstract interface (auth spec, Option B — R12).
///
/// Backend-agnostic boundary for syncing Wishes between the local Drift
/// database and the remote backend. The application layer's `SyncController`
/// depends on this interface; the concrete PocketBase adapter under
/// `data/account/remote/` is the only SDK importer.
///
/// Sync identity is the Wish UUID (no duplication across devices, R12.5).
/// Conflict resolution is last-write-wins by `updatedAtUtc`, with a tombstone
/// (soft-delete marker, see the Drift migration) resolving delete-vs-edit
/// (R12.2).
library wishable.data.account.sync_service;

import '../../domain/wish.dart';

/// A remote change pulled from the backend: either an upsert of [wish] or a
/// delete marker for [deletedId]. Exactly one is non-null.
final class RemoteChange {
  RemoteChange.upsert(Wish this.wish)
      : deletedId = null,
        updatedAtUtc = wish.updatedAtUtc;
  const RemoteChange.delete(String this.deletedId, this.updatedAtUtc)
      : wish = null;

  /// The upserted Wish, or null for a delete.
  final Wish? wish;

  /// The id of a remotely-deleted Wish, or null for an upsert.
  final String? deletedId;

  /// When the remote change occurred (UTC), used for last-write-wins.
  final DateTime updatedAtUtc;
}

/// Pushes local changes to and pulls remote changes from the backend.
abstract interface class SyncService {
  /// Pushes locally-changed [wishes] (and local deletes, carried as tombstones)
  /// to the backend for the signed-in user (R12.1).
  Future<void> pushLocalChanges(List<Wish> wishes, List<String> deletedIds);

  /// Pulls remote changes updated since [since] (the last successful pull
  /// watermark); null pulls everything (first sync / sign-in again) (R12.1).
  Future<List<RemoteChange>> pullRemoteChanges(DateTime? since);

  /// Full reconcile used on first sign-in / sign-in-again: pulls the complete
  /// remote set and merges by UUID so nothing duplicates (R12.5).
  Future<List<RemoteChange>> fullReconcile();
}
