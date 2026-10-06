/// Domain-level value types for the backup/restore boundary.
///
/// These describe the inputs and outputs of `BackupService` (design
/// "Data-Access Layer (repositories)") in Drift-free, platform-neutral terms
/// so the application and presentation layers can drive export/import without
/// referencing Drift or `dart:io`. The data layer maps these to concrete file
/// I/O; the UI maps a user's picked file / chosen destination to them.
///
/// Pure Dart: no Flutter, Drift, or dart:io dependencies. Immutable and
/// compared by value.
library wishable.domain.backup;

/// The format produced or consumed by a backup operation.
enum BackupFormat {
  /// A raw copy of the SQLite database file (R11.1).
  database,

  /// A schema-versioned JSON document (R11.2, R12.4).
  json,

  /// A fixed-column, RFC-4180 CSV document (R11.3, R12.5).
  csv,
}

/// Where an export should be written.
///
/// A platform-neutral destination descriptor: [path] is the absolute file
/// path the data layer writes to (after writing to a temp file and moving it
/// into place, per R11.4). Carrying the [format] lets the service validate
/// the target against the requested operation.
final class ExportTarget {
  const ExportTarget({
    required this.path,
    required this.format,
  });

  /// Absolute destination path for the exported file.
  final String path;

  /// The format the caller intends to write at [path].
  final BackupFormat format;

  ExportTarget copyWith({
    String? path,
    BackupFormat? format,
  }) {
    return ExportTarget(
      path: path ?? this.path,
      format: format ?? this.format,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportTarget && other.path == path && other.format == format;

  @override
  int get hashCode => Object.hash(path, format);

  @override
  String toString() => 'ExportTarget(path: $path, format: $format)';
}

/// Exported backup content produced in memory, ready for the presentation
/// layer to deliver however the platform allows (write to a chosen path on
/// desktop/mobile, or trigger a browser download on web).
///
/// Keeping the bytes platform-neutral lets export work everywhere — including
/// web, where `dart:io` file writing is unavailable.
final class BackupBytes {
  const BackupBytes({
    required this.bytes,
    required this.format,
    required this.suggestedFileName,
    required this.wishCount,
  });

  /// The exported content.
  final List<int> bytes;

  /// The format of [bytes].
  final BackupFormat format;

  /// A sensible default file name (with extension) for a save dialog/download.
  final String suggestedFileName;

  /// Number of Wishes captured in the export snapshot.
  final int wishCount;
}

/// The outcome of a successful export (R11.1–R11.3).
///
/// On failure the service throws a descriptive error instead of returning this
/// (design error-handling table, R11.4); this type always describes a file
/// that was durably written.
final class ExportResult {
  const ExportResult({
    required this.path,
    required this.format,
    required this.byteCount,
    required this.wishCount,
  });

  /// Absolute path of the file that was written.
  final String path;

  /// Format of the written file.
  final BackupFormat format;

  /// Size of the written file in bytes.
  final int byteCount;

  /// Number of Wishes captured in the export snapshot.
  final int wishCount;

  ExportResult copyWith({
    String? path,
    BackupFormat? format,
    int? byteCount,
    int? wishCount,
  }) {
    return ExportResult(
      path: path ?? this.path,
      format: format ?? this.format,
      byteCount: byteCount ?? this.byteCount,
      wishCount: wishCount ?? this.wishCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportResult &&
          other.path == path &&
          other.format == format &&
          other.byteCount == byteCount &&
          other.wishCount == wishCount;

  @override
  int get hashCode => Object.hash(path, format, byteCount, wishCount);

  @override
  String toString() => 'ExportResult(path: $path, format: $format, '
      'byteCount: $byteCount, wishCount: $wishCount)';
}

/// A file selected for import (R12.1).
///
/// Describes the file's [path] and declared [format] in platform-neutral
/// terms. `BackupService.inspect` reads and fully validates the file before
/// any write (R12.2), and `restore` applies it transactionally (R12.1).
final class ImportFile {
  const ImportFile({
    required this.path,
    required this.format,
  });

  /// Absolute path of the file to import.
  final String path;

  /// Declared format of the file to import.
  final BackupFormat format;

  ImportFile copyWith({
    String? path,
    BackupFormat? format,
  }) {
    return ImportFile(
      path: path ?? this.path,
      format: format ?? this.format,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportFile && other.path == path && other.format == format;

  @override
  int get hashCode => Object.hash(path, format);

  @override
  String toString() => 'ImportFile(path: $path, format: $format)';
}

/// The validated summary of an import file produced by
/// `BackupService.inspect` before any write (R12.2).
///
/// A preview means the file parsed and validated cleanly; a malformed or
/// unreadable file is rejected with a descriptive error instead of yielding a
/// preview. The counts let the UI describe what a confirmed restore would
/// replace (R12.3).
final class ImportPreview {
  const ImportPreview({
    required this.format,
    required this.wishCount,
    required this.categoryCount,
    this.schemaVersion,
  });

  /// Format of the inspected file.
  final BackupFormat format;

  /// Number of Wishes the file contains.
  final int wishCount;

  /// Number of distinct categories referenced by the file.
  final int categoryCount;

  /// Schema version declared by the file, when the format carries one
  /// (JSON, R12.4); `null` for formats without an embedded version.
  final int? schemaVersion;

  ImportPreview copyWith({
    BackupFormat? format,
    int? wishCount,
    int? categoryCount,
    int? schemaVersion,
  }) {
    return ImportPreview(
      format: format ?? this.format,
      wishCount: wishCount ?? this.wishCount,
      categoryCount: categoryCount ?? this.categoryCount,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportPreview &&
          other.format == format &&
          other.wishCount == wishCount &&
          other.categoryCount == categoryCount &&
          other.schemaVersion == schemaVersion;

  @override
  int get hashCode =>
      Object.hash(format, wishCount, categoryCount, schemaVersion);

  @override
  String toString() => 'ImportPreview(format: $format, '
      'wishCount: $wishCount, categoryCount: $categoryCount, '
      'schemaVersion: $schemaVersion)';
}
