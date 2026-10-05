/// [BackupController] — the application-layer view-model that drives manual
/// backup export and import/restore (design "Application Layer
/// (controllers / view-models)", task 11.6).
///
/// This controller sits above the Drift-free [BackupService] interface (read
/// from [backupServiceProvider]) and references only the domain backup value
/// types ([ExportTarget], [ExportResult], [ImportFile], [ImportPreview]). It
/// never imports Drift or the concrete `DriftBackupService`, so the
/// application layer stays Drift-free (R14.3).
///
/// ## Export (R11.1–R11.3)
///
/// [export] dispatches on the [ExportTarget.format] to the matching service
/// method (`exportDatabase` / `exportJson` / `exportCsv`) and surfaces the
/// resulting [ExportResult] as success state.
///
/// ## Import / restore (R12.1, R12.3)
///
/// Import is a two-step, confirm-before-write flow:
///
///   1. [inspect] calls [BackupService.inspect], which reads and fully
///      validates the file WITHOUT writing (R12.2), and exposes the resulting
///      [ImportPreview] as state so the UI can show a REPLACE confirmation
///      describing what a restore would replace (R12.3).
///   2. Only once the user confirms does [restore] call
///      [BackupService.restore], which applies the replacement atomically
///      (R12.1).
///
/// ## Descriptive errors (R11.4, R12.2)
///
/// Export and import failures (surfaced by the service as
/// `BackupExportException` / `BackupImportException`) are caught here and
/// turned into [BackupError] state carrying the exception's descriptive
/// message, so the UI can display it rather than the controller throwing an
/// uncaught error. To keep the application layer Drift-free, the exception
/// types are caught by their base [Object] and reduced to a message string —
/// the concrete Drift-backed exception classes are never imported.
library wishable.application.controllers.backup_controller;

import 'package:riverpod/riverpod.dart';

import '../../data/repositories/backup_service.dart';
import '../../domain/backup.dart';
import '../providers.dart';

/// The state exposed by [BackupController].
///
/// A sealed hierarchy so the UI can exhaustively switch over the current
/// phase of a backup operation. Every variant is immutable and compared by
/// value.
sealed class BackupState {
  const BackupState();
}

/// No backup operation has run (or the last outcome has been cleared).
final class BackupIdle extends BackupState {
  const BackupIdle();

  @override
  bool operator ==(Object other) => other is BackupIdle;

  @override
  int get hashCode => (BackupIdle).hashCode;

  @override
  String toString() => 'BackupIdle()';
}

/// An export or import/restore operation is in flight.
final class BackupInProgress extends BackupState {
  const BackupInProgress();

  @override
  bool operator ==(Object other) => other is BackupInProgress;

  @override
  int get hashCode => (BackupInProgress).hashCode;

  @override
  String toString() => 'BackupInProgress()';
}

/// An export completed; carries the [ExportResult] so the UI can report the
/// written file (R11.1–R11.3).
final class BackupExportSuccess extends BackupState {
  const BackupExportSuccess(this.result);

  /// The outcome of the successful export.
  final ExportResult result;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupExportSuccess && other.result == result;

  @override
  int get hashCode => result.hashCode;

  @override
  String toString() => 'BackupExportSuccess($result)';
}

/// An import file was inspected and validated without writing; carries the
/// [ImportPreview] so the UI can show a REPLACE confirmation (R12.2, R12.3).
///
/// Holds the [file] that produced the preview so [BackupController.restore]
/// can apply it on confirmation without the UI having to re-supply it.
final class BackupImportPreviewReady extends BackupState {
  const BackupImportPreviewReady({
    required this.file,
    required this.preview,
  });

  /// The inspected file, carried forward for a confirmed restore.
  final ImportFile file;

  /// The validated summary of [file].
  final ImportPreview preview;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupImportPreviewReady &&
          other.file == file &&
          other.preview == preview;

  @override
  int get hashCode => Object.hash(file, preview);

  @override
  String toString() =>
      'BackupImportPreviewReady(file: $file, preview: $preview)';
}

/// A confirmed restore completed; the database now reflects the imported file
/// (R12.1).
final class BackupRestoreSuccess extends BackupState {
  const BackupRestoreSuccess();

  @override
  bool operator ==(Object other) => other is BackupRestoreSuccess;

  @override
  int get hashCode => (BackupRestoreSuccess).hashCode;

  @override
  String toString() => 'BackupRestoreSuccess()';
}

/// An export, inspect, or restore failed; carries the service's descriptive
/// [message] for the UI to display (R11.4, R12.2).
final class BackupError extends BackupState {
  const BackupError(this.message);

  /// The descriptive failure message surfaced from the backup service.
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupError && other.message == message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'BackupError($message)';
}

/// Drives [BackupService] for export and the confirm-before-write
/// import/restore flow, exposing the outcome as [BackupState].
final class BackupController extends Notifier<BackupState> {
  @override
  BackupState build() => const BackupIdle();

  BackupService get _service => ref.read(backupServiceProvider);

  /// Exports the current data to [target], dispatching on
  /// [ExportTarget.format] to the matching service method (R11.1–R11.3).
  ///
  /// On success the state becomes [BackupExportSuccess]; on failure it becomes
  /// [BackupError] with the service's descriptive message rather than throwing
  /// (R11.4).
  Future<void> export(ExportTarget target) async {
    state = const BackupInProgress();
    try {
      final ExportResult result = switch (target.format) {
        BackupFormat.database => await _service.exportDatabase(target),
        BackupFormat.json => await _service.exportJson(target),
        BackupFormat.csv => await _service.exportCsv(target),
      };
      state = BackupExportSuccess(result);
    } catch (error) {
      state = BackupError(_messageOf(error));
    }
  }

  /// Inspects [file] without writing and exposes the validated
  /// [ImportPreview] as [BackupImportPreviewReady] so the UI can show a
  /// REPLACE confirmation (R12.2, R12.3).
  ///
  /// A malformed or unreadable file yields [BackupError] with the service's
  /// descriptive message and performs no write (R12.2).
  Future<void> inspect(ImportFile file) async {
    state = const BackupInProgress();
    try {
      final ImportPreview preview = await _service.inspect(file);
      state = BackupImportPreviewReady(file: file, preview: preview);
    } catch (error) {
      state = BackupError(_messageOf(error));
    }
  }

  /// Applies a previously inspected import after the user confirms the
  /// replace, restoring the database atomically (R12.1).
  ///
  /// Only valid once a preview is ready: callers must have an outstanding
  /// [BackupImportPreviewReady] state (produced by [inspect]). If no preview
  /// is pending the call is a no-op guarded by [BackupError], which keeps the
  /// confirm-before-write contract (R12.3) explicit. On success the state
  /// becomes [BackupRestoreSuccess]; on failure [BackupError] with the
  /// service's descriptive message (R12.2).
  Future<void> restore() async {
    final BackupState current = state;
    if (current is! BackupImportPreviewReady) {
      state = const BackupError(
        'No import has been inspected; inspect a file before restoring.',
      );
      return;
    }
    final ImportFile file = current.file;
    state = const BackupInProgress();
    try {
      await _service.restore(file);
      state = const BackupRestoreSuccess();
    } catch (error) {
      state = BackupError(_messageOf(error));
    }
  }

  /// Clears the last outcome back to [BackupIdle], e.g. after the UI has
  /// shown a success/error message or the user cancels a pending preview.
  void reset() {
    state = const BackupIdle();
  }

  /// Reduces any thrown error to a descriptive message without importing the
  /// concrete Drift-backed exception types. `BackupExportException` and
  /// `BackupImportException` both carry their detail in `toString()`, so the
  /// string form is the descriptive message the UI shows (R11.4, R12.2).
  String _messageOf(Object error) => error.toString();
}

/// Provides the [BackupController] and its [BackupState].
final NotifierProvider<BackupController, BackupState> backupControllerProvider =
    NotifierProvider<BackupController, BackupState>(
  BackupController.new,
  name: 'backupControllerProvider',
);
