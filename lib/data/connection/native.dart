/// Native (desktop + mobile) database connection.
///
/// Selected by the conditional import in `connection.dart` when `dart:io` is
/// available (Windows, macOS, Linux, Android, iOS). Opens the SQLite file via
/// [NativeDatabase.createInBackground] on a background isolate so the UI never
/// blocks on database I/O. Recent `sqlite3` bundles SQLite itself, so no extra
/// native libraries are required (design "Platform strategy for persistence").
///
/// Content was rephrased for compliance with licensing restrictions.
library wishable.data.connection.native;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the Wishable database as a file named `wishable.sqlite` under the
/// application documents directory (R10.1). The connection is created lazily on
/// a background isolate.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final Directory documents = await getApplicationDocumentsDirectory();
    final File file = File(p.join(documents.path, 'wishable.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
