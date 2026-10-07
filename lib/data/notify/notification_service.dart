/// The [NotificationService] abstract interface — a plugin-free boundary for
/// local notifications.
///
/// The application/presentation layers depend only on this interface and the
/// domain notification types; the concrete platform implementation (behind the
/// conditional-import seam in `notification_service_factory.dart`) is the only
/// code that imports `flutter_local_notifications`. On platforms without
/// support (web) the factory returns a no-op implementation, so callers never
/// branch on platform.
library wishable.data.notify.notification_service;

import '../../domain/notifications.dart';

/// Schedules and shows local notifications (reminders + periodic nudge).
abstract interface class NotificationService {
  /// Prepares the platform plugin (timezones, channels). Safe to call more
  /// than once. Returns false when notifications are unsupported here.
  Future<bool> initialize();

  /// Requests the OS notification permission. Returns whether it is granted
  /// (true on platforms that need no explicit grant; false when unsupported).
  Future<bool> requestPermission();

  /// Schedules (or reschedules) the periodic "keep going" nudge per [settings],
  /// whose body mentions [activeCount] active/in-progress wishlists. Cancels
  /// the nudge when disabled or frequency is off.
  Future<void> scheduleNudge(NotificationSettings settings, int activeCount);

  /// Schedules a one-off reminder for a specific wishlist.
  Future<void> scheduleReminder(WishReminder reminder);

  /// Cancels a previously scheduled reminder for [wishId].
  Future<void> cancelReminder(String wishId);

  /// Cancels every scheduled notification (e.g. when the user disables
  /// notifications entirely).
  Future<void> cancelAll();

  /// Whether this platform can deliver local notifications at all.
  bool get isSupported;
}

/// A no-op [NotificationService] used on unsupported platforms (web) or when
/// the user has notifications off. Every method is a safe no-op so callers need
/// no platform checks.
final class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<bool> initialize() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleNudge(NotificationSettings settings, int activeCount) async {}

  @override
  Future<void> scheduleReminder(WishReminder reminder) async {}

  @override
  Future<void> cancelReminder(String wishId) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  bool get isSupported => false;
}
