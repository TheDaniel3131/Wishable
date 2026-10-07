/// [NotificationController] — view-model for local notifications.
///
/// Wraps the Drift-free [NotificationService] and [NotificationSettingsStore]
/// interfaces; never imports the plugin. Exposes the current
/// [NotificationSettings] and the actions the UI drives: enable/disable, set
/// the periodic nudge cadence/time, request permission, and schedule/cancel
/// per-wishlist reminders. Whenever settings or the active-wishlist count
/// change, it reschedules the nudge so its body reflects the live count.
library wishable.application.controllers.notification_controller;

import 'package:riverpod/riverpod.dart';

import '../../data/notify/notification_service.dart';
import '../../data/notify/notification_service_factory.dart';
import '../../data/notify/notification_settings_store.dart';
import '../../domain/lifecycle_status.dart';
import '../../domain/notifications.dart';
import '../../domain/wish.dart';
import '../providers.dart';

/// The platform notification service (real on native, no-op on web).
final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>(
  (Ref ref) => createNotificationService(),
  name: 'notificationServiceProvider',
);

/// Persistence for the user's notification preferences.
final Provider<NotificationSettingsStore> notificationSettingsStoreProvider =
    Provider<NotificationSettingsStore>(
  (Ref ref) => DriftNotificationSettingsStore(ref.watch(appDatabaseProvider)),
  name: 'notificationSettingsStoreProvider',
);

/// Controller exposing [NotificationSettings] and notification actions.
final class NotificationController extends AsyncNotifier<NotificationSettings> {
  NotificationService get _service => ref.read(notificationServiceProvider);
  NotificationSettingsStore get _store =>
      ref.read(notificationSettingsStoreProvider);

  @override
  Future<NotificationSettings> build() async {
    final NotificationSettings settings = await _store.load();
    if (settings.enabled && _service.isSupported) {
      await _service.initialize();
      await _rescheduleNudge(settings);
    }
    return settings;
  }

  /// Whether the platform can deliver notifications at all.
  bool get isSupported => _service.isSupported;

  /// Enables notifications: requests OS permission, persists, and schedules the
  /// nudge. Returns false if permission was denied or the platform is
  /// unsupported (state is left disabled).
  Future<bool> enable() async {
    if (!_service.isSupported) return false;
    await _service.initialize();
    final bool granted = await _service.requestPermission();
    if (!granted) return false;
    final NotificationSettings next =
        (state.value ?? const NotificationSettings()).copyWith(enabled: true);
    await _persistAndApply(next);
    return true;
  }

  /// Disables notifications: cancels everything and persists the off state.
  Future<void> disable() async {
    await _service.cancelAll();
    final NotificationSettings next =
        (state.value ?? const NotificationSettings()).copyWith(enabled: false);
    await _store.save(next);
    state = AsyncData(next);
  }

  /// Updates the periodic nudge cadence and reschedules.
  Future<void> setNudge(NudgeFrequency frequency, {int? hour, int? minute}) async {
    final NotificationSettings current =
        state.value ?? const NotificationSettings();
    final NotificationSettings next = current.copyWith(
      nudgeFrequency: frequency,
      nudgeHour: hour ?? current.nudgeHour,
      nudgeMinute: minute ?? current.nudgeMinute,
    );
    await _persistAndApply(next);
  }

  /// Schedules a reminder for a specific wishlist (no-op if notifications are
  /// disabled/unsupported).
  Future<void> scheduleReminder(Wish wish, DateTime whenUtc) async {
    final NotificationSettings s = state.value ?? const NotificationSettings();
    if (!s.enabled || !_service.isSupported) return;
    await _service.initialize();
    await _service.scheduleReminder(
      WishReminder(wishId: wish.id, title: wish.title, whenUtc: whenUtc),
    );
  }

  /// Cancels a wishlist's reminder.
  Future<void> cancelReminder(String wishId) =>
      _service.cancelReminder(wishId);

  /// Recomputes the active-wishlist count and reschedules the nudge. Call after
  /// wishlists change so the nudge body stays accurate.
  Future<void> refreshNudgeCount() async {
    final NotificationSettings s = state.value ?? const NotificationSettings();
    if (!s.enabled || !_service.isSupported) return;
    await _rescheduleNudge(s);
  }

  Future<void> _persistAndApply(NotificationSettings next) async {
    await _store.save(next);
    state = AsyncData(next);
    if (next.enabled && _service.isSupported) {
      await _rescheduleNudge(next);
    } else {
      await _service.cancelAll();
    }
  }

  /// Reschedules the periodic nudge with a fresh active/in-progress count.
  Future<void> _rescheduleNudge(NotificationSettings settings) async {
    final int count = await _activeCount();
    await _service.scheduleNudge(settings, count);
  }

  /// Counts wishlists that are Active or In-progress (the "still going" set).
  Future<int> _activeCount() async {
    final List<Wish> all = await ref.read(wishRepositoryProvider).getAll();
    return all
        .where((Wish w) =>
            w.status == LifecycleStatus.active ||
            w.status == LifecycleStatus.inProgress)
        .length;
  }
}

/// Provides the [NotificationController].
final AsyncNotifierProvider<NotificationController, NotificationSettings>
    notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, NotificationSettings>(
  NotificationController.new,
  name: 'notificationControllerProvider',
);
