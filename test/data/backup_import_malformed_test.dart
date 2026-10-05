// Feature: wishable, Property 15: Malformed import is rejected without side effects
//
// Property-based test for task 9.4.
//
// **Property 15: Malformed import is rejected without side effects**
// **Validates: Requirements 12.2**
//
// `BackupService.inspect` fully parses and validates an import file BEFORE any
// write, and `restore` re-parses through the exact same validation path inside
// a single transaction (design "Import safety", R12.2 / R12.1). Both therefore
// reject any unreadable/malformed/wrong-shape file with a descriptive
// [BackupImportException] and leave the database untouched.
//
// This property seeds a real in-memory [AppDatabase] with existing wishes +
// categories, then — for randomly generated MALFORMED file contents spanning
// every declared [BackupFormat] (not-JSON strings; JSON with the wrong
// top-level shape, missing fields, unknown enum tokens, or a bad
// schemaVersion; truncated/garbage CSV; and a nonexistent file path) — writes
// the content to a temp file and calls both `inspect()` and `restore()`.
//
// For every generated input it asserts:
//   1. a [BackupImportException] is thrown by BOTH `inspect` and `restore`
//      (R12.2 "rejects malformed/unreadable files with a descriptive error"),
//      and
//   2. NO side effects — the database snapshot (`getAll()`), compared
//      field-for-field, is identical before and after each failed
//      `inspect`/`restore` (R12.2 "NO write ever happens").
//
// This exercises real Drift I/O over an in-memory database and real on-disk
// file reads, so it runs under `flutter_test`.
library wishable.test.data.backup_import_malformed_test;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// glados supplies the property runner and its generator extensions on `Any`.
// Its `expect`/`test` clash with flutter_test's, so hide those two and let
// flutter_test provide `test`, `expect`, and the matchers.
import 'package:glados/glados.dart'
    hide expect, test, expectLater, setUpAll, tearDownAll;
import 'package:path/path.dart' as p;
import 'package:wishable/data/app_database.dart';
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

  // A single shared temp directory for all generated malformed files; cleaned
  // up in tearDownAll. Each case writes a uniquely named file inside it.
  late Directory tempDir;
  var fileCounter = 0;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('wishable_malformed_');
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ---- Property 15: malformed import is rejected without side effects -----
  //
  // 100 generated cases (minimum required). Each case runs against a fresh
  // in-memory database seeded with wishes so cases are fully isolated and the
  // "no side effects" assertion has real data to protect.
  Glados<_MalformedCase>(_anyMalformedCase, ExploreConfig(numRuns: 100)).test(
    'inspect() and restore() reject every malformed input with a '
    'BackupImportException and leave the database byte-identical',
    (malformed) async {
      final AppDatabase db = AppDatabase.forExecutor(NativeDatabase.memory());
      try {
        final wishes = DriftWishRepository(db);
        final categories = DriftCategoryRepository(db);
        final service = DriftBackupService(
          db,
          wishRepository: wishes,
          categoryRepository: categories,
        );

        // --- Seed existing data the import must not touch (R12.2) ----------
        await _seed(wishes, categories);
        final List<Wish> before = await wishes.getAll();
        // Guard: the "no side effects" assertion is only meaningful if there
        // is actually data present to protect.
        expect(before, isNotEmpty, reason: 'seed must create wishes');

        // --- Materialize the malformed import file -------------------------
        final ImportFile file =
            await malformed.toImportFile(tempDir, fileCounter++);

        // --- 1) inspect() rejects with a BackupImportException -------------
        await expectLater(
          service.inspect(file),
          throwsA(isA<BackupImportException>()),
          reason: 'inspect must reject malformed input: ${malformed.label}',
        );

        // No side effects: a failed inspect never writes (R12.2).
        _expectUnchanged(await wishes.getAll(), before,
            reason: 'inspect must not mutate the database');

        // --- 2) restore() rejects with a BackupImportException -------------
        await expectLater(
          service.restore(file),
          throwsA(isA<BackupImportException>()),
          reason: 'restore must reject malformed input: ${malformed.label}',
        );

        // No side effects: a failed restore rolls back and leaves the
        // database exactly as it was (R12.2 / R12.1).
        _expectUnchanged(await wishes.getAll(), before,
            reason: 'restore must not mutate the database');
      } finally {
        await db.close();
      }
    },
  );
}

// --- Seeding ----------------------------------------------------------------

/// Seeds a deterministic, non-trivial set of wishes across a couple of
/// categories so the "no side effects" invariant has real state to protect.
Future<void> _seed(
  DriftWishRepository wishes,
  DriftCategoryRepository categories,
) async {
  final Category travel = await categories.getOrCreateByName('Travel');
  final Category learn = await categories.getOrCreateByName('Learn');

  await wishes.create(WishDraft(
    title: 'See the aurora',
    description: 'Tromsø in winter',
    categoryId: travel.id,
    priority: Priority.high,
  ));
  await wishes.create(WishDraft(
    title: 'Learn Dart',
    description: null,
    categoryId: learn.id,
    priority: Priority.medium,
  ));
  await wishes.create(WishDraft(
    title: 'Visit Kyoto, "the old capital"',
    description: 'cherry blossoms, 桜',
    categoryId: travel.id,
    priority: Priority.low,
  ));
}

// --- No-side-effects assertion ----------------------------------------------

/// Asserts that [actual] (the database snapshot after a failed import) matches
/// [reference] (the snapshot before it) field-for-field, order-independent.
/// This is the "no write ever happened" guarantee of R12.2.
void _expectUnchanged(
  List<Wish> actual,
  List<Wish> reference, {
  required String reason,
}) {
  expect(actual, hasLength(reference.length), reason: reason);
  final Map<String, Wish> byId = <String, Wish>{
    for (final Wish w in actual) w.id: w,
  };
  for (final Wish original in reference) {
    final Wish? survivor = byId[original.id];
    expect(survivor, isNotNull, reason: '$reason (missing ${original.id})');
    expect(survivor!.id, original.id, reason: '$reason: id');
    expect(survivor.title, original.title, reason: '$reason: title');
    expect(survivor.description, original.description,
        reason: '$reason: description');
    expect(survivor.categoryId, original.categoryId,
        reason: '$reason: categoryId');
    expect(survivor.priority, original.priority, reason: '$reason: priority');
    expect(survivor.status, original.status, reason: '$reason: status');
    expect(survivor.progress, original.progress, reason: '$reason: progress');
    expect(survivor.createdAtUtc, original.createdAtUtc,
        reason: '$reason: createdAtUtc');
    expect(survivor.updatedAtUtc, original.updatedAtUtc,
        reason: '$reason: updatedAtUtc');
  }
}

// --- Malformed-input model + generators -------------------------------------

/// One generated malformed import: the declared [format], a short [label] for
/// diagnostics, and how it is materialized on disk.
///
/// A [content] of `null` means "do not write a file at all" — the import
/// points at a nonexistent path, which both `inspect` and `restore` must
/// reject as unreadable (R12.2).
class _MalformedCase {
  const _MalformedCase({
    required this.format,
    required this.label,
    required this.content,
  });

  final BackupFormat format;
  final String label;
  final String? content;

  /// Writes [content] to a uniquely named temp file inside [dir] and returns
  /// the matching [ImportFile]. When [content] is `null`, returns an
  /// [ImportFile] pointing at a path where no file exists.
  Future<ImportFile> toImportFile(Directory dir, int index) async {
    final String ext = _extensionFor(format);
    final String path = p.join(dir.path, 'malformed_$index.$ext');
    if (content == null) {
      // Deliberately do NOT create the file: a nonexistent path.
      final File f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    } else {
      await File(path).writeAsString(content!, flush: true);
    }
    return ImportFile(path: path, format: format);
  }

  static String _extensionFor(BackupFormat format) {
    switch (format) {
      case BackupFormat.json:
        return 'json';
      case BackupFormat.csv:
        return 'csv';
      case BackupFormat.database:
        return 'sqlite';
    }
  }

  @override
  String toString() => '_MalformedCase($label, format: $format, '
      'content: ${content == null ? '<nonexistent>' : _preview(content!)})';

  static String _preview(String s) {
    final flat = s.replaceAll('\n', '\\n').replaceAll('\r', '\\r');
    return flat.length <= 60 ? flat : '${flat.substring(0, 57)}...';
  }
}

/// Characters mixed into generated junk to stress the parsers.
const String _junkChars = 'abcABC123 "\\/\n\r\t{}[],:;😀é中';

/// Arbitrary (almost-certainly-not-valid) text.
final Generator<String> _anyJunkText = any.stringOf(_junkChars);

// ---- Malformed JSON generators --------------------------------------------

/// Not JSON at all: arbitrary junk text that `jsonDecode` rejects (and the
/// rare valid-JSON case is still rejected by the shape/field checks below,
/// but to keep this generator honestly "not JSON" we prefix a bare word).
final Generator<String> _notJsonText = _anyJunkText.map((s) => 'not-json $s');

/// JSON whose top-level value is the wrong shape (an array / string / number /
/// bool / null instead of the expected object).
final Generator<String> _jsonWrongTopLevelShape = any.oneOf<String>([
  any.always('[]'),
  any.always('[1, 2, 3]'),
  any.always('"just a string"'),
  any.always('42'),
  any.always('true'),
  any.always('null'),
]);

/// A well-formed JSON object that declares an UNSUPPORTED schemaVersion
/// (anything other than [kWishJsonSchemaVersion] == 1), with an empty wishes
/// array so the ONLY defect is the version. Shifting away from 1 (0, or 2+)
/// guarantees the version is always unsupported.
final Generator<String> _jsonBadSchemaVersion = any
    .intInRange(0, 50)
    .map((v) => v == 1 ? 0 : v)
    .map((v) => '{"schemaVersion": $v, "wishes": []}');

/// A schema-valid envelope whose `wishes` array holds a single object that is
/// malformed in exactly one way: a missing required field, a wrong-typed
/// field, an unknown enum token, or an unparseable timestamp.
final Generator<String> _jsonMalformedWish = any.oneOf<String>([
  // Missing the required 'title'.
  any.always('{"schemaVersion": 1, "wishes": [{"id": "x", '
      '"description": null, "category": "C", "priority": "low", '
      '"status": "active", "progress": 0, '
      '"createdAtUtc": "2025-01-01T00:00:00.000Z", '
      '"updatedAtUtc": "2025-01-01T00:00:00.000Z"}]}'),
  // Unknown priority token.
  any.always('{"schemaVersion": 1, "wishes": [{"id": "x", "title": "t", '
      '"description": null, "category": "C", "priority": "URGENT", '
      '"status": "active", "progress": 0, '
      '"createdAtUtc": "2025-01-01T00:00:00.000Z", '
      '"updatedAtUtc": "2025-01-01T00:00:00.000Z"}]}'),
  // Unknown status token.
  any.always('{"schemaVersion": 1, "wishes": [{"id": "x", "title": "t", '
      '"description": null, "category": "C", "priority": "low", '
      '"status": "paused", "progress": 0, '
      '"createdAtUtc": "2025-01-01T00:00:00.000Z", '
      '"updatedAtUtc": "2025-01-01T00:00:00.000Z"}]}'),
  // progress is a string, not an int.
  any.always('{"schemaVersion": 1, "wishes": [{"id": "x", "title": "t", '
      '"description": null, "category": "C", "priority": "low", '
      '"status": "active", "progress": "lots", '
      '"createdAtUtc": "2025-01-01T00:00:00.000Z", '
      '"updatedAtUtc": "2025-01-01T00:00:00.000Z"}]}'),
  // Unparseable timestamp.
  any.always('{"schemaVersion": 1, "wishes": [{"id": "x", "title": "t", '
      '"description": null, "category": "C", "priority": "low", '
      '"status": "active", "progress": 0, '
      '"createdAtUtc": "not-a-date", '
      '"updatedAtUtc": "2025-01-01T00:00:00.000Z"}]}'),
  // 'wishes' present but not an array.
  any.always('{"schemaVersion": 1, "wishes": {"nope": true}}'),
  // Missing schemaVersion entirely.
  any.always('{"wishes": []}'),
]);

final Generator<_MalformedCase> _anyMalformedJson = any.oneOf<_MalformedCase>([
  _notJsonText.map((s) => _MalformedCase(
      format: BackupFormat.json, label: 'json/not-json', content: s)),
  _jsonWrongTopLevelShape.map((s) => _MalformedCase(
      format: BackupFormat.json, label: 'json/wrong-shape', content: s)),
  _jsonBadSchemaVersion.map((s) => _MalformedCase(
      format: BackupFormat.json, label: 'json/bad-schema-version', content: s)),
  _jsonMalformedWish.map((s) => _MalformedCase(
      format: BackupFormat.json, label: 'json/malformed-wish', content: s)),
]);

// ---- Malformed CSV generators ---------------------------------------------

/// Garbage / truncated CSV content: random junk, a header with no body in the
/// wrong shape, or a row with the wrong number of columns. The CSV codec
/// rejects content that does not match its fixed-column shape.
final Generator<String> _malformedCsvText = any.oneOf<String>([
  // Pure junk (no recognizable header).
  _anyJunkText.map((s) => 'definitely,not,a,valid,wish,csv\n$s'),
  // A header-looking line but truncated / missing required columns.
  any.always('title,description\n"Only two columns",oops'),
  // A single bare value — no delimiters, no header.
  any.always('garbage'),
  // Numeric-looking junk rows.
  any.always('1,2,3\n4,5,6'),
]);

final Generator<_MalformedCase> _anyMalformedCsv = _malformedCsvText.map((s) =>
    _MalformedCase(
        format: BackupFormat.csv, label: 'csv/malformed', content: s));

// ---- Malformed database generators ----------------------------------------

/// A "database" import that is not a valid SQLite/Wishable database: either a
/// nonexistent file (content == null) or a file containing non-SQLite bytes.
final Generator<_MalformedCase> _anyMalformedDatabase =
    any.oneOf<_MalformedCase>([
  // Nonexistent path.
  any.always(const _MalformedCase(
      format: BackupFormat.database, label: 'db/nonexistent', content: null)),
  // A file that exists but is not a SQLite database.
  _anyJunkText.map((s) => _MalformedCase(
      format: BackupFormat.database,
      label: 'db/not-sqlite',
      content: 'this is not a sqlite header $s')),
]);

// ---- Top-level generator across all formats --------------------------------

/// Draws a malformed case from every format and defect family with roughly
/// even weighting, so 100 runs cover the whole rejection space (R12.2).
final Generator<_MalformedCase> _anyMalformedCase = any.oneOf<_MalformedCase>([
  _anyMalformedJson,
  _anyMalformedCsv,
  _anyMalformedDatabase,
]);
