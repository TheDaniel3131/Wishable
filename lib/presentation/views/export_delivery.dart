/// Platform-agnostic delivery of exported backup bytes to a file.
///
/// `file_picker`'s `saveFile` is unreliable across targets (it throws
/// `UnimplementedError` on Windows desktop in the bundled version, and cannot
/// write a path on web), so export does NOT use it. Instead this seam selects
/// a platform-appropriate delivery at compile time, exactly like
/// `data/connection/`:
///
///   - `export_delivery_io.dart`  (dart.library.io)         — writes the bytes
///     to a folder the user picks (via `file_picker.getDirectoryPath`, which is
///     implemented on desktop/mobile) using `dart:io`.
///   - `export_delivery_web.dart` (dart.library.js_interop)  — triggers a
///     browser download of the bytes.
///
/// Each implementation exposes `Future<ExportDeliveryResult> deliverExport(...)`.
library wishable.presentation.views.export_delivery;

export 'export_delivery_io.dart'
    if (dart.library.js_interop) 'export_delivery_web.dart';

/// The outcome of delivering an export.
class ExportDeliveryResult {
  const ExportDeliveryResult({required this.delivered, this.location});

  /// Whether the file was delivered (false = user cancelled the folder picker).
  final bool delivered;

  /// Where it landed, when known (a file path on desktop/mobile). On web this
  /// is null because the browser owns the download location.
  final String? location;
}
