/// The Drift-backed [WishImageRepository] implementation.
///
/// Lives in the data-access layer — the only layer permitted to reference
/// Drift types (R14.3) — and keeps a private row<->domain mapper so no Drift
/// type leaks across the interface. Images are stored as blobs in the
/// `WishImages` table so they are cached locally and render on every platform
/// (including web) with no `dart:io`/path_provider dependency.
library wishable.data.repositories.drift_wish_image_repository;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/wish_image.dart';
import '../app_database.dart';
import 'wish_image_repository.dart';

/// Drift-backed implementation of [WishImageRepository].
class DriftWishImageRepository implements WishImageRepository {
  DriftWishImageRepository(this._db, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  @override
  Future<WishImage> add(
    String wishId,
    Uint8List bytes,
    String mimeType, {
    String? id,
    String? remoteName,
  }) async {
    return _db.transaction(() async {
      final int nextPos = await _nextPosition(wishId);
      final WishImageRow row = WishImageRow(
        id: id ?? _uuid.v4(),
        wishId: wishId,
        bytes: bytes,
        mimeType: mimeType,
        position: nextPos,
        createdAtUtc: DateTime.now().toUtc(),
        remoteName: remoteName,
      );
      await _db.into(_db.wishImages).insert(row);
      return _toDomain(row);
    });
  }

  @override
  Future<void> remove(String id) async {
    await (_db.delete(_db.wishImages)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<List<WishImage>> getForWish(String wishId) async {
    final List<WishImageRow> rows = await (_db.select(_db.wishImages)
          ..where((t) => t.wishId.equals(wishId) & t.deletedAtUtc.isNull())
          ..orderBy(<OrderingTerm Function($WishImagesTable)>[
            (t) => OrderingTerm(expression: t.position),
          ]))
        .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Stream<List<WishImage>> watchForWish(String wishId) {
    return (_db.select(_db.wishImages)
          ..where((t) => t.wishId.equals(wishId) & t.deletedAtUtc.isNull())
          ..orderBy(<OrderingTerm Function($WishImagesTable)>[
            (t) => OrderingTerm(expression: t.position),
          ]))
        .watch()
        .map((List<WishImageRow> rows) =>
            rows.map(_toDomain).toList(growable: false));
  }

  @override
  Stream<WishImage?> watchCover(String wishId) {
    return (_db.select(_db.wishImages)
          ..where((t) => t.wishId.equals(wishId) & t.deletedAtUtc.isNull())
          ..orderBy(<OrderingTerm Function($WishImagesTable)>[
            (t) => OrderingTerm(expression: t.position),
          ])
          ..limit(1))
        .watch()
        .map((List<WishImageRow> rows) =>
            rows.isEmpty ? null : _toDomain(rows.first));
  }

  @override
  Future<List<WishImage>> getAll() async {
    final List<WishImageRow> rows = await (_db.select(_db.wishImages)
          ..where((t) => t.deletedAtUtc.isNull()))
        .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  /// The next display position for [wishId]: `max(position) + 1`, or 0 when the
  /// Wish has no images yet.
  Future<int> _nextPosition(String wishId) async {
    final Expression<int> maxPos = _db.wishImages.position.max();
    final query = _db.selectOnly(_db.wishImages)
      ..addColumns(<Expression<Object>>[maxPos])
      ..where(_db.wishImages.wishId.equals(wishId) &
          _db.wishImages.deletedAtUtc.isNull());
    final int? currentMax = (await query.getSingleOrNull())?.read(maxPos);
    return (currentMax ?? -1) + 1;
  }

  WishImage _toDomain(WishImageRow row) {
    return WishImage(
      id: row.id,
      wishId: row.wishId,
      bytes: Uint8List.fromList(row.bytes),
      mimeType: row.mimeType,
      position: row.position,
      createdAtUtc: row.createdAtUtc.toUtc(),
      remoteName: row.remoteName,
    );
  }
}
