/// Fallback database connection for unsupported platforms.
///
/// This is the default target of the conditional import in `connection.dart`.
/// It is overridden by `native.dart` (when `dart:io` is available) or
/// `web.dart` (when `dart:js_interop` is available). If neither library is
/// present, calling [openConnection] throws, since Wishable cannot persist
/// data on such a platform (design "Platform strategy for persistence").
library wishable.data.connection.unsupported;

import 'package:drift/drift.dart';

/// Always throws: no persistence backend is available on this platform.
QueryExecutor openConnection() {
  throw UnsupportedError(
    'No database connection is available on this platform. Wishable requires '
    'either a native (dart:io) or web (dart:js_interop) environment.',
  );
}
