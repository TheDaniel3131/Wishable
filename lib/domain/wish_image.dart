/// The [WishImage] domain value object — an image attached to a [Wish].
///
/// Images are cached locally as raw bytes (so they render offline and on every
/// platform including web, with no `dart:io`/path_provider dependency) and sync
/// to PocketBase file storage when an account is signed in. A Wish may have
/// zero or more images, ordered by [position].
///
/// Pure Dart: no Flutter, Drift, or dart:io dependencies. Compared by value
/// (the [bytes] are compared by identity via length + reference to stay cheap;
/// callers treat a [WishImage] as immutable).
library wishable.domain.wish_image;

import 'dart:typed_data';

/// An image attached to a Wish.
final class WishImage {
  const WishImage({
    required this.id,
    required this.wishId,
    required this.bytes,
    required this.mimeType,
    required this.position,
    required this.createdAtUtc,
    this.remoteName,
  });

  /// Stable UUID identifying this image (sync identity).
  final String id;

  /// The owning [Wish]'s id.
  final String wishId;

  /// The raw image bytes (the local cache; renders offline on all platforms).
  final Uint8List bytes;

  /// MIME type, e.g. `image/jpeg` or `image/png`.
  final String mimeType;

  /// Display order within the owning Wish (ascending).
  final int position;

  /// Creation time (UTC).
  final DateTime createdAtUtc;

  /// The PocketBase stored filename once uploaded, or `null` if this image has
  /// not yet been pushed to the backend (offline-created, pending sync).
  final String? remoteName;

  WishImage copyWith({
    String? id,
    String? wishId,
    Uint8List? bytes,
    String? mimeType,
    int? position,
    DateTime? createdAtUtc,
    Object? remoteName = _unset,
  }) {
    return WishImage(
      id: id ?? this.id,
      wishId: wishId ?? this.wishId,
      bytes: bytes ?? this.bytes,
      mimeType: mimeType ?? this.mimeType,
      position: position ?? this.position,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      remoteName:
          identical(remoteName, _unset) ? this.remoteName : remoteName as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WishImage &&
          other.id == id &&
          other.wishId == wishId &&
          other.mimeType == mimeType &&
          other.position == position &&
          other.createdAtUtc == createdAtUtc &&
          other.remoteName == remoteName &&
          other.bytes.length == bytes.length;

  @override
  int get hashCode => Object.hash(
        id,
        wishId,
        mimeType,
        position,
        createdAtUtc,
        remoteName,
        bytes.length,
      );

  @override
  String toString() => 'WishImage(id: $id, wishId: $wishId, '
      'mimeType: $mimeType, position: $position, bytes: ${bytes.length}B, '
      'remoteName: $remoteName)';
}

const Object _unset = Object();
