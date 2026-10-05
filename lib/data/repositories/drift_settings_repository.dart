/// The Drift-backed [SettingsRepository] implementation (task 8.4).
///
/// Persists [AppSettings] as simple key/value rows in the Drift `Settings`
/// table (R10.1). This file lives in the data-access layer — the only layer
/// permitted to reference Drift types (R14.3) — so no Drift type leaks across
/// the [SettingsRepository] boundary; callers above depend only on the
/// interface and the domain [AppSettings] value object.
///
/// Storage shape: one row per setting field. Each [AppSettings] field maps to
/// a stable string key and a stable string value token, so the schema never
/// changes as new settings are added — a new field becomes a new key here.
library wishable.data.repositories.drift_settings_repository;

import 'package:drift/drift.dart';

import '../../domain/app_settings.dart';
import '../app_database.dart';
import 'settings_repository.dart';

/// Stable storage key for the theme-preference setting.
///
/// The key is independent of the enum/field name so renaming code never
/// changes the persisted schema.
const String _kThemePreferenceKey = 'theme_preference';

/// Stable string tokens for [ThemePreference].
///
/// Mapping by explicit token (rather than `enum.name` or `enum.index`) keeps
/// persistence stable if the enum is reordered or its members are renamed.
const Map<ThemePreference, String> _themePreferenceToToken =
    <ThemePreference, String>{
  ThemePreference.system: 'system',
  ThemePreference.light: 'light',
  ThemePreference.dark: 'dark',
};

/// Reverse of [_themePreferenceToToken], used when reading rows back.
final Map<String, ThemePreference> _tokenToThemePreference =
    <String, ThemePreference>{
  for (final MapEntry<ThemePreference, String> entry
      in _themePreferenceToToken.entries)
    entry.value: entry.key,
};

/// Drift-backed persistence for [AppSettings] over the `Settings` key/value
/// table.
final class DriftSettingsRepository implements SettingsRepository {
  /// Creates a repository backed by [_db].
  DriftSettingsRepository(this._db);

  final AppDatabase _db;

  /// Loads the persisted settings, returning [AppSettings.defaults] when no
  /// rows exist (R10.1).
  ///
  /// Reads every key/value row once, then folds the recognised keys into an
  /// [AppSettings]. Unknown keys and unparseable values are ignored so a
  /// stored value from a newer or corrupted write falls back to the default
  /// for that field rather than throwing.
  @override
  Future<AppSettings> load() async {
    final List<SettingRow> rows = await _db.select(_db.settings).get();
    if (rows.isEmpty) {
      return AppSettings.defaults();
    }

    final Map<String, String> values = <String, String>{
      for (final SettingRow row in rows) row.key: row.value,
    };

    AppSettings settings = AppSettings.defaults();

    final String? themeToken = values[_kThemePreferenceKey];
    if (themeToken != null) {
      final ThemePreference? preference = _tokenToThemePreference[themeToken];
      if (preference != null) {
        settings = settings.copyWith(themePreference: preference);
      }
    }

    return settings;
  }

  /// Persists [settings] by upserting one key/value row per field (R10.1).
  ///
  /// Each field is written through `insertOnConflictUpdate` so a save replaces
  /// the existing value for that key without disturbing other keys.
  @override
  Future<void> save(AppSettings settings) async {
    await _db.batch((Batch batch) {
      batch.insertAllOnConflictUpdate(
        _db.settings,
        <SettingsCompanion>[
          SettingsCompanion.insert(
            key: _kThemePreferenceKey,
            value: _themePreferenceToToken[settings.themePreference]!,
          ),
        ],
      );
    });
  }
}
