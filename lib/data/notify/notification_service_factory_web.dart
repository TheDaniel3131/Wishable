/// Web factory: returns the no-op [NotificationService] since
/// `flutter_local_notifications` does not support web. Selected as the
/// fallback when `dart:io` is unavailable.
library wishable.data.notify.notification_service_factory_web;

import 'notification_service.dart';

NotificationService createNotificationService() =>
    const NoopNotificationService();
