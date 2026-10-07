/// [SettingsView] — the Settings screen that exposes manual backup (export)
/// and restore (import) controls (design "Settings_View"; R11.1–R11.4,
/// R12.1–R12.3).
///
/// This is a presentation-layer widget. It depends only on the application
/// layer ([backupControllerProvider] from `lib/application/application.dart`)
/// and the Drift-free domain backup value types ([ExportTarget], [ImportFile],
/// [BackupFormat], [ImportPreview]). It never imports Drift or `dart:io`,
/// keeping the layer boundary intact (design "Module boundaries").
///
/// ## Export (R11.1–R11.3)
///
/// Three buttons — Database / JSON / CSV — each open a native "save" dialog
/// via [FilePicker.saveFile] to choose a destination path, then build an
/// [ExportTarget] and call [BackupController.export]. Dismissing the dialog
/// cancels the operation.
///
/// ## Import / restore (R12.1–R12.3)
///
/// The Import button opens a native "open" dialog via [FilePicker.pickFiles],
/// infers the [BackupFormat] from the file extension, builds an [ImportFile]
/// and calls [BackupController.inspect] (read-and-validate only, no write).
/// When the controller reports [BackupImportPreviewReady], a REPLACE
/// confirmation [AlertDialog] describes what the restore would replace
/// (wish/category counts); confirming calls [BackupController.restore] and
/// cancelling calls [BackupController.reset] (R12.3).
///
/// ## Feedback (R11.4, R12.2)
///
/// A progress indicator is shown while a [BackupInProgress] operation is in
/// flight. Success ([BackupExportSuccess] / [BackupRestoreSuccess]) and
/// failure ([BackupError], carrying the service's descriptive message) are
/// surfaced via a [SnackBar]; the controller is reset afterwards so the same
/// operation can be repeated.
library wishable.presentation.views.settings_view;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/application.dart';
import '../../domain/backup.dart';
import '../../theme/app_theme.dart';
import '../account/account_view.dart';
import '../auth/auth_gate.dart';
import '../auth/passcode_setup_view.dart';
import 'export_delivery.dart';

/// The Settings screen exposing backup export and restore import controls.
class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  /// Guards against re-entrantly opening a second REPLACE confirmation dialog
  /// if the provider fires again while one is already visible.
  bool _confirmationVisible = false;

  @override
  Widget build(BuildContext context) {
    // React to backup state transitions for feedback and the REPLACE
    // confirmation. Listening (rather than only watching) lets us drive
    // one-shot UI — SnackBars and dialogs — exactly once per transition.
    ref.listen<BackupState>(backupControllerProvider, (previous, next) {
      _handleStateChange(next);
    });

    final BackupState state = ref.watch(backupControllerProvider);
    final bool busy = state is BackupInProgress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          const _SectionHeader(
            icon: AppIcons.settings,
            title: 'Backup',
            subtitle: 'Export a copy of your Wishes to a file.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: busy ? null : () => _export(BackupFormat.database),
                  icon: const Icon(AppIcons.database),
                  label: const Text('Export database'),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : () => _export(BackupFormat.json),
                  icon: const Icon(AppIcons.json),
                  label: const Text('Export JSON'),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : () => _export(BackupFormat.csv),
                  icon: const Icon(AppIcons.csv),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          const _SectionHeader(
            icon: AppIcons.restore,
            title: 'Restore',
            subtitle:
                'Import a backup file. This replaces all current Wishes after '
                'you confirm.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: busy ? null : _import,
                icon: const Icon(AppIcons.restore),
                label: const Text('Import from file'),
              ),
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Working…'),
                ],
              ),
            ),
          const Divider(height: 32),
          const _SectionHeader(
            icon: Icons.lock_outline,
            title: 'Security',
            subtitle: 'Protect the app on this device with a passcode or '
                'biometrics.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext _) => const PasscodeSetupView(),
                  ),
                ),
                icon: const Icon(Icons.lock_outline),
                label: const Text('App lock'),
              ),
            ),
          ),
          const Divider(height: 32),
          const _SectionHeader(
            icon: Icons.cloud_outlined,
            title: 'Account & sync',
            subtitle: 'Optionally sign in to sync your Wishes across devices. '
                'Wishable works fully offline without an account.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    // Account & sync is sensitive: guard it behind the app
                    // lock so opening it requires unlocking when a passcode is
                    // enrolled and the app is locked.
                    builder: (BuildContext _) =>
                        const LockGuard(child: AccountView()),
                  ),
                ),
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('Account & sync'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Exports the requested [format] (R11.1–R11.3), cross-platform.
  ///
  /// The content is produced in memory by the controller, then handed to the
  /// platform save dialog as `bytes`. Passing bytes is what makes this work on
  /// web (which triggers a download — a save dialog with no bytes returns null
  /// there) and reliably writes the file on desktop/mobile. A cancelled dialog
  /// is a no-op.
  Future<void> _export(BackupFormat format) async {
    final BackupBytes? content =
        await ref.read(backupControllerProvider.notifier).prepareExport(format);
    if (content == null) {
      // prepareExport failed; the controller set a BackupError which the
      // listener surfaces as a SnackBar.
      return;
    }
    try {
      final ExportDeliveryResult result = await deliverExport(
        bytes: content.bytes,
        suggestedFileName: content.suggestedFileName,
        dialogTitle: 'Export ${_formatLabel(format)}',
      );
      if (!mounted) return;
      if (!result.delivered) {
        // User cancelled the folder picker — nothing written.
        return;
      }
      final String where = result.location != null
          ? ' to ${result.location}'
          : ' (${content.suggestedFileName})';
      _showSnackBar(
        'Exported ${content.wishCount} '
        '${content.wishCount == 1 ? 'wishlist' : 'wishlists'}$where.',
      );
    } catch (error) {
      if (mounted) {
        _showSnackBar('Export failed: $error', isError: true);
      }
    }
  }

  /// Prompts for a backup file and, if chosen, inspects it (read-and-validate
  /// only). The REPLACE confirmation is driven later by the resulting
  /// [BackupImportPreviewReady] state (R12.2, R12.3).
  Future<void> _import() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select a backup file',
      type: FileType.any,
    );
    final String? path = result?.files.single.path;
    if (path == null) {
      // User dismissed the dialog or no path is available.
      return;
    }
    final BackupFormat? format = _formatFromPath(path);
    if (format == null) {
      _showSnackBar(
        'Unsupported file type. Choose a .sqlite, .json, or .csv backup.',
        isError: true,
      );
      return;
    }
    final ImportFile file = ImportFile(path: path, format: format);
    await ref.read(backupControllerProvider.notifier).inspect(file);
  }

  /// Routes a new [BackupState] to the appropriate one-shot UI: the REPLACE
  /// confirmation for a ready preview, or a success/error [SnackBar].
  void _handleStateChange(BackupState state) {
    switch (state) {
      case BackupImportPreviewReady():
        _promptRestoreConfirmation(state.preview);
      case BackupExportSuccess(:final ExportResult result):
        _showSnackBar(
          'Exported ${result.wishCount} '
          '${result.wishCount == 1 ? 'Wish' : 'Wishes'} to '
          '${result.path}.',
        );
        ref.read(backupControllerProvider.notifier).reset();
      case BackupRestoreSuccess():
        _showSnackBar('Restore complete. Your Wishes were replaced.');
        ref.read(backupControllerProvider.notifier).reset();
      case BackupError(:final String message):
        _showSnackBar(message, isError: true);
        ref.read(backupControllerProvider.notifier).reset();
      case BackupIdle():
      case BackupInProgress():
        // No one-shot UI for these phases.
        break;
    }
  }

  /// Shows the REPLACE confirmation describing what a restore would replace
  /// (R12.3). Confirming restores; cancelling (or dismissing) resets the
  /// controller so no write occurs.
  Future<void> _promptRestoreConfirmation(ImportPreview preview) async {
    if (_confirmationVisible) {
      return;
    }
    _confirmationVisible = true;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(AppIcons.restore),
          title: const Text('Replace all current data?'),
          content: Text(
            'Importing this ${_formatLabel(preview.format)} will REPLACE all '
            'current Wishes with ${preview.wishCount} '
            '${preview.wishCount == 1 ? 'Wish' : 'Wishes'} across '
            '${preview.categoryCount} '
            '${preview.categoryCount == 1 ? 'category' : 'categories'}.\n\n'
            'This cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace'),
            ),
          ],
        );
      },
    );
    _confirmationVisible = false;

    final BackupController controller =
        ref.read(backupControllerProvider.notifier);
    if (confirmed ?? false) {
      await controller.restore();
    } else {
      // Cancelled or dismissed: abandon the pending preview without writing.
      controller.reset();
    }
  }

  /// Shows a [SnackBar] with [message], tinted as an error when [isError].
  ///
  /// Uses the [State.context] guarded by [State.mounted] so it is safe to call
  /// after an `await`.
  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? colors.errorContainer : null,
        ),
      );
  }

  /// Human-readable name for a [BackupFormat], used in dialogs and messages.
  static String _formatLabel(BackupFormat format) => switch (format) {
        BackupFormat.database => 'database backup',
        BackupFormat.json => 'JSON export',
        BackupFormat.csv => 'CSV export',
      };

  /// Infers a [BackupFormat] from a file [path]'s extension, or `null` when
  /// the extension is not a recognized backup type.
  static BackupFormat? _formatFromPath(String path) {
    final int dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) {
      return null;
    }
    final String ext = path.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'sqlite' || 'db' || 'sqlite3' => BackupFormat.database,
      'json' => BackupFormat.json,
      'csv' => BackupFormat.csv,
      _ => null,
    };
  }
}

/// A labelled section header with a leading icon, used to group the backup and
/// restore controls on the Settings screen.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
