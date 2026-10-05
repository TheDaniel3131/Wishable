/// Drift table definitions for the Wishable local database.
///
/// This file lives in the data-access layer — the ONLY layer permitted to
/// reference Drift types (design R14.3). The schema mirrors the "Drift schema"
/// section of the design document.
library wishable.data.tables;

import 'package:drift/drift.dart';

import '../domain/lifecycle_status.dart';
import '../domain/priority.dart';

/// Persisted Wishes.
///
/// Columns map one-to-one to the domain `Wish` value object. The UUID string
/// `id` is the stable primary key (R14.1); `priority` and `status` are stored
/// as their enum index via `intEnum`; `progress` carries a 0–100 CHECK
/// constraint as a defense-in-depth backstop to domain validation (R5.2); and
/// both timestamps are stored in UTC (R1.5, R2.4, R14.2).
@DataClassName('WishRow')
class Wishes extends Table {
  TextColumn get id => text()(); // UUID PK (R14.1)
  TextColumn get title => text().withLength(min: 1)(); // R1.2
  TextColumn get description => text().nullable()(); // R1.3
  TextColumn get categoryId => text().customConstraint(
        'NOT NULL REFERENCES categories(id)',
      )(); // FK -> Category (R3.1)
  IntColumn get priority => intEnum<Priority>()(); // R4
  IntColumn get status => intEnum<LifecycleStatus>()(); // R6
  IntColumn get progress => integer().customConstraint(
      'NOT NULL CHECK (progress BETWEEN 0 AND 100)')(); // CHECK 0..100 (R5)
  DateTimeColumn get createdAtUtc => dateTime()(); // R1.5, R14.2
  DateTimeColumn get updatedAtUtc => dateTime()(); // R2.4, R14.2

  /// Soft-delete tombstone marker (auth spec Option B, R12.2). Null for a live
  /// Wish; set to the UTC delete time when the Wish is deleted, so sync can
  /// resolve a delete-vs-edit conflict by last-write-wins against
  /// [updatedAtUtc]. Added in schema v2; local reads filter these out.
  DateTimeColumn get deletedAtUtc => dateTime().nullable()();

  /// Stable, monotonically increasing display number ("Wish #N"). Assigned once
  /// at creation as `max(seq) + 1` and never changed, so it survives reordering
  /// and filtering (unlike a list position). Nullable only to support the v2->v3
  /// migration backfill; every row created by the app carries a value. Added in
  /// schema v3.
  IntColumn get seq => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Categories a Wish can belong to.
///
/// Names are unique (R3.3) so get-or-create can be idempotent. The five preset
/// categories (Learn, Travel, Buy, Save, Achieve) are seeded in the database
/// migration `onCreate` with `isPreset == true` (R3.2).
@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()(); // UUID PK
  TextColumn get name => text().unique()(); // R3.3
  BoolColumn get isPreset =>
      boolean().withDefault(const Constant(false))(); // R3.2

  @override
  Set<Column> get primaryKey => {id};
}

/// Simple key/value application settings (R10.1).
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()(); // R10.1

  @override
  Set<Column> get primaryKey => {key};
}
