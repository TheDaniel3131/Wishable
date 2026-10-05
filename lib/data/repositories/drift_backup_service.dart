/// The Drift-backed [BackupService] implementation (design "Data-Access Layer
/// (repositories)", task 9).
///
/// This class is the sole bridge between the Drift [AppDatabase] / the domain
/// repositories and the on-disk backup artifacts. It lives in the data-access
/// layer — the only layer permitted to reference Drift types and `dart:io`
/// (R14.3) — and keeps every write safe by staging to a temp file and only
/// moving it into place once the whole payload is durable.
///
/// ## Export safety (R11.4)
///
/// Every export follows the same contract (design error-handling table):
///
///   1. Read a transactional snapshot of all wishes + categories so export
///      never mutates the database and always sees a consistent view (R11.1,
///      R11.2, R11.3).
///   2. Serialize/produce the payload into a sibling **temp** file next to the
///      requested target path.
///   3. Atomically move/rename the temp file onto the target path.
///   4. On ANY failure, delete the partial temp file (and never touch the
///      target), then rethrow a descriptive [BackupExportException]. The
///      database is left unchanged because export only ever reads from it.
///
/// ## Category by name
///
/// The persisted [Wish] stores a `categoryId` foreign key, but the JSON/CSV
/// export formats embed the category by NAME so an import on a fresh install
/// can recreate categories (design "Serialization formats"). This service owns
/// the id→name mapping it builds from the category snapshot and hands
/// [SerializableWish] projections to the pure [WishJsonCodec]/[WishCsvCodec].
///
/// ## Import safety (R12.1, R12.2)
///
/// Import is the mirror of export: validate everything before touching the
/// database, then apply the whole payload atomically.
///
///   1. `inspect` reads and FULLY parses/validates the file (JSON/CSV via the
///      pure codecs, a database file by opening it read-only and reading its
///      tables). Any unreadable/malformed/wrong-schema file is rejected with a
///      descriptive [BackupImportException] and NO write ever happens (R12.2).
///   2. `restore` re-parses the file through the same path, resolves category
///      NAMEs back to ids (creating any missing categories), and applies the
///      replacement set through [WishRepository.replaceAll] inside a SINGLE
///      [AppDatabase.transaction] so a mid-restore failure rolls the whole
///      operation back and leaves the database exactly as it was (R12.1).
library wishable.data.repositories.drift_backup_service;

import 'dart:io';

import 'package:drift/drift.dart';

import '../../domain/backup.dart';
import '../../domain/category.dart';
import '../../domain/wish.dart';
import '../../domain/wish_csv_codec.dart';
import '../../domain/wish_json_codec.dart';
import '../app_database.dart';
import '../connection/file_database.dart';
import 'backup_service.dart';
import 'category_repository.dart';
import 'wish_repository.dart';

/// Thrown when an export fails (disk full, permission denied, cancellation, a
/// missing database file, …). The [message] is a human-readable description
/// suitable for surfacing to the user (R11.4); [cause] carries the underlying
/// error for diagnostics when present.
class BackupExportException implements Exception {
  BackupExportException(this.message, {this.cause});

  /// Human-readable description of what went wrong.
  final String message;

  /// The underlying error that triggered the failure, when known.
  final Object? cause;

  @override
  String toString() {
    final suffix = cause == null ? '' : ' (cause: $cause)';
    return 'BackupExportException: $message$suffix';
  }
}

/// Thrown when an import fails: an unreadable file, malformed JSON/CSV, an
/// unsupported schema version, an invalid enum/timestamp token, or a database
/// file that is not a valid Wishable database. The [message] is a
/// human-readable description suitable for surfacing to the user (R12.2);
/// [cause] carries the underlying error (e.g. a [WishJsonFormatException] or
/// [WishCsvFormatException]) for diagnostics when present.
///
/// `inspect` throws this before any write, so the database is untouched when it
/// is raised. `restore` throws it from inside its transaction, so the rollback
/// leaves the database exactly as it was (R12.1).
class BackupImportException implements Exception {
  BackupImportException(this.message, {this.cause});

  /// Human-readable description of what went wrong.
  final String message;

  /// The underlying error that triggered the failure, when known.
  final Object? cause;

  @override
  String toString() {
    final suffix = cause == null ? '' : ' (cause: $cause)';
    return 'BackupImportException: $message$suffix';
  }
}

/// Drift-backed implementation of [BackupService].
///
/// Reads a transactional snapshot through the injected [WishRepository] /
/// [CategoryRepository] (and the raw [AppDatabase] for the database-file
/// export) and writes export artifacts with the stage-temp-then-move contract
/// described in the library doc (R11.4).
final class DriftBackupService implements BackupService {
  /// Creates a service over [_db] and the domain repositories.
  ///
  /// The optional codecs are injectable for tests; they default to the pure
  /// domain codecs.
  DriftBackupService(
    this._db, {
    required WishRepository wishRepository,
    required CategoryRepository categoryRepository,
    WishJsonCodec jsonCodec = const WishJsonCodec(),
    WishCsvCodec csvCodec = const WishCsvCodec(),
  })  : _wishes = wishRepository,
        _categories = categoryRepository,
        _jsonCodec = jsonCodec,
        _csvCodec = csvCodec;

  final AppDatabase _db;
  final WishRepository _wishes;
  final CategoryRepository _categories;
  final WishJsonCodec _jsonCodec;
  final WishCsvCodec _csvCodec;

  // --- Export operations ---------------------------------------------------

  @override
  Future<ExportResult> exportDatabase(ExportTarget t) async {
    // A raw copy of the SQLite database file (R11.1). Checkpoint the
    // write-ahead log first so a file-backed database flushes any pending
    // pages into the main file before we copy it, then copy the resolved
    // source file into place via the temp-then-move contract.
    final List<Wish> wishes = await _snapshotWishes();
    return _writeAtomically(
      t,
      BackupFormat.database,
      wishCount: wishes.length,
      produce: (File tempFile) async {
        final String sourcePath = await _resolveDatabaseFilePath();
        await _checkpoint();
        await File(sourcePath).copy(tempFile.path);
      },
    );
  }

  @override
  Future<ExportResult> exportJson(ExportTarget t) async {
    final _Snapshot snapshot = await _snapshot();
    final List<SerializableWish> serializable = _project(snapshot);
    final String payload = _jsonCodec.encode(serializable);
    return _writeAtomically(
      t,
      BackupFormat.json,
      wishCount: serializable.length,
      produce: (File tempFile) => tempFile.writeAsString(payload, flush: true),
    );
  }

  @override
  Future<ExportResult> exportCsv(ExportTarget t) async {
    final _Snapshot snapshot = await _snapshot();
    final List<SerializableWish> serializable = _project(snapshot);
    final String payload = _csvCodec.encode(serializable);
    return _writeAtomically(
      t,
      BackupFormat.csv,
      wishCount: serializable.length,
      produce: (File tempFile) => tempFile.writeAsString(payload, flush: true),
    );
  }

  // --- Import operations (task 9.2) ----------------------------------------

  @override
  Future<ImportPreview> inspect(ImportFile file) async {
    // Fully parse + validate the file before any write (R12.2). _parse reads,
    // decodes, and validates according to the declared format and rethrows any
    // failure as a descriptive BackupImportException. NO database write occurs
    // here — a preview means "this file would restore cleanly".
    final _ParsedImport parsed = await _parse(file);
    final int categoryCount = parsed.wishes
        .map((SerializableWish w) => w.categoryName)
        .toSet()
        .length;
    return ImportPreview(
      format: file.format,
      wishCount: parsed.wishes.length,
      categoryCount: categoryCount,
      schemaVersion: parsed.schemaVersion,
    );
  }

  @override
  Future<void> restore(ImportFile file) async {
    // Re-parse through the same validation path used by inspect, so a restore
    // is only ever attempted on a file that validated cleanly.
    final _ParsedImport parsed = await _parse(file);

    // Apply the whole payload inside a SINGLE transaction so it is
    // all-or-nothing: resolving/creating categories and replacing every wish
    // commit together, and any failure rolls the transaction back leaving the
    // database exactly as it was (R12.1). getOrCreateByName and replaceAll run
    // on the same database and therefore participate in this outer
    // transaction.
    try {
      await _db.transaction(() async {
        // Map each embedded category NAME back to an id, creating any category
        // that does not yet exist (design "Category by name"). Caching keeps a
        // repeated name from issuing duplicate lookups.
        final Map<String, String> idByName = <String, String>{};
        final List<Wish> wishes = <Wish>[];
        for (final SerializableWish sw in parsed.wishes) {
          String? categoryId = idByName[sw.categoryName];
          if (categoryId == null) {
            final Category category =
                await _categories.getOrCreateByName(sw.categoryName);
            categoryId = category.id;
            idByName[sw.categoryName] = categoryId;
          }
          wishes.add(sw.toWish(categoryId: categoryId));
        }
        await _wishes.replaceAll(wishes);
      });
    } on BackupImportException {
      rethrow;
    } catch (error) {
      throw BackupImportException(
        'Failed to restore ${_formatLabel(file.format)} from "${file.path}". '
        'The database was left unchanged.',
        cause: error,
      );
    }
  }

  // --- Import parsing + validation (R12.2) ---------------------------------

  /// Reads and fully validates [file] according to its declared format,
  /// returning the parsed [SerializableWish] projection shared by `inspect`
  /// and `restore`. Any failure — a missing/unreadable file, malformed
  /// JSON/CSV, an unsupported schema version, an invalid enum/timestamp token,
  /// or a database file that is not a readable Wishable database — is rethrown
  /// as a descriptive [BackupImportException]. No write happens here.
  Future<_ParsedImport> _parse(ImportFile file) async {
    switch (file.format) {
      case BackupFormat.json:
        return _parseText(file, (String source) {
          final List<SerializableWish> wishes = _jsonCodec.decode(source);
          return _ParsedImport(
            wishes: wishes,
            schemaVersion: kWishJsonSchemaVersion,
          );
        });
      case BackupFormat.csv:
        return _parseText(file, (String source) {
          final List<SerializableWish> wishes = _csvCodec.decode(source);
          return _ParsedImport(wishes: wishes, schemaVersion: null);
        });
      case BackupFormat.database:
        return _parseDatabase(file);
    }
  }

  /// Reads [file] as UTF-8 text and runs [decode] over it, mapping every
  /// failure (I/O or codec) to a descriptive [BackupImportException].
  Future<_ParsedImport> _parseText(
    ImportFile file,
    _ParsedImport Function(String source) decode,
  ) async {
    final String source;
    try {
      source = await File(file.path).readAsString();
    } catch (error) {
      throw BackupImportException(
        'Could not read the ${_formatLabel(file.format)} file at '
        '"${file.path}".',
        cause: error,
      );
    }
    try {
      return decode(source);
    } on WishJsonFormatException catch (error) {
      throw BackupImportException(
        'The JSON file at "${file.path}" is malformed: ${error.message}',
        cause: error,
      );
    } on WishCsvFormatException catch (error) {
      throw BackupImportException(
        'The CSV file at "${file.path}" is malformed: ${error.message}',
        cause: error,
      );
    }
  }

  /// Opens [file] as a Wishable [AppDatabase] and reads its wishes +
  /// categories to validate it is a well-formed database before any restore.
  /// Projects the rows into [SerializableWish] (category by NAME) so the
  /// database path shares the same restore logic as JSON/CSV. The temp
  /// database is always closed, and any failure becomes a descriptive
  /// [BackupImportException].
  Future<_ParsedImport> _parseDatabase(ImportFile file) async {
    if (!await File(file.path).exists()) {
      throw BackupImportException(
        'The database file at "${file.path}" does not exist.',
      );
    }
    AppDatabase? source;
    try {
      source = AppDatabase.forExecutor(openFileExecutor(file.path));
      // Reading both tables forces the schema to resolve and surfaces a
      // non-Wishable or corrupt file as an error here (before any write).
      final List<CategoryRow> categoryRows =
          await source.select(source.categories).get();
      final List<WishRow> wishRows = await source.select(source.wishes).get();
      final Map<String, String> nameById = <String, String>{
        for (final CategoryRow c in categoryRows) c.id: c.name,
      };
      final List<SerializableWish> serializable = <SerializableWish>[
        for (final WishRow w in wishRows)
          SerializableWish(
            id: w.id,
            title: w.title,
            description: w.description,
            categoryName: nameById[w.categoryId] ?? w.categoryId,
            priority: w.priority,
            status: w.status,
            progress: w.progress,
            createdAtUtc: w.createdAtUtc.toUtc(),
            updatedAtUtc: w.updatedAtUtc.toUtc(),
          ),
      ];
      return _ParsedImport(wishes: serializable, schemaVersion: null);
    } catch (error) {
      throw BackupImportException(
        'The file at "${file.path}" is not a readable Wishable database.',
        cause: error,
      );
    } finally {
      await source?.close();
    }
  }

  // --- Snapshot + projection -----------------------------------------------

  /// Reads a transactional snapshot of all wishes and categories so an export
  /// sees a single consistent view and never mutates the database (R11).
  Future<_Snapshot> _snapshot() {
    return _db.transaction(() async {
      final List<Wish> wishes = await _wishes.getAll();
      final List<Category> categories = await _categories.getAll();
      return _Snapshot(wishes: wishes, categories: categories);
    });
  }

  /// Reads just the wish snapshot (used by the raw database export, which does
  /// not need the category projection) inside a transaction.
  Future<List<Wish>> _snapshotWishes() {
    return _db.transaction(() => _wishes.getAll());
  }

  /// Projects the snapshot into the pure [SerializableWish] units the codecs
  /// consume, mapping each wish's `categoryId` to its category NAME (design
  /// "Serialization formats"). A wish whose category is somehow missing from
  /// the snapshot falls back to its raw id so the export never silently drops
  /// a record.
  List<SerializableWish> _project(_Snapshot snapshot) {
    final Map<String, String> nameById = <String, String>{
      for (final Category c in snapshot.categories) c.id: c.name,
    };
    return <SerializableWish>[
      for (final Wish w in snapshot.wishes)
        SerializableWish.fromWish(
          w,
          categoryName: nameById[w.categoryId] ?? w.categoryId,
        ),
    ];
  }

  // --- Atomic write contract (R11.4) ---------------------------------------

  /// Produces an export into a sibling temp file via [produce], then moves it
  /// atomically onto `target.path`. On any failure the partial temp file is
  /// deleted and a descriptive [BackupExportException] is thrown; the database
  /// is never touched because export only reads from it.
  Future<ExportResult> _writeAtomically(
    ExportTarget target,
    BackupFormat format, {
    required int wishCount,
    required Future<void> Function(File tempFile) produce,
  }) async {
    final File destination = File(target.path);
    final File tempFile = File(_tempPathFor(target.path));
    try {
      // Ensure the destination directory exists before staging.
      await destination.parent.create(recursive: true);
      // Clear any leftover temp from a previous aborted run.
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      await produce(tempFile);

      // Atomically move the fully written temp file into place. rename() is
      // atomic within a filesystem; fall back to copy+delete if the temp and
      // target live on different volumes.
      await _moveIntoPlace(tempFile, destination);

      final int byteCount = await destination.length();
      return ExportResult(
        path: destination.path,
        format: format,
        byteCount: byteCount,
        wishCount: wishCount,
      );
    } catch (error) {
      // Leave the DB and any pre-existing target untouched; remove the partial
      // temp file and surface a descriptive error (R11.4).
      await _deleteQuietly(tempFile);
      throw BackupExportException(
        'Failed to export ${_formatLabel(format)} to "${target.path}".',
        cause: error,
      );
    }
  }

  /// Moves [temp] onto [destination], preferring an atomic rename and falling
  /// back to copy-then-delete when the two paths are on different filesystems
  /// (where rename raises).
  Future<void> _moveIntoPlace(File temp, File destination) async {
    try {
      await temp.rename(destination.path);
    } on FileSystemException {
      await temp.copy(destination.path);
      await _deleteQuietly(temp);
    }
  }

  /// A sibling temp path for [targetPath] that will not collide with the
  /// target itself.
  String _tempPathFor(String targetPath) {
    final String stamp = DateTime.now().microsecondsSinceEpoch.toString();
    return '$targetPath.$stamp.tmp';
  }

  /// Deletes [file] if present, swallowing any error so cleanup never masks
  /// the original failure.
  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup; ignore.
    }
  }

  // --- Raw database export helpers -----------------------------------------

  /// Flushes the write-ahead log into the main database file so a raw file
  /// copy captures all committed data (R11.1). Best-effort: a database without
  /// WAL mode simply has nothing to checkpoint.
  Future<void> _checkpoint() async {
    await _db.customStatement('PRAGMA wal_checkpoint(FULL)');
  }

  /// Resolves the absolute path of the main SQLite database file via
  /// `PRAGMA database_list`. Throws a descriptive [BackupExportException] when
  /// the database is not file-backed (e.g. an in-memory test database), since
  /// there is nothing to copy.
  Future<String> _resolveDatabaseFilePath() async {
    final List<QueryRow> rows =
        await _db.customSelect('PRAGMA database_list').get();
    for (final QueryRow row in rows) {
      final Map<String, Object?> data = row.data;
      if (data['name'] == 'main') {
        final Object? file = data['file'];
        if (file is String && file.isNotEmpty) {
          return file;
        }
      }
    }
    throw BackupExportException(
      'The database is not backed by a file and cannot be copied.',
    );
  }

  String _formatLabel(BackupFormat format) {
    switch (format) {
      case BackupFormat.database:
        return 'database';
      case BackupFormat.json:
        return 'JSON';
      case BackupFormat.csv:
        return 'CSV';
    }
  }
}

/// A consistent read of the two tables an export serializes.
final class _Snapshot {
  const _Snapshot({required this.wishes, required this.categories});

  final List<Wish> wishes;
  final List<Category> categories;
}

/// The fully validated result of parsing an import file, shared by `inspect`
/// (which turns it into an [ImportPreview]) and `restore` (which applies it).
///
/// A [_ParsedImport] only exists for a file that read + decoded cleanly;
/// [wishes] carries the category by NAME (ready for id resolution on restore)
/// and [schemaVersion] is the version the format declared (JSON) or `null` for
/// formats without an embedded version (CSV, database).
final class _ParsedImport {
  const _ParsedImport({required this.wishes, required this.schemaVersion});

  final List<SerializableWish> wishes;
  final int? schemaVersion;
}
