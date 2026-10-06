/// The [WishImageRepository] abstract interface.
///
/// Drift-free seam for the images attached to a Wish: the application and
/// presentation layers depend only on this interface and the domain
/// [WishImage] type, so no Drift type leaks across the boundary (R14.3).
/// Images are cached locally (as bytes) and surfaced reactively so galleries
/// auto-refresh.
library wishable.data.repositories.wish_image_repository;

import 'dart:typed_data';

import '../../domain/wish_image.dart';

/// Reactive, Drift-free persistence boundary for [WishImage] records.
abstract interface class WishImageRepository {
  /// Adds an image (from raw [bytes]) to the Wish identified by [wishId],
  /// appended after any existing images, and returns the created [WishImage].
  ///
  /// [id] lets a caller preserve an existing identity (e.g. an image pulled
  /// from the backend during sync, so it is not duplicated on the next cycle);
  /// when omitted a fresh UUID is assigned.
  Future<WishImage> add(
    String wishId,
    Uint8List bytes,
    String mimeType, {
    String? id,
    String? remoteName,
  });

  /// Removes the image identified by [id].
  Future<void> remove(String id);

  /// Returns all (non-deleted) images for [wishId], ordered by position.
  Future<List<WishImage>> getForWish(String wishId);

  /// Watches the images for [wishId], emitting on change (ordered by position).
  Stream<List<WishImage>> watchForWish(String wishId);

  /// Watches the first (cover) image for [wishId], or null when none — used by
  /// list rows to show a thumbnail without loading every image.
  Stream<WishImage?> watchCover(String wishId);

  /// A one-shot snapshot of every image across all Wishes (for sync/export).
  Future<List<WishImage>> getAll();
}
