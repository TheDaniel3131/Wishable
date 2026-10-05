/// Web database connection.
///
/// Selected by the conditional import in `connection.dart` when `dart:js_interop`
/// is available. Opens the database with [WasmDatabase.open], loading the
/// `sqlite3.wasm` and `drift_worker.js` assets shipped in `web/`. Drift selects
/// the best available browser storage — OPFS when the browser supports it, and
/// IndexedDB otherwise (design "Platform strategy for persistence").
library wishable.data.connection.web;

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Opens the Wishable database in the browser (R10.1). The connection is
/// created lazily so the WASM module and worker are loaded on first use.
///
/// `WasmDatabase.open` negotiates the storage backend automatically, preferring
/// OPFS and falling back to IndexedDB when OPFS is unavailable. The required
/// `sqlite3.wasm` and `drift_worker.js` assets must be present in `web/`.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final WasmDatabaseResult result = await WasmDatabase.open(
      databaseName: 'wishable',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
