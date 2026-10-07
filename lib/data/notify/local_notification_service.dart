/// [LocalNotificationService] — the `flutter_local_notifications` adapter.
///
/// The ONLY notification file that imports the plugin. Supports Android, iOS,
/// macOS, Linux, and Windows; the conditional-import factory routes web to the
/// [NoopNotificationService] instead, so this file is never loaded on web.
///
/// Scheduling uses the `timezone` package (required by the plugin for zoned
/// scheduling). Notification ids are stable so a reschedule replaces rather
/// than duplicates: the periodic nudge uses a fixed id; a reminder derives its
/// id deterministically from the wish id.
library wishable.data.notify.local_notification_service;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/notifications.dart';
import 'notification_service.dart';

final class LocalNotificationService implements NotificationService {
  LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// Fixed notification id for the periodic nudge.
  static const int _nudgeId = 1;

  /// Android notification channel for Wishable reminders.
  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'wishable_reminders',
    'Wishable reminders',
    channelDescription: 'Reminders and nudges about your wishlists',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
    linux: LinuxNotificationDetails(),
  );

  @override
  bool get isSupported => true;

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(tz.local.name));
    } catch (_) {
      // Fall back to UTC if the local zone can't be resolved.
    }

    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
    );
    _initialized = await _plugin.initialize(settings) ?? true;
    return _initialized;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    // Android 13+.
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final bool? granted = await android.requestNotificationsPermission();
      return granted ?? true;
    }
    // iOS / macOS.
    final IOSFlutterLocalNotificationsPlugin? ios =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final bool? granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    final MacOSFlutterLocalNotificationsPlugin? macos =
        _plugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
    if (macos != null) {
      final bool? granted = await macos.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    // Linux / Windows need no explicit runtime grant.
    return true;
  }

  @override
  Future<void> scheduleNudge(
      NotificationSettings settings, int activeCount) async {
    await initialize();
    await _plugin.cancel(_nudgeId);
    if (!settings.enabled ||
        settings.nudgeFrequency == NudgeFrequency.off ||
        activeCount <= 0) {
      return;
    }

    final tz.TZDateTime first = _nextInstanceOf(
      settings.nudgeHour,
      settings.nudgeMinute,
    );
    final DateTimeComponents components =
        settings.nudgeFrequency == NudgeFrequency.weekly
            ? DateTimeComponents.dayOfWeekAndTime
            : DateTimeComponents.time;

    final String body = activeCount == 1
        ? 'You have 1 wishlist in progress. Keep going!'
        : 'You have $activeCount wishlists in progress. Keep going!';

    await _plugin.zonedSchedule(
      _nudgeId,
      'Wishable',
      body,
      first,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: components,
    );
  }

  @override
  Future<void> scheduleReminder(WishReminder reminder) async {
    await initialize();
    final tz.TZDateTime when =
        tz.TZDateTime.from(reminder.whenUtc.toUtc(), tz.local);
    // Only schedule future reminders.
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }
    await _plugin.zonedSchedule(
      _reminderId(reminder.wishId),
      'Wishlist reminder',
      reminder.title,
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancelReminder(String wishId) =>
      _plugin.cancel(_reminderId(wishId));

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  /// Next occurrence of [hour]:[minute] in local time, today or tomorrow.
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Deterministic, stable, positive notification id derived from [wishId], in
  /// a range that won't collide with [_nudgeId].
  static int _reminderId(String wishId) {
    final int hash = wishId.hashCode & 0x7fffffff;
    return 1000 + (hash % 1000000000);
  }
}
