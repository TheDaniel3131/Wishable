/// The Drift-backed [WishRepository] implementation (design "Data-Access
/// Layer (repositories)", task 8.2).
///
/// This class is the sole bridge between the Drift [AppDatabase] and the
/// domain [Wish] value object. It lives in the data-access layer — the only
/// layer permitted to reference Drift types (R14.3) — and keeps a private
/// row<->domain mapper so no Drift type (`WishRow`, companions) ever leaks
/// across the interface boundary.
///
/// Responsibilities:
///   - create/update/delete/getById CRUD over the `Wishes` table.
///   - reactive [watchAll]/[watchByStatus]/[watchByCategory] streams backed by
///     Drift's reactive queries so list views auto-refresh (R9).
///   - [applyProgress] and [transition] routed through [LifecyclePolicy.apply],
///     so every lifecycle mutation obeys the same invariants (R5, R6).
///   - [getAll]/[replaceAll] giving the `BackupService` a Drift-free snapshot
///     and an all-or-nothing restore inside a single transaction (R11, R12.1).
///
/// Identity and time are owned here: [create] assigns a UUID id (R14.1) and UTC
/// timestamps (R1.5), [update] preserves the id and refreshes `updatedAtUtc`
/// (R2.4, R14.2).
library wishable.data.repositories.drift_wish_repository;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/ids.dart';
import '../../domain/lifecycle_event.dart';
import '../../domain/lifecycle_policy.dart';
import '../../domain/lifecycle_status.dart';
import '../../domain/priority.dart';
import '../../domain/wish.dart';
import '../../domain/wish_input.dart';
import '../app_database.dart';
import 'wish_repository.dart';

/// Thrown when an operation targets a [Wish] id that is not present in the
/// database. Keeping it a plain [StateError] subtype means callers above the
/// data layer never need to know about Drift.
class WishNotFoundError extends StateError {
  WishNotFoundError(WishId id) : super('No Wish exists with id "$id".');
}

/// Drift-backed implementation of [WishRepository].
class DriftWishRepository implements WishRepository {
  /// Creates a repository over [_db], the application's Drift database.
  DriftWishRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  // --- Create / update / delete / read ------------------------------------

  @override
  Future<Wish> create(WishDraft draft) async {
    // A newly created Wish is always Active with progress 0 (R1.1), carries a
    // freshly minted UUID (R14.1), and records the same UTC instant for both
    // timestamps (R1.5, R14.2). An omitted priority defaults to Medium (R1.4).
    // The stable display number is the next value above the current max,
    // assigned once and never changed so it survives reordering/filtering.
    // Computed and inserted in one transaction so concurrent creates cannot
    // collide on the same seq.
    return _db.transaction(() async {
      final DateTime now = DateTime.now().toUtc();
      final int nextSeq = await _nextSeq();
      final WishRow row = WishRow(
        id: _uuid.v4(),
        title: draft.title,
        description: draft.description,
        categoryId: draft.categoryId,
        priority: draft.priority ?? Priority.medium,
        status: LifecycleStatus.active,
        progress: LifecyclePolicy.minProgress,
        createdAtUtc: now,
        updatedAtUtc: now,
        seq: nextSeq,
      );
      await _db.into(_db.wishes).insert(row);
      return _toDomain(row);
    });
  }

  /// Returns the next display number: `max(seq) + 1`, or 1 for an empty table.
  Future<int> _nextSeq() async {
    final Expression<int> maxSeq = _db.wishes.seq.max();
    final query = _db.selectOnly(_db.wishes)
      ..addColumns(<Expression<Object>>[maxSeq]);
    final int? currentMax = (await query.getSingle()).read(maxSeq);
    return (currentMax ?? 0) + 1;
  }

  @override
  Future<Wish> update(WishId id, WishEdit edit) async {
    // Preserve the id and lifecycle state (status/progress are driven only
    // through applyProgress/transition), refresh updatedAtUtc, and apply the
    // user-editable fields (R2). description is written explicitly so clearing
    // it to null persists (R2.3).
    final WishRow existing = await _requireRow(id);
    final WishRow next = existing.copyWith(
      title: edit.title,
      description: Value<String?>(edit.description),
      categoryId: edit.categoryId,
      priority: edit.priority,
      updatedAtUtc: DateTime.now().toUtc(),
    );
    await _persist(next);
    return _toDomain(next);
  }

  @override
  Future<void> delete(WishId id) async {
    await (_db.delete(_db.wishes)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<Wish?> getById(WishId id) async {
    final WishRow? row = await _rowById(id);
    return row == null ? null : _toDomain(row);
  }

  // --- Reactive streams ----------------------------------------------------

  @override
  Stream<List<Wish>> watchAll() {
    return _db.select(_db.wishes).watch().map(_toDomainList);
  }

  @override
  Stream<List<Wish>> watchByStatus(LifecycleStatus status) {
    return (_db.select(_db.wishes)..where((t) => t.status.equalsValue(status)))
        .watch()
        .map(_toDomainList);
  }

  @override
  Stream<List<Wish>> watchByCategory(CategoryId id) {
    return (_db.select(_db.wishes)..where((t) => t.categoryId.equals(id)))
        .watch()
        .map(_toDomainList);
  }

  // --- Lifecycle mutations (routed through LifecyclePolicy) ----------------

  @override
  Future<Wish> applyProgress(WishId id, int progress) {
    return _applyEvent(id, ProgressChanged(progress));
  }

  @override
  Future<Wish> transition(WishId id, LifecycleEvent event) {
    return _applyEvent(id, event);
  }

  /// Reads the current row, computes the next `(status, progress)` via
  /// [LifecyclePolicy.apply], and persists it with a refreshed `updatedAtUtc`
  /// (R5, R6). A rejected event (e.g. out-of-range progress) yields an
  /// unchanged lifecycle state, so the row is written back identically apart
  /// from the timestamp.
  Future<Wish> _applyEvent(WishId id, LifecycleEvent event) async {
    final WishRow existing = await _requireRow(id);
    final LifecycleState result = LifecyclePolicy.apply(
      existing.status,
      existing.progress,
      event,
    );
    final WishRow next = existing.copyWith(
      status: result.status,
      progress: result.progress,
      updatedAtUtc: DateTime.now().toUtc(),
    );
    await _persist(next);
    return _toDomain(next);
  }

  // --- Snapshot / restore --------------------------------------------------

  @override
  Future<List<Wish>> getAll() async {
    final List<WishRow> rows = await _db.select(_db.wishes).get();
    return _toDomainList(rows);
  }

  @override
  Future<void> replaceAll(List<Wish> wishes) {
    // All-or-nothing: clear the table and insert the replacement set inside a
    // single transaction so a failure mid-restore leaves the data untouched
    // (R12.1).
    return _db.transaction(() async {
      await _db.delete(_db.wishes).go();
      await _db.batch((Batch batch) {
        batch.insertAll(
          _db.wishes,
          wishes.map(_toRow).toList(growable: false),
        );
      });
    });
  }

  // --- Internals -----------------------------------------------------------

  /// Writes [row] back to its existing record by primary key.
  Future<void> _persist(WishRow row) async {
    await (_db.update(_db.wishes)..where((t) => t.id.equals(row.id)))
        .write(row.toCompanion(false));
  }

  Future<WishRow?> _rowById(WishId id) {
    return (_db.select(_db.wishes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Reads the row for [id] or throws [WishNotFoundError] when absent, so
  /// mutations against a missing Wish fail loudly rather than silently
  /// no-op'ing.
  Future<WishRow> _requireRow(WishId id) async {
    final WishRow? row = await _rowById(id);
    if (row == null) {
      throw WishNotFoundError(id);
    }
    return row;
  }

  // --- Row <-> domain mapping (data layer owns the mapping) ----------------

  List<Wish> _toDomainList(List<WishRow> rows) =>
      rows.map(_toDomain).toList(growable: false);

  /// Maps a Drift [WishRow] to the domain [Wish]. Timestamps are normalized to
  /// UTC defensively; the columns are always written in UTC (R14.2).
  Wish _toDomain(WishRow row) {
    return Wish(
      id: row.id,
      title: row.title,
      description: row.description,
      categoryId: row.categoryId,
      priority: row.priority,
      status: row.status,
      progress: row.progress,
      createdAtUtc: row.createdAtUtc.toUtc(),
      updatedAtUtc: row.updatedAtUtc.toUtc(),
      seq: row.seq,
    );
  }

  /// Maps a domain [Wish] back to a Drift [WishRow] for restore (R12.1).
  WishRow _toRow(Wish wish) {
    return WishRow(
      id: wish.id,
      title: wish.title,
      description: wish.description,
      categoryId: wish.categoryId,
      priority: wish.priority,
      status: wish.status,
      progress: wish.progress,
      createdAtUtc: wish.createdAtUtc.toUtc(),
      updatedAtUtc: wish.updatedAtUtc.toUtc(),
      seq: wish.seq,
    );
  }
}
