/// Data-layer notifications barrel.
///
/// Exposes the [NotificationService] interface + no-op, the conditional-import
/// factory, and the [NotificationSettingsStore]. The plugin
/// (`flutter_local_notifications`) is imported ONLY by the native service
/// implementation, never above the data layer or on web.
library wishable.data.notify;

export 'notification_service.dart';
export 'notification_service_factory.dart';
export 'notification_settings_store.dart';
