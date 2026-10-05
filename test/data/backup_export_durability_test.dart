// Feature: wishable, Task 9.5: Database export durability integration test
//
// Integration test for task 9.5.
//
// **Validates: Requirements 11.1, 10.4**
//
// Exercises the full raw-database export path of [DriftBackupService]:
//   1. Open a FILE-backed [AppDatabase] (the export copies the raw SQLite
//      file and rejects in-memory databases via `PRAGMA database_list`, so a
//      file-backed source is required here).
//   2. Seed a handful of wishes across categories (via [DriftWishRepository] +
//      [DriftCategoryRepository]) and a non-default setting (via
//      [DriftSettingsRepository]).
//   3. Call `exportDatabase(ExportTarget(format: BackupFormat.database))`,
//      which snapshots, checkpoints the WAL, and copies the file into place
//      (R11.1).
//   4. Open a BRAND-NEW [AppDatabase] over the exported copy and assert the
//      wishes match the originals field-for-field (to second resolution for
//      timestamps) and the loaded [AppSettings] match (R10.4) — proving the
//      exported file is a durable, fully equivalent copy of the live database.
//
// This touches real Drift native I/O and the filesystem, so it runs under
// `flutter_test`. All temp files/dirs are removed in a `finally`.
library wishable.test.data.backup_export_durability_test;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:wishable/data/app_database.dart';
import 'package:wishable/data/repositories/drift_backup_service.dart';
import 'package:wishable/data/repositories/drift_category_repository.dart';
import 'package:wishable/data/repositories/drift_settings_repository.dart';
import 'package:wishable/data/repositories/drift_wish_repository.dart';
import 'package:wishable/domain/app_settings.dart';
import 'package:wishable/domain/backup.dart';
import 'package:wishable/domain/category.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish.dart';
import 'package:wishable/domain/wish_input.dart';

void main() {
  // Required because the test touches the Flutter/Drift native bindings.
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'exportDatabase writes a durable copy whose wishes and settings match '
    'the live database field-for-field (R11.1, R10.4)',
    () async {
      final Directory tempDir =
          await Directory.systemTemp.createTemp('wishable_export_');
      final File sourceFile =
          File(p.join(tempDir.path, 'wishable_source.sqlite'));
      final File copyFile =
          File(p.join(tempDir.path, 'wishable_export.sqlite'));

      try {
        // --- Seed the live, file-backed database -------------------------
        final AppDatabase sourceDb =
            AppDatabase.forExecutor(NativeDatabase(sourceFile));
        List<Wish> originals;
        const AppSettings savedSettings =
            AppSettings(themePreference: ThemePreference.dark);
        try {
          final wishes = DriftWishRepository(sourceDb);
          final categories = DriftCategoryRepository(sourceDb);
          final settings = DriftSettingsRepository(sourceDb);
          final service = DriftBackupService(
            sourceDb,
            wishRepository: wishes,
            categoryRepository: categories,
          );

          // A varied, deterministic batch of wishes across a few categories
          // (covering optional description incl. null, and every priority).
          final created = <Wish>[];
          final specs = _seedSpecs();
          for (final spec in specs) {
            final Category category =
                await categories.getOrCreateByName(spec.categoryName);
            created.add(await wishes.create(WishDraft(
              title: spec.title,
              description: spec.description,
              categoryId: category.id,
              priority: spec.priority,
            )));
          }
          originals = created;

          // A non-default setting so the round-trip proves settings survive
          // (defaults would round-trip trivially).
          await settings.save(savedSettings);

          // --- Export the raw database file (R11.1) ----------------------
          final ExportResult result = await service.exportDatabase(
            ExportTarget(
              path: copyFile.path,
              format: BackupFormat.database,
            ),
          );

          expect(result.format, BackupFormat.database);
          expect(result.wishCount, originals.length);
          expect(await copyFile.exists(), isTrue,
              reason: 'the export copy must be written to the target path');
          expect(result.byteCount, greaterThan(0));
        } finally {
          await sourceDb.close();
        }

        // --- Open the exported copy and verify equivalence (R10.4) --------
        final AppDatabase copyDb =
            AppDatabase.forExecutor(NativeDatabase(copyFile));
        try {
          final copyWishes = DriftWishRepository(copyDb);
          final copySettings = DriftSettingsRepository(copyDb);

          // Wishes match the originals field-for-field, order-independent.
          final List<Wish> reloaded = await copyWishes.getAll();
          expect(reloaded, hasLength(originals.length),
              reason: 'the export must capture every wish');
          final Map<String, Wish> byId = <String, Wish>{
            for (final w in reloaded) w.id: w,
          };
          for (final original in originals) {
            final Wish? survivor = byId[original.id];
            expect(survivor, isNotNull,
                reason: 'wish ${original.id} must be present in the export');
            _expectWishesEquivalent(actual: survivor!, reference: original);
          }

          // Settings match the non-default value that was saved.
          final AppSettings reloadedSettings = await copySettings.load();
          expect(reloadedSettings, equals(savedSettings),
              reason: 'the exported copy must preserve persisted settings');
        } finally {
          await copyDb.close();
        }
      } finally {
        // Clean up all temp files/dirs regardless of outcome.
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    },
  );
}

// --- Equivalence assertion --------------------------------------------------

/// Asserts the exported [actual] wish matches the original [reference] on
/// every domain field. Timestamps are compared at second resolution because
/// Drift's `dateTime()` column stores whole Unix seconds; the stored instants
/// must remain in UTC (R14.2).
void _expectWishesEquivalent({required Wish actual, required Wish reference}) {
  expect(actual.id, reference.id, reason: 'id');
  expect(actual.title, reference.title, reason: 'title');
  expect(actual.description, reference.description, reason: 'description');
  expect(actual.categoryId, reference.categoryId, reason: 'categoryId');
  expect(actual.priority, reference.priority, reason: 'priority');
  expect(actual.status, reference.status, reason: 'status');
  expect(actual.progress, reference.progress, reason: 'progress');

  expect(actual.createdAtUtc.isUtc, isTrue, reason: 'createdAt stays UTC');
  expect(actual.updatedAtUtc.isUtc, isTrue, reason: 'updatedAt stays UTC');
  expect(actual.createdAtUtc, _truncateToSeconds(reference.createdAtUtc),
      reason: 'createdAt matches to the second');
  expect(actual.updatedAtUtc, _truncateToSeconds(reference.updatedAtUtc),
      reason: 'updatedAt matches to the second');
}

/// Truncates [t] to whole seconds in UTC — the resolution the Drift
/// `dateTime()` column stores.
DateTime _truncateToSeconds(DateTime t) {
  final utc = t.toUtc();
  return DateTime.fromMillisecondsSinceEpoch(
    (utc.millisecondsSinceEpoch ~/ 1000) * 1000,
    isUtc: true,
  );
}

// --- Seed data --------------------------------------------------------------

/// A fixed, varied batch of wishes to seed: distinct categories, every
/// priority, and a mix of present/absent descriptions.
class _SeedSpec {
  const _SeedSpec({
    required this.title,
    required this.description,
    required this.categoryName,
    required this.priority,
  });

  final String title;
  final String? description;
  final String categoryName;
  final Priority? priority;
}

List<_SeedSpec> _seedSpecs() => const <_SeedSpec>[
      _SeedSpec(
        title: 'Learn Dart',
        description: 'Finish the language tour',
        categoryName: 'Learn',
        priority: Priority.high,
      ),
      _SeedSpec(
        title: 'Trip to Kyoto',
        description: null,
        categoryName: 'Travel',
        priority: Priority.medium,
      ),
      _SeedSpec(
        title: 'New headphones',
        description: 'Noise cancelling, with "quotes" & symbols 😀',
        categoryName: 'Buy',
        priority: Priority.low,
      ),
      _SeedSpec(
        title: 'Emergency fund',
        description: '',
        categoryName: 'Save',
        priority: null, // exercises the Medium default (R1.4)
      ),
      _SeedSpec(
        title: 'Run a marathon',
        description: 'Train over 16 weeks',
        categoryName: 'Achieve',
        priority: Priority.high,
      ),
    ];
