/// The [AppSettings] domain value object.
///
/// Application configuration persisted locally (design R10.1). The data layer
/// stores settings as key/value rows in the Drift `Settings` table and maps
/// them to and from this immutable value object through `SettingsRepository`
/// (task 8.4). V1 keeps the surface small; new settings can be added as
/// fields here and mapped in the repository without changing the storage
/// shape.
///
/// Pure Dart: no Flutter, Drift, or dart:io dependencies. Immutable and
/// compared by value.
library wishable.domain.app_settings;

/// How the application should resolve its light/dark appearance.
///
/// Independent of Flutter's `ThemeMode` so the domain layer stays free of any
/// Flutter dependency; the presentation layer maps this to the framework type.
enum ThemePreference {
  system,
  light,
  dark,
}

/// Immutable application settings.
///
/// Two instances are equal when every field matches.
final class AppSettings {
  const AppSettings({
    this.themePreference = ThemePreference.system,
  });

  /// The default settings used before the user has saved any preference, and
  /// on a fresh installation (R10.1).
  factory AppSettings.defaults() => const AppSettings();

  /// Preferred light/dark appearance.
  final ThemePreference themePreference;

  /// Returns a copy of these settings with the given fields replaced.
  ///
  /// Omitted fields retain their current value.
  AppSettings copyWith({
    ThemePreference? themePreference,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings && other.themePreference == themePreference;

  @override
  int get hashCode => themePreference.hashCode;

  @override
  String toString() => 'AppSettings(themePreference: $themePreference)';
}
