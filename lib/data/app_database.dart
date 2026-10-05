/// The Drift [AppDatabase] for Wishable.
///
/// This file lives in the data-access layer — the ONLY layer permitted to
/// reference Drift types (design R14.3). It wires the table definitions into a
/// generated database and seeds the five preset categories on first creation
/// (R3.2).
library wishable.data.app_database;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/lifecycle_status.dart';
import '../domain/priority.dart';
import 'connection/connection.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The names of the five preset categories seeded on database creation (R3.2).
const List<String> kPresetCategoryNames = <String>[
  'Learn',
  'Travel',
  'Buy',
  'Save',
  'Achieve',
];

@DriftDatabase(tables: [Wishes, Categories, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  /// Constructs a database over an existing [executor]. Used by tests to run
  /// against an in-memory database (`NativeDatabase.memory()`).
  AppDatabase.forExecutor(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedPresetCategories();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // v1 -> v2: add the nullable soft-delete tombstone column used by
          // Option B sync (R12.2). Append-only and backward-compatible —
          // existing rows get a NULL deletedAtUtc (i.e. "live"), so no data is
          // lost or altered.
          if (from < 2) {
            await m.addColumn(wishes, wishes.deletedAtUtc);
          }
          if (from < 3) {
            // v2 -> v3: add the stable display-number column and backfill
            // existing rows in creation order so older Wishes get lower
            // numbers. Append-only and data-preserving.
            await m.addColumn(wishes, wishes.seq);
            await _backfillSeq();
          }
        },
        beforeOpen: (details) async {
          // Enforce foreign-key constraints (off by default in SQLite).
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Backfills the `seq` display number for rows created before schema v3,
  /// numbering them 1..N in creation order (ties broken by id for determinism).
  /// Uses SQLite's ROW_NUMBER() window function in a single UPDATE.
  Future<void> _backfillSeq() async {
    await customStatement('''
      UPDATE wishes
      SET seq = sub.rn
      FROM (
        SELECT id, ROW_NUMBER() OVER (ORDER BY created_at_utc, id) AS rn
        FROM wishes
      ) AS sub
      WHERE wishes.id = sub.id AND wishes.seq IS NULL
    ''');
  }

  /// Inserts exactly the five preset categories (R3.2). A fixed UUID namespace
  /// keeps the generated ids stable and deterministic across installs.
  Future<void> _seedPresetCategories() async {
    const Uuid uuid = Uuid();
    const String namespace = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';
    await batch((Batch batch) {
      for (final String name in kPresetCategoryNames) {
        batch.insert(
          categories,
          CategoriesCompanion.insert(
            id: uuid.v5(namespace, name),
            name: name,
            isPreset: const Value(true),
          ),
        );
      }
    });
  }
}
