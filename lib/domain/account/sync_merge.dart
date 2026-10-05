/// Pure sync merge logic (auth spec, Option B — R12.2).
///
/// Given the local set of Wishes (plus local tombstones) and the remote changes
/// pulled from the backend, computes the converged set using last-write-wins by
/// `updatedAtUtc`, with a tombstone resolving delete-vs-edit deterministically.
/// Pure Dart and deterministic, so it is unit/property-testable without a
/// backend or database.
library wishable.domain.account.sync_merge;

import '../wish.dart';

/// A local tombstone: a Wish that was deleted locally at [deletedAtUtc].
class LocalTombstone {
  const LocalTombstone(this.wishId, this.deletedAtUtc);
  final String wishId;
  final DateTime deletedAtUtc;
}

/// A remote change expressed in pure-domain terms (no SDK types): either an
/// upsert of [wish] or a delete of [wishId], stamped with [updatedAtUtc].
class RemoteDelta {
  RemoteDelta.upsert(Wish this.wish)
      : wishId = wish.id,
        isDelete = false,
        updatedAtUtc = wish.updatedAtUtc;
  const RemoteDelta.delete(this.wishId, this.updatedAtUtc)
      : wish = null,
        isDelete = true;

  final String wishId;
  final Wish? wish;
  final bool isDelete;
  final DateTime updatedAtUtc;
}

/// The converged result of a merge: the Wishes that should exist locally after
/// the merge, and the set of wish ids that should be removed locally (because a
/// remote delete won).
class MergeResult {
  const MergeResult({required this.upserts, required this.deletions});

  /// Wishes to upsert locally (remote won, or new remote records).
  final List<Wish> upserts;

  /// Wish ids to delete locally (a remote delete won over the local copy).
  final Set<String> deletions;
}

/// Merges [remote] changes into the [local] set, honoring [localTombstones].
///
/// Rules (R12.2), per wish id:
///   - If only one side has it, take that side (upsert local-missing remote;
///     keep local-only until it is pushed).
///   - If both sides changed it, the newer `updatedAtUtc` wins (last-write-
///     wins). On an exact tie, remote wins (deterministic tiebreak).
///   - Delete vs edit: a delete is modeled as a change stamped at its delete
///     time. The side with the newer timestamp wins — a newer delete removes
///     the wish; a newer edit resurrects/keeps it.
///
/// Returns the local upserts and deletions needed to converge. Does not mutate
/// its inputs.
MergeResult mergeSync({
  required List<Wish> local,
  required List<LocalTombstone> localTombstones,
  required List<RemoteDelta> remote,
}) {
  final Map<String, Wish> localById = <String, Wish>{
    for (final Wish w in local) w.id: w,
  };
  final Map<String, DateTime> localDeleteAt = <String, DateTime>{
    for (final LocalTombstone t in localTombstones) t.wishId: t.deletedAtUtc,
  };

  final List<Wish> upserts = <Wish>[];
  final Set<String> deletions = <String>{};

  for (final RemoteDelta delta in remote) {
    final Wish? localWish = localById[delta.wishId];
    final DateTime? localDeletedAt = localDeleteAt[delta.wishId];

    // The local side's effective timestamp for this id: its tombstone time if
    // deleted locally, else its updatedAtUtc, else null (unknown locally).
    final DateTime? localStamp = localDeletedAt ?? localWish?.updatedAtUtc;

    // Remote wins when the local side is unknown or strictly older, or on a
    // tie (deterministic: remote wins ties).
    final bool remoteWins =
        localStamp == null || !delta.updatedAtUtc.isBefore(localStamp);

    if (!remoteWins) {
      // Local is newer; keep local, nothing to apply from this delta.
      continue;
    }

    if (delta.isDelete) {
      // A newer remote delete removes the wish locally (if present).
      if (localWish != null) {
        deletions.add(delta.wishId);
      }
    } else if (delta.wish != null) {
      // A newer remote upsert replaces/creates the local wish.
      upserts.add(delta.wish!);
      // If it was locally tombstoned but the remote edit is newer, the edit
      // resurrects it — ensure it is not also deleted.
      deletions.remove(delta.wishId);
    }
  }

  return MergeResult(upserts: upserts, deletions: deletions);
}
