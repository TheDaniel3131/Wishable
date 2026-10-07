// Feature: wishable, task 14.2 — Widget test for replace-restore confirmation.
//
// **Proves: Requirement 12.3** — "Initiating a restore that replaces data
// prompts for confirmation BEFORE modifying the database."
//
// The import/restore flow in [SettingsView] is confirm-before-write: inspecting
// a file (read-and-validate only, no write) produces a
// [BackupImportPreviewReady] state, which drives a REPLACE confirmation
// [AlertDialog]. Only when the user taps "Replace" does the controller call
// [BackupService.restore] — the single method that mutates the database. Taps
// on "Cancel" abandon the pending preview without any write.
//
// This test exercises that contract end-to-end through the real
// [SettingsView] + [BackupController], substituting only the Drift-backed
// [BackupService] with a recording fake so we can observe exactly when (and
// whether) `restore()` — the write — is invoked:
//
//   Scenario A (cancel): inspect a file, assert the "Replace all current
//   data?" dialog appears and `restore()` has NOT been called; tap Cancel and
//   assert `restore()` is STILL not called (and the controller reset to idle).
//
//   Scenario B (confirm): inspect a file, assert the dialog appears and
//   `restore()` has NOT been called yet; tap Replace and assert `restore()` IS
//   then called — the write happens only after confirmation.
//
// The native file picker cannot run in a widget test, so instead of tapping
// "Import from file" we drive the controller's `inspect()` directly from the
// test. The dialog is driven purely by provider state, not by the picker, so
// this faithfully reproduces what the Import button does on a real device.
library wishable.test.presentation.settings_restore_confirmation_test;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishable/application/application.dart';
import 'package:wishable/data/notify/notify.dart';
import 'package:wishable/data/repositories/backup_service.dart';
import 'package:wishable/domain/backup.dart';
import 'package:wishable/domain/notifications.dart';
import 'package:wishable/presentation/views/settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A canned preview the fake returns from inspect(); its counts feed the
  // confirmation dialog's body text.
  const ImportPreview preview = ImportPreview(
    format: BackupFormat.json,
    wishCount: 3,
    categoryCount: 2,
    schemaVersion: 1,
  );

  const ImportFile file = ImportFile(
    path: '/tmp/wishable-backup.json',
    format: BackupFormat.json,
  );

  // SettingsView renders a notifications section backed by the notification
  // controller, which otherwise reaches the real Drift database (unavailable in
  // a widget test). Override the service with a no-op and the settings store
  // with an in-memory fake so building the view never touches a real DB.
  List<Override> notificationOverrides() => <Override>[
        notificationServiceProvider
            .overrideWithValue(const NoopNotificationService()),
        notificationSettingsStoreProvider
            .overrideWithValue(_FakeNotificationSettingsStore()),
      ];

  Future<_FakeBackupService> pumpSettings(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsView()),
      ),
    );
    return container.read(backupServiceProvider) as _FakeBackupService;
  }

  testWidgets(
    'inspecting a file prompts for confirmation and does NOT restore until '
    'the user confirms; Cancel never writes (R12.3)',
    (WidgetTester tester) async {
      final _FakeBackupService fake = _FakeBackupService(preview);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          backupServiceProvider.overrideWithValue(fake),
          ...notificationOverrides(),
        ],
      );
      addTearDown(container.dispose);

      await pumpSettings(tester, container);

      // Drive the read-and-validate step the Import button performs. This must
      // NOT write — it only produces a preview for the confirmation.
      await container.read(backupControllerProvider.notifier).inspect(file);
      await tester.pumpAndSettle();

      // inspect() was called with our file; restore() (the write) was NOT.
      expect(fake.inspectCalls, <ImportFile>[file],
          reason: 'the file must be read-and-validated before any write');
      expect(fake.restoreCalls, isEmpty,
          reason: 'no write may happen before the user confirms (R12.3)');

      // The REPLACE confirmation is shown, describing what would be replaced.
      expect(find.text('Replace all current data?'), findsOneWidget,
          reason: 'a confirmation must be prompted before modifying data');
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Replace'), findsOneWidget);

      // User cancels — this must abandon the preview WITHOUT writing.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fake.restoreCalls, isEmpty,
          reason: 'cancelling must perform no write (R12.3)');
      expect(find.text('Replace all current data?'), findsNothing,
          reason: 'the confirmation is dismissed on cancel');
      expect(container.read(backupControllerProvider), const BackupIdle(),
          reason: 'cancelling resets the controller to idle');
    },
  );

  testWidgets(
    'confirming the REPLACE prompt is what triggers the database write (R12.3)',
    (WidgetTester tester) async {
      final _FakeBackupService fake = _FakeBackupService(preview);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          backupServiceProvider.overrideWithValue(fake),
          ...notificationOverrides(),
        ],
      );
      addTearDown(container.dispose);

      await pumpSettings(tester, container);

      await container.read(backupControllerProvider.notifier).inspect(file);
      await tester.pumpAndSettle();

      // Confirmation is up and still nothing has been written.
      expect(find.text('Replace all current data?'), findsOneWidget);
      expect(fake.restoreCalls, isEmpty,
          reason: 'the write must not happen until confirmation (R12.3)');

      // User confirms the replace — only now may the write occur.
      await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
      await tester.pumpAndSettle();

      expect(fake.restoreCalls, <ImportFile>[file],
          reason: 'confirming the prompt triggers the restore write (R12.3)');
      expect(find.text('Replace all current data?'), findsNothing,
          reason: 'the confirmation is dismissed on confirm');
    },
  );
}

/// A recording [BackupService] fake.
///
/// [inspect] returns a canned [ImportPreview] and records the file it was asked
/// about; [restore] — the only database write in the import flow — records each
/// invocation so the test can assert exactly when it happens. The export
/// methods are unused by this test and throw if called.
class _FakeBackupService implements BackupService {
  _FakeBackupService(this._preview);

  final ImportPreview _preview;

  /// Files passed to [inspect], in call order.
  final List<ImportFile> inspectCalls = <ImportFile>[];

  /// Files passed to [restore], in call order. A write occurs iff this is
  /// non-empty.
  final List<ImportFile> restoreCalls = <ImportFile>[];

  @override
  Future<ImportPreview> inspect(ImportFile file) async {
    inspectCalls.add(file);
    return _preview;
  }

  @override
  Future<void> restore(ImportFile file) async {
    restoreCalls.add(file);
  }

  @override
  Future<ExportResult> exportDatabase(ExportTarget t) =>
      throw UnimplementedError('export is not exercised by this test');

  @override
  Future<ExportResult> exportJson(ExportTarget t) =>
      throw UnimplementedError('export is not exercised by this test');

  @override
  Future<ExportResult> exportCsv(ExportTarget t) =>
      throw UnimplementedError('export is not exercised by this test');

  @override
  Future<BackupBytes> exportToBytes(BackupFormat format) =>
      throw UnimplementedError('export is not exercised by this test');
}

/// In-memory [NotificationSettingsStore] fake.
///
/// SettingsView's notifications section loads settings through this store; the
/// restore-confirmation flow under test does not touch notifications, so a
/// default (disabled) settings value is all that's needed to let the view
/// build without reaching a real database.
class _FakeNotificationSettingsStore implements NotificationSettingsStore {
  NotificationSettings _settings = const NotificationSettings();

  @override
  Future<NotificationSettings> load() async => _settings;

  @override
  Future<void> save(NotificationSettings settings) async {
    _settings = settings;
  }
}
