/// Web export delivery (see `export_delivery.dart`).
///
/// Triggers a browser download of the bytes by creating a Blob, an object URL,
/// and a transient anchor element that is clicked programmatically. Uses the
/// modern `package:web` + `dart:js_interop` APIs (no deprecated `dart:html`).
/// The browser owns the download location, so [ExportDeliveryResult.location]
/// is null.
library wishable.presentation.views.export_delivery_web;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'export_delivery.dart';

/// Downloads [bytes] in the browser as [suggestedFileName].
Future<ExportDeliveryResult> deliverExport({
  required List<int> bytes,
  required String suggestedFileName,
  required String dialogTitle,
}) async {
  final Uint8List data = Uint8List.fromList(bytes);
  // Wrap the bytes in a Blob. The JS Blob constructor takes an array of parts.
  final web.Blob blob = web.Blob(
    <JSUint8Array>[data.toJS].toJS,
    web.BlobPropertyBag(type: 'application/octet-stream'),
  );
  final String url = web.URL.createObjectURL(blob);
  final web.HTMLAnchorElement anchor =
      web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = suggestedFileName
        ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return const ExportDeliveryResult(delivered: true);
}
