/// Platform-agnostic database connection opener.
///
/// At compile time, conditional imports select the correct implementation so
/// the rest of the codebase sees a single `openConnection()` regardless of
/// platform (design "Platform strategy for persistence", R13.1):
///
///   - `native.dart`      (dart.library.io)          — [NativeDatabase]
///   - `web.dart`         (dart.library.js_interop)   — [WasmDatabase] (OPFS/IndexedDB)
///   - `unsupported.dart` (fallback)                  — throws [UnsupportedError]
///
/// This isolates R10 (local persistence) behind the data-access layer. Each
/// platform file exposes `QueryExecutor openConnection()`; this file re-exports
/// the selected one so `AppDatabase` can depend on a single symbol.
library wishable.data.connection;

export 'unsupported.dart'
    if (dart.library.io) 'native.dart'
    if (dart.library.js_interop) 'web.dart';
