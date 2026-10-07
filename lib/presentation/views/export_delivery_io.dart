/// Native (desktop + mobile) export delivery (see `export_delivery.dart`).
///
/// Prompts for a destination folder with `file_picker.getDirectoryPath` — which
/// IS implemented on Windows/macOS/Linux/mobile, unlike `saveFile` — then
/// writes the bytes there with `dart:io`. Returns where the file landed so the
/// UI can report it.
library wishable.presentation.views.export_delivery_io;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'export_delivery.dart';

/// Writes [bytes] to a user-picked folder as [suggestedFileName].
Future<ExportDeliveryResult> deliverExport({
  required List<int> bytes,
  required String suggestedFileName,
  required String dialogTitle,
}) async {
  final String? dir = await FilePicker.platform.getDirectoryPath(
    dialogTitle: dialogTitle,
  );
  if (dir == null) {
    // User cancelled the folder picker.
    return const ExportDeliveryResult(delivered: false);
  }

  // Avoid clobbering an existing file by appending (1), (2), … if needed.
  String target = p.join(dir, suggestedFileName);
  if (await File(target).exists()) {
    final String stem = p.basenameWithoutExtension(suggestedFileName);
    final String ext = p.extension(suggestedFileName);
    int n = 1;
    while (await File(p.join(dir, '$stem ($n)$ext')).exists()) {
      n++;
    }
    target = p.join(dir, '$stem ($n)$ext');
  }

  await File(target).writeAsBytes(bytes, flush: true);
  return ExportDeliveryResult(delivered: true, location: target);
}
