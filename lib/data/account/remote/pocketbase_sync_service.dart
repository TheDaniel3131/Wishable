/// [PocketbaseSyncService] — the PocketBase [SyncService] adapter (auth spec,
/// Option B — R12).
///
/// The ONLY sync file that imports the `pocketbase` SDK. Maps the local [Wish]
/// domain model to/from a user-scoped `wishes` collection and implements
/// push/pull/reconcile. Conflict resolution (last-write-wins by `updatedAtUtc`,
/// tombstone for delete-vs-edit) is applied by the application-layer
/// `SyncController`; this adapter is the transport, translating records and
/// talking to the backend.
///
/// Record shape (one `wishes` record per Wish). These are app-defined text
/// fields, deliberately named distinctly from PocketBase's own auto
/// `created`/`updated` system fields so they never collide:
///   wishId (text, the stable UUID — the sync identity, R12.5), title,
///   description, categoryName, priority, status, progress, wishCreatedAt,
///   wishUpdatedAt, wishDeletedAt (nullable tombstone), owner (relation to the
///   auth user; collection API rules scope reads/writes to the owner).
///
/// We use our OWN `wishUpdatedAt` (the device edit time) for last-write-wins
/// rather than PocketBase's server-managed `updated`, because conflict
/// resolution must compare when the user edited on each device, not when the
/// server received the write.
library wishable.data.account.remote.pocketbase_sync_service;

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../../domain/lifecycle_status.dart';
import '../../../domain/priority.dart';
import '../../../domain/wish.dart';
import '../../../domain/wish_image.dart';
import '../sync_service.dart';

/// PocketBase-backed sync transport over a `wishes` collection and a
/// `wish_images` collection (one record per image, with a PocketBase `file`
/// field holding the image bytes — Option A file storage).
final class PocketbaseSyncService implements SyncService {
  PocketbaseSyncService(
    this._pb, {
    String collection = 'wishes',
    String imageCollection = 'wish_images',
  })  : _collection = collection,
        _imageCollection = imageCollection;

  final PocketBase _pb;
  final String _collection;
  final String _imageCollection;

  /// The signed-in user's id, used as the `owner` relation and to scope reads.
  String get _ownerId => _pb.authStore.record?.id ?? '';

  @override
  Future<void> pushLocalChanges(
    List<Wish> wishes,
    List<String> deletedIds,
  ) async {
    // Upserts: find an existing record for the wishId, update it or create it.
    for (final Wish wish in wishes) {
      final Map<String, dynamic> body = _toBody(wish);
      final RecordModel? existing = await _findByWishId(wish.id);
      if (existing == null) {
        await _pb.collection(_collection).create(body: body);
      } else {
        await _pb.collection(_collection).update(existing.id, body: body);
      }
    }
    // Deletes: mark the remote record as tombstoned (soft delete) so other
    // devices learn of the delete via a normal pull (R12.2). We do not hard-
    // delete remotely, so a concurrent edit elsewhere can still win by
    // updatedAtUtc.
    for (final String wishId in deletedIds) {
      final RecordModel? existing = await _findByWishId(wishId);
      if (existing != null) {
        await _pb.collection(_collection).update(
          existing.id,
          body: <String, dynamic>{
            'wishDeletedAt': DateTime.now().toUtc().toIso8601String(),
            'wishUpdatedAt': DateTime.now().toUtc().toIso8601String(),
          },
        );
      }
    }
  }

  @override
  Future<List<RemoteChange>> pullRemoteChanges(DateTime? since) async {
    final String ownerFilter = "owner = '$_ownerId'";
    final String filter = since == null
        ? ownerFilter
        : "$ownerFilter && wishUpdatedAt >= '${since.toUtc().toIso8601String()}'";
    final List<RecordModel> records =
        await _pb.collection(_collection).getFullList(
              filter: filter,
              sort: 'wishUpdatedAt',
            );
    return records.map(_toChange).toList(growable: false);
  }

  @override
  Future<List<RemoteChange>> fullReconcile() async {
    final List<RecordModel> records =
        await _pb.collection(_collection).getFullList(
              filter: "owner = '$_ownerId'",
              sort: 'wishUpdatedAt',
            );
    return records.map(_toChange).toList(growable: false);
  }

  // --- Images (Option A: PocketBase file storage) --------------------------
  //
  // One `wish_images` record per image. Fields: owner (relation to user),
  // imageId (stable UUID = sync identity), wishId (which Wish it belongs to),
  // mimeType, position, imgCreatedAt (datetime), imgDeletedAt (nullable
  // tombstone), and `file` (PocketBase file field holding the bytes).

  @override
  Future<void> pushLocalImages(
    List<LocalImageUpload> uploads,
    List<String> deletedIds,
  ) async {
    for (final LocalImageUpload up in uploads) {
      // Only create if the image is not already on the server (uploads are
      // immutable; an image's bytes never change after creation).
      final RecordModel? existing = await _findImageByImageId(up.id);
      if (existing != null) {
        continue;
      }
      await _pb.collection(_imageCollection).create(
        body: <String, dynamic>{
          'owner': _ownerId,
          'imageId': up.id,
          'wishId': up.wishId,
          'mimeType': up.mimeType,
          'position': up.position,
          'imgCreatedAt': up.createdAtUtc.toUtc().toIso8601String(),
        },
        files: <http.MultipartFile>[
          http.MultipartFile.fromBytes(
            'file',
            up.bytes,
            filename: '${up.id}${_extensionFor(up.mimeType)}',
          ),
        ],
      );
    }
    // Tombstone remote images for local deletes so other devices learn of them.
    for (final String imageId in deletedIds) {
      final RecordModel? existing = await _findImageByImageId(imageId);
      if (existing != null) {
        await _pb.collection(_imageCollection).update(
          existing.id,
          body: <String, dynamic>{
            'imgDeletedAt': DateTime.now().toUtc().toIso8601String(),
          },
        );
      }
    }
  }

  @override
  Future<List<RemoteImageChange>> pullRemoteImages(DateTime? since) async {
    final String ownerFilter = "owner = '$_ownerId'";
    final String filter = since == null
        ? ownerFilter
        : "$ownerFilter && imgCreatedAt >= '${since.toUtc().toIso8601String()}'";
    final List<RecordModel> records =
        await _pb.collection(_imageCollection).getFullList(filter: filter);

    final List<RemoteImageChange> changes = <RemoteImageChange>[];
    for (final RecordModel record in records) {
      final Map<String, dynamic> d = record.toJson();
      final String imageId = _asString(d['imageId']) ?? '';
      final String? deleted = _asString(d['imgDeletedAt']);
      if (deleted != null && deleted.isNotEmpty) {
        changes.add(RemoteImageChange.delete(imageId));
        continue;
      }
      final String fileName = _asString(d['file']) ?? '';
      if (fileName.isEmpty) {
        continue;
      }
      // Download the file bytes so they can be cached locally.
      final Uri url = _pb.files.getUrl(record, fileName);
      final http.Response resp = await http.get(url);
      if (resp.statusCode != 200) {
        continue; // skip this image; a later sync retries
      }
      changes.add(RemoteImageChange.upsert(
        WishImage(
          id: imageId,
          wishId: _asString(d['wishId']) ?? '',
          bytes: resp.bodyBytes,
          mimeType: _asString(d['mimeType']) ?? 'image/jpeg',
          position: (d['position'] as num?)?.toInt() ?? 0,
          createdAtUtc:
              _parseDateTime(d['imgCreatedAt']) ?? DateTime.now().toUtc(),
          remoteName: fileName,
        ),
      ));
    }
    return changes;
  }

  Future<RecordModel?> _findImageByImageId(String imageId) async {
    final List<RecordModel> found =
        await _pb.collection(_imageCollection).getFullList(
              filter: "owner = '$_ownerId' && imageId = '$imageId'",
            );
    return found.isEmpty ? null : found.first;
  }

  static String _extensionFor(String mimeType) {
    switch (mimeType) {
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      case 'image/heic':
        return '.heic';
      default:
        return '.jpg';
    }
  }

  // --- Mapping -------------------------------------------------------------

  Future<RecordModel?> _findByWishId(String wishId) async {
    final List<RecordModel> found =
        await _pb.collection(_collection).getFullList(
              filter: "owner = '$_ownerId' && wishId = '$wishId'",
              sort: '-wishUpdatedAt',
            );
    return found.isEmpty ? null : found.first;
  }

  // NOTE on category: the remote stores the category by NAME (so a fresh
  // device can recreate it), but the local [Wish] carries a `categoryId` UUID.
  // The application-layer SyncController performs the id<->name mapping and
  // hands this adapter [Wish] objects whose `categoryId` slot carries the
  // category NAME on push; on pull, [_toChange] likewise returns the NAME in
  // the `categoryId` slot for the controller to resolve. This mirrors how the
  // BackupService projects categories by name.
  Map<String, dynamic> _toBody(Wish wish) => <String, dynamic>{
        'owner': _ownerId,
        'wishId': wish.id,
        'title': wish.title,
        'description': wish.description ?? '',
        'categoryName': wish.categoryId, // carries the NAME (see note above)
        'priority': _priorityToken(wish.priority),
        'status': _statusToken(wish.status),
        'progress': wish.progress,
        'wishCreatedAt': wish.createdAtUtc.toUtc().toIso8601String(),
        'wishUpdatedAt': wish.updatedAtUtc.toUtc().toIso8601String(),
        'wishDeletedAt': null,
      };

  RemoteChange _toChange(RecordModel record) {
    final Map<String, dynamic> d = record.toJson();
    final DateTime? deleted = _parseDateTime(d['wishDeletedAt']);
    final DateTime updatedAt =
        _parseDateTime(d['wishUpdatedAt']) ?? DateTime.now().toUtc();
    final String wishId = _asString(d['wishId']) ?? '';
    if (deleted != null) {
      return RemoteChange.delete(wishId, updatedAt);
    }
    return RemoteChange.upsert(
      Wish(
        id: wishId,
        title: _asString(d['title']) ?? '',
        description: () {
          final String? desc = _asString(d['description']);
          return (desc == null || desc.isEmpty) ? null : desc;
        }(),
        // The remote stores the category by name; the SyncController resolves
        // it to a local categoryId (get-or-create) before persisting. We pass
        // the name through the categoryId slot and let the controller map it.
        categoryId: _asString(d['categoryName']) ?? '',
        priority: _priorityFromToken(_asString(d['priority'])),
        status: _statusFromToken(_asString(d['status'])),
        progress: (d['progress'] as num?)?.toInt() ?? 0,
        createdAtUtc: _parseDateTime(d['wishCreatedAt']) ?? updatedAt,
        updatedAtUtc: updatedAt,
      ),
    );
  }

  static String? _asString(Object? v) => v?.toString();

  /// Parses a PocketBase Datetime/Plain-text timestamp into a UTC [DateTime],
  /// or null when empty/unset. PocketBase Datetime fields serialize as
  /// `yyyy-MM-dd HH:mm:ss.SSSZ` (space-separated); the app writes ISO-8601
  /// (`T`-separated). [DateTime.parse] accepts the `T` form directly, so we
  /// normalize the space form to `T` first and treat an empty value as null
  /// (an unset nullable tombstone).
  static DateTime? _parseDateTime(Object? raw) {
    final String? s = _asString(raw);
    if (s == null || s.isEmpty) {
      return null;
    }
    final String normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized)?.toUtc();
  }

  // --- Enum <-> PocketBase wire tokens -------------------------------------
  //
  // The PocketBase `priority` / `status` Select options use these exact string
  // values. Status in particular uses "in progress" (with a space) on the
  // backend, which differs from the Dart enum name `inProgress`, so the mapping
  // is explicit rather than relying on `.name`.

  static String _priorityToken(Priority p) => switch (p) {
        Priority.low => 'low',
        Priority.medium => 'medium',
        Priority.high => 'high',
      };

  static Priority _priorityFromToken(String? token) => switch (token) {
        'low' => Priority.low,
        'high' => Priority.high,
        _ => Priority.medium, // default + unknown
      };

  static String _statusToken(LifecycleStatus s) => switch (s) {
        LifecycleStatus.active => 'active',
        LifecycleStatus.inProgress => 'in progress',
        LifecycleStatus.completed => 'completed',
      };

  static LifecycleStatus _statusFromToken(String? token) => switch (token) {
        'in progress' => LifecycleStatus.inProgress,
        // Tolerate the legacy camelCase form in case older records exist.
        'inProgress' => LifecycleStatus.inProgress,
        'completed' => LifecycleStatus.completed,
        _ => LifecycleStatus.active, // default + unknown
      };
}
