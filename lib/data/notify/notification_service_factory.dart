/// Platform-agnostic constructor for the [NotificationService].
///
/// Conditional imports pick the implementation at compile time, like
/// `data/connection/`:
///   - `notification_service_factory_io.dart`  (dart.library.io) — the real
///     `flutter_local_notifications` adapter (Android/iOS/macOS/Linux/Windows).
///   - `notification_service_factory_web.dart` (fallback) — a no-op, since the
///     plugin does not support web.
///
/// Both expose `NotificationService createNotificationService()`.
library wishable.data.notify.notification_service_factory;

export 'notification_service_factory_web.dart'
    if (dart.library.io) 'notification_service_factory_io.dart';
