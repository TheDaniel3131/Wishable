/// Persistence for [NotificationSettings] over the Drift Settings key/value
/// table.
///
/// The interface is Drift-free; the Drift-backed implementation stores the
/// settings as a single JSON row under a stable key, mirroring the existing
/// settings-storage approach (one key, stable schema).
library wishable.data.notify.notification_settings_store;

import 'dart:convert';

import '../../domain/notifications.dart';
import '../app_database.dart';

/// Drift-free boundary for loading/saving [NotificationSettings].
abstract interface class NotificationSettingsStore {
  Future<NotificationSettings> load();
  Future<void> save(NotificationSettings settings);
}

/// Drift-backed [NotificationSettingsStore].
final class DriftNotificationSettingsStore
    implements NotificationSettingsStore {
  DriftNotificationSettingsStore(this._db);

  final AppDatabase _db;

  static const String _key = 'notification_settings_v1';

  @override
  Future<NotificationSettings> load() async {
    final SettingRow? row = await (_db.select(_db.settings)
          ..where((t) => t.key.equals(_key)))
        .getSingleOrNull();
    if (row == null) {
      return const NotificationSettings();
    }
    try {
      final Map<String, Object?> map =
          json.decode(row.value) as Map<String, Object?>;
      return NotificationSettings.fromMap(map);
    } catch (_) {
      return const NotificationSettings();
    }
  }

  @override
  Future<void> save(NotificationSettings settings) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: _key,
            value: json.encode(settings.toMap()),
          ),
        );
  }
}
