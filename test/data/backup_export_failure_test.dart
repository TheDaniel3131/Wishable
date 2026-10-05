// Feature: wishable, Property 14: Export failure cleans up and preserves the database
//
// Property-based test for task 9.3.
//
// **Property 14: Export failure cleans up and preserves the database**
// **Validates: Requirements 11.4**
//
// For any set of Wishes, when an export operation fails after it has begun
// writing, [DriftBackupService] must honour the temp-then-move contract's
// failure path (R11.4):
//   1. it throws a descriptive [BackupExportException],
//   2. it leaves NO partial file behind at the designated location — in
//      particular no leftover sibling `<target>.<stamp>.tmp` staging file in
//      the target directory, and
//   3. it leaves the Local_Database unchanged, because an export only ever
//      reads from the database (getAll() before == after).
//
// ## Forcing a failure during the write
//
// The service stages the payload to a sibling temp file `<target>.<stamp>.tmp`
// and then renames it onto `target.path`. To drive the write down its failure
// branch deterministically we make the requested target path an EXISTING
// DIRECTORY. The staging write to the sibling `.tmp` file succeeds, but the
// final `rename()` (and the copy fallback) onto a directory raises a
// [FileSystemException], exercising the cleanup-and-rethrow path for real.
//
// This test exercises real Drift I/O over an in-memory database
// (`NativeDatabase.memory()`) and real `dart:io` filesystem operations, so it
// runs under `flutter_test`.
library wishable.test.data.backup_export_failure_test;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// glados supplies the property runner and its generator extensions on `Any`.
// Its `expect`/`test` clash with flutter_test's, so hide those two and let
// flutter_test provide `test`, `expect`, and the matchers.
import 'package:glados/glados.dart' hide expect, test;
import 'package:path/path.dart' as p;
import 'package:wishable/data/app_database.dart';
import 'package:wishable/data/repositories/backup_service.dart';
import 'package:wishable/data/repositories/drift_backup_service.dart';
import 'package:wishable/data/repositories/drift_category_repository.dart';
import 'package:wishable/data/repositories/drift_wish_repository.dart';
import 'package:wishable/domain/backup.dart';
import 'package:wishable/domain/category.dart';
import 'package:wishable/domain/priority.dart';
import 'package:wishable/domain/wish.dart';
import 'package:wishable/domain/wish_input.dart';

void main() {
  // Required because the test touches the Flutter/Drift native bindings.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---- Property 14: export failure cleans up and preserves the DB --------
  //
  // 100 generated cases (ExploreConfig.numRuns). Each case runs against a
  // fresh in-memory database and its own temporary directory, so cases are
  // fully isolated and leave nothing behind.
  Glados<_ExportCase>(_anyExportCase, ExploreConfig(numRuns: 100)).test(
    'a failing export throws BackupExportException, leaves no partial/temp '
    'file in the target directory, and leaves the database unchanged',
    (testCase) async {
      final AppDatabase db = AppDatabase.forExecutor(NativeDatabase.memory());
      final Directory workDir =
          await Directory.systemTemp.createTemp('wishable_export_fail_');
      try {
        final wishes = DriftWishRepository(db);
        final categories = DriftCategoryRepository(db);

        // --- Populate the database with the generated wishes -------------
        for (final _WishSpec spec in testCase.wishes) {
          final Category category =
              await categories.getOrCreateByName(spec.categoryName);
          await wishes.create(WishDraft(
            title: spec.title,
            description: spec.description,
            categoryId: category.id,
            priority: spec.priority,
          ));
        }

        final service = DriftBackupService(
          db,
          wishRepository: wishes,
          categoryRepository: categories,
        );

        // --- Capture the database snapshot BEFORE the failing export -----
        final List<Wish> before = await wishes.getAll();

        // --- Build a guaranteed-failing target ---------------------------
        //
        // Make the target path an EXISTING DIRECTORY inside workDir. The
        // service's parent-dir create + sibling temp write both succeed, but
        // moving the temp file onto a directory fails, driving the write down
        // its cleanup-and-rethrow branch.
        final Directory targetAsDir =
            Directory(p.join(workDir.path, testCase.targetName));
        await targetAsDir.create(recursive: true);

        final ExportTarget target = ExportTarget(
          path: targetAsDir.path,
          format: testCase.format,
        );

        // Snapshot the target directory's parent contents so we can prove no
        // stray `.tmp` staging file is left behind.
        final Set<String> parentBefore = _listNames(workDir);

        // --- Attempt the export; it MUST fail ----------------------------
        Object? thrown;
        try {
          await _runExport(service, target);
          fail('Export to a directory target was expected to fail but '
              'succeeded for ${testCase.format}.');
        } catch (error) {
          thrown = error;
        }

        // (1) The failure is a descriptive BackupExportException (R11.4).
        expect(thrown, isA<BackupExportException>(),
            reason: 'a failed export must surface a BackupExportException');
        expect((thrown as BackupExportException).message, isNotEmpty,
            reason: 'the exception must carry a human-readable message');

        // (2) No partial export file / temp file remains at the location.
        // The target directory must be untouched (still a directory, still
        // empty — the export never wrote into it), and no sibling
        // `<target>.<stamp>.tmp` staging file may linger in workDir.
        expect(await targetAsDir.exists(), isTrue,
            reason: 'the pre-existing target directory must survive');
        expect(_listNames(targetAsDir), isEmpty,
            reason: 'nothing may be written inside the target location');

        final Set<String> parentAfter = _listNames(workDir);
        expect(parentAfter, equals(parentBefore),
            reason: 'no stray staging file may be left in the target dir');
        final Iterable<String> leftoverTemps =
            parentAfter.where((String name) => name.endsWith('.tmp'));
        expect(leftoverTemps, isEmpty,
            reason: 'no leftover .tmp staging file may remain, found '
                '$leftoverTemps');

        // (3) The database is unchanged — export only ever reads (R11.4).
        final List<Wish> after = await wishes.getAll();
        expect(after.length, before.length,
            reason: 'export must not add or remove any wish');
        expect(_byId(after), equals(_byId(before)),
            reason: 'export must not mutate any wish');
      } finally {
        await db.close();
        if (await workDir.exists()) {
          await workDir.delete(recursive: true);
        }
      }
    },
  );
}

/// Dispatches to the right export entry point for [target]'s format. The
/// database format path fails too (an in-memory database is not file-backed),
/// but JSON/CSV are the formats that exercise the temp-then-move cleanup.
Future<ExportResult> _runExport(BackupService service, ExportTarget target) {
  switch (target.format) {
    case BackupFormat.json:
      return service.exportJson(target);
    case BackupFormat.csv:
      return service.exportCsv(target);
    case BackupFormat.database:
      return service.exportDatabase(target);
  }
}

/// The immediate child entry names of [dir] (files + subdirectories).
Set<String> _listNames(Directory dir) {
  return dir
      .listSync(followLinks: false)
      .map((FileSystemEntity e) => p.basename(e.path))
      .toSet();
}

/// Indexes [wishes] by id for an order-independent equality comparison.
Map<String, Wish> _byId(List<Wish> wishes) => <String, Wish>{
      for (final Wish w in wishes) w.id: w,
    };

// --- Case specification + generators ----------------------------------------

/// One generated export-failure case: the population of wishes to seed, the
/// export format to attempt, and the name of the (directory) target that will
/// force the write to fail.
class _ExportCase {
  const _ExportCase({
    required this.wishes,
    required this.format,
    required this.targetName,
  });

  final List<_WishSpec> wishes;
  final BackupFormat format;
  final String targetName;

  @override
  String toString() => '_ExportCase(wishes: ${wishes.length}, format: $format, '
      'targetName: $targetName)';
}

/// The inputs for one seeded Wish.
class _WishSpec {
  const _WishSpec({
    required this.title,
    required this.description,
    required this.categoryName,
    required this.priority,
  });

  final String title;
  final String? description;
  final String categoryName;
  final Priority? priority;

  @override
  String toString() => '_WishSpec(title: $title, category: $categoryName)';
}

/// Characters mixed into generated text to stress serialization/escaping:
/// ASCII letters and digits plus Unicode and CSV/JSON-significant punctuation.
const String _specialChars = 'abcABC123 "\\/\n\r\t{}[],:😀é中🚀';

/// A non-empty title (R1.2 requires non-empty).
final Generator<String> _anyNonEmptyText = any.nonEmptyStringOf(_specialChars);

/// An optional description: null, empty, or arbitrary text (R1.3, R2.3).
final Generator<String?> _anyOptionalText = any.oneOf<String?>([
  any.null_,
  any.always<String?>(''),
  any.stringOf(_specialChars).map<String?>((String s) => s),
]);

/// A random priority, or null to exercise the Medium default (R1.4).
final Generator<Priority?> _anyOptionalPriority = any.oneOf<Priority?>([
  any.null_,
  any.choose(Priority.values).map<Priority?>((Priority p) => p),
]);

/// A single random Wish specification.
final Generator<_WishSpec> _anyWishSpec = any.combine4(
  _anyNonEmptyText, // title
  _anyOptionalText, // description
  _anyNonEmptyText, // categoryName (unique by name)
  _anyOptionalPriority, // priority (incl. null -> Medium)
  (String title, String? description, String categoryName,
          Priority? priority) =>
      _WishSpec(
    title: title,
    description: description,
    categoryName: categoryName,
    priority: priority,
  ),
);

/// A population of wishes: a (possibly empty) list, since Property 14 holds
/// "for any set of Wishes" including the empty set.
final Generator<List<_WishSpec>> _anyWishPopulation = any.list(_anyWishSpec);

/// A text/JSON/CSV export format. The temp-then-move cleanup path is most
/// directly exercised by JSON and CSV (both write a sibling temp then move),
/// so the generator biases toward them while still occasionally covering the
/// database format (which fails earlier, before any temp file).
final Generator<BackupFormat> _anyFormat = any.oneOf<BackupFormat>([
  any.always(BackupFormat.json),
  any.always(BackupFormat.csv),
  any.always(BackupFormat.json),
  any.always(BackupFormat.csv),
  any.always(BackupFormat.database),
]);

/// A simple, filesystem-safe target directory name.
final Generator<String> _anyTargetName = any
    .nonEmptyStringOf('abcdefghijklmnopqrstuvwxyz0123456789')
    .map((String s) => 'export_$s');

/// A full export-failure case.
final Generator<_ExportCase> _anyExportCase = any.combine3(
  _anyWishPopulation,
  _anyFormat,
  _anyTargetName,
  (List<_WishSpec> wishes, BackupFormat format, String targetName) =>
      _ExportCase(wishes: wishes, format: format, targetName: targetName),
);
