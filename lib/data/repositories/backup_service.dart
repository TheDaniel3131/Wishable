/// The [BackupService] abstract interface (design "Data-Access Layer
/// (repositories)").
///
/// Drift-free seam for manual backup/restore: the layers above depend only on
/// this interface, a Drift-backed class (task 9) implements it, and the
/// interface references only the domain backup value types ([ExportTarget],
/// [ExportResult], [ImportFile], [ImportPreview]) so no Drift type leaks
/// across the boundary (R14.3).
///
/// Exports read from a transactional snapshot and write to a temp path before
/// moving into place; on failure the implementation deletes any partial file
/// and leaves the database unchanged (R11.4). `inspect` fully validates an
/// import before any write (R12.2); `restore` applies it inside a single
/// transaction so a mid-restore failure rolls back entirely (R12.1).
library wishable.data.repositories.backup_service;

import '../../domain/backup.dart';

/// Drift-free boundary for export and import/restore operations.
abstract interface class BackupService {
  /// Exports a raw copy of the database to [t] (R11.1).
  Future<ExportResult> exportDatabase(ExportTarget t);

  /// Exports a schema-versioned JSON document to [t] (R11.2).
  Future<ExportResult> exportJson(ExportTarget t);

  /// Exports a fixed-column CSV document to [t] (R11.3).
  Future<ExportResult> exportCsv(ExportTarget t);

  /// Produces the export content for [format] in memory, without writing a
  /// file. The presentation layer delivers the bytes per platform (write to a
  /// chosen path on desktop/mobile, or a browser download on web). This is the
  /// cross-platform export path (R11.1–R11.3) that works on web too.
  Future<BackupBytes> exportToBytes(BackupFormat format);

  /// Reads and fully validates [file], returning a preview; rejects a
  /// malformed or unreadable file with a descriptive error and no write
  /// (R12.2).
  Future<ImportPreview> inspect(ImportFile file);

  /// Restores the database from [file] inside a single transaction, replacing
  /// existing data all-or-nothing (R12.1).
  Future<void> restore(ImportFile file);
}
