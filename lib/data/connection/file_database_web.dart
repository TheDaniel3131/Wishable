/// Web (and any non-`dart:io`) fallback for the file-backed database opener.
///
/// This is the default target of the conditional import in
/// `file_database.dart`. The raw-database backup format reads a `.sqlite` file
/// off the local filesystem, which the browser sandbox does not expose, so
/// opening a file-backed database is not supported on web. Callers should use
/// the JSON or CSV backup formats instead, which work on every platform.
library wishable.data.connection.file_database_web;

import 'package:drift/drift.dart';

/// Always throws: a file-backed database cannot be opened on this platform.
///
/// On web the raw-database backup format is unavailable; use JSON or CSV.
QueryExecutor openFileExecutor(String path) {
  throw UnsupportedError(
    'Opening a database file is not supported on this platform. '
    'The raw-database backup format is native-only; use the JSON or CSV '
    'format on web.',
  );
}
