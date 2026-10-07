/// Domain value types for local notifications (reminders + periodic nudge).
///
/// Pure Dart: no Flutter, no plugins. These describe WHAT to notify in
/// platform-neutral terms; the data layer maps them to the platform notifier.
library wishable.domain.notifications;

/// How often the periodic "keep going" nudge fires.
enum NudgeFrequency { off, daily, weekly }

/// User preferences for notifications, persisted in the Settings table.
final class NotificationSettings {
  const NotificationSettings({
    this.enabled = false,
    this.nudgeFrequency = NudgeFrequency.off,
    this.nudgeHour = 9,
    this.nudgeMinute = 0,
  });

  /// Master switch — when false, nothing is scheduled or shown.
  final bool enabled;

  /// Cadence of the periodic active-wishlist nudge.
  final NudgeFrequency nudgeFrequency;

  /// Local hour (0–23) the nudge fires.
  final int nudgeHour;

  /// Local minute (0–59) the nudge fires.
  final int nudgeMinute;

  NotificationSettings copyWith({
    bool? enabled,
    NudgeFrequency? nudgeFrequency,
    int? nudgeHour,
    int? nudgeMinute,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      nudgeFrequency: nudgeFrequency ?? this.nudgeFrequency,
      nudgeHour: nudgeHour ?? this.nudgeHour,
      nudgeMinute: nudgeMinute ?? this.nudgeMinute,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'enabled': enabled,
        'nudgeFrequency': nudgeFrequency.name,
        'nudgeHour': nudgeHour,
        'nudgeMinute': nudgeMinute,
      };

  factory NotificationSettings.fromMap(Map<String, Object?> map) {
    return NotificationSettings(
      enabled: (map['enabled'] as bool?) ?? false,
      nudgeFrequency: NudgeFrequency.values.firstWhere(
        (NudgeFrequency f) => f.name == map['nudgeFrequency'],
        orElse: () => NudgeFrequency.off,
      ),
      nudgeHour: (map['nudgeHour'] as int?) ?? 9,
      nudgeMinute: (map['nudgeMinute'] as int?) ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.enabled == enabled &&
      other.nudgeFrequency == nudgeFrequency &&
      other.nudgeHour == nudgeHour &&
      other.nudgeMinute == nudgeMinute;

  @override
  int get hashCode =>
      Object.hash(enabled, nudgeFrequency, nudgeHour, nudgeMinute);
}

/// A one-off reminder scheduled for a specific Wish at [whenUtc].
final class WishReminder {
  const WishReminder({
    required this.wishId,
    required this.title,
    required this.whenUtc,
  });

  final String wishId;

  /// The wishlist title, shown in the notification body.
  final String title;

  /// When the reminder fires (UTC).
  final DateTime whenUtc;
}
