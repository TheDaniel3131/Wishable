/// Native factory: builds the real [LocalNotificationService]. Selected on
/// `dart.library.io` (Android/iOS/macOS/Linux/Windows).
library wishable.data.notify.notification_service_factory_io;

import 'local_notification_service.dart';
import 'notification_service.dart';

NotificationService createNotificationService() => LocalNotificationService();
