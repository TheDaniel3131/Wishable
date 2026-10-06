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

import 'dart:typed_data';

import '../../domain/wish.dart';
import '../../domain/wish_image.dart';

/// A remote image change pulled from the backend: either an upsert carrying the
/// downloaded [image] bytes, or a delete marker for [deletedId].
final class RemoteImageChange {
  RemoteImageChange.upsert(WishImage this.image) : deletedId = null;
  const RemoteImageChange.delete(String this.deletedId) : image = null;

  /// The upserted image (with downloaded bytes), or null for a delete.
  final WishImage? image;

  /// The id of a remotely-deleted image, or null for an upsert.
  final String? deletedId;
}

/// A local image to push to the backend. Carries the raw [bytes] plus the
/// identity/metadata needed to create or match the remote record.
final class LocalImageUpload {
  const LocalImageUpload({
    required this.id,
    required this.wishId,
    required this.bytes,
    required this.mimeType,
    required this.position,
    required this.createdAtUtc,
  });

  final String id;
  final String wishId;
  final Uint8List bytes;
  final String mimeType;
  final int position;
  final DateTime createdAtUtc;
}

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

  // --- Images (Option A: PocketBase file storage) --------------------------

  /// Pushes local images to the backend: uploads each in [uploads] whose id is
  /// not yet present remotely (as a multipart file), and tombstones any remote
  /// image in [deletedIds]. Images are stored in PocketBase file storage.
  Future<void> pushLocalImages(
    List<LocalImageUpload> uploads,
    List<String> deletedIds,
  );

  /// Pulls remote image changes for the signed-in user, downloading the file
  /// bytes for upserts so they can be cached locally. [since] limits to images
  /// changed after the watermark; null pulls everything.
  Future<List<RemoteImageChange>> pullRemoteImages(DateTime? since);
}
