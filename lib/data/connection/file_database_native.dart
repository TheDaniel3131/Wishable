/// Native implementation of the file-backed database opener seam.
///
/// Selected by the conditional import in `file_database.dart` when `dart:io`
/// is available (Windows, macOS, Linux, Android, iOS). Opens an existing
/// SQLite file as a Drift [QueryExecutor] via [NativeDatabase]. This is the
/// only place outside `connection/native.dart` permitted to reference
/// `package:drift/native.dart`, keeping `dart:ffi` out of the web build.
library wishable.data.connection.file_database_native;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Opens the SQLite database at [path] as a Drift [QueryExecutor].
///
/// Used by the backup service to read an imported `.sqlite` file. The caller
/// owns the returned executor's lifecycle and must close it.
QueryExecutor openFileExecutor(String path) {
  return NativeDatabase(File(path));
}
