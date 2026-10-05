/// The [SettingsRepository] abstract interface (design "Data-Access Layer
/// (repositories)").
///
/// Drift-free seam for application settings persistence: the layers above
/// depend only on this interface, a Drift-backed class (task 8.4) implements
/// it over the Settings key/value table, and the interface references only the
/// domain [AppSettings] type so no Drift type leaks across the boundary
/// (R14.3).
library wishable.data.repositories.settings_repository;

import '../../domain/app_settings.dart';

/// Drift-free persistence boundary for [AppSettings].
abstract interface class SettingsRepository {
  /// Loads the persisted settings, returning [AppSettings.defaults] when none
  /// have been saved (R10.1).
  Future<AppSettings> load();

  /// Persists [settings] locally.
  Future<void> save(AppSettings settings);
}
