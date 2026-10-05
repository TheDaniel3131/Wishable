/// Platform-agnostic opener for a database stored at a specific file path.
///
/// The raw-database backup format (export a `.sqlite` file, import/restore from
/// one) is inherently native-only: it requires `dart:io` file access and
/// Drift's `NativeDatabase` (which depends on `dart:ffi`). Pulling
/// `package:drift/native.dart` into the shared data layer would drag `dart:ffi`
/// into the web build and break compilation (`dart:ffi` is unavailable on
/// web).
///
/// To keep the web build clean, this seam is selected at compile time by
/// conditional imports exactly like `connection.dart`:
///
///   - `file_database_native.dart` (dart.library.io) — real [NativeDatabase]
///   - `file_database_web.dart`    (fallback)         — throws [UnsupportedError]
///
/// Each implementation exposes `QueryExecutor openFileExecutor(String path)`;
/// this file re-exports the selected one so the backup service depends on a
/// single symbol without ever importing `package:drift/native.dart` directly.
library wishable.data.connection.file_database;

export 'file_database_web.dart'
    if (dart.library.io) 'file_database_native.dart';
