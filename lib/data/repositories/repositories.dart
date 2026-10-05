/// Abstract repository interfaces — the Drift-free data-access boundary
/// (design "Data-Access Layer (repositories)", R14.3).
///
/// These interfaces reference only domain types, so the application and
/// presentation layers can depend on them without ever touching Drift. The
/// Drift-backed implementations live in the data layer and are introduced by
/// tasks 8 and 9.
library wishable.data.repositories;

export 'backup_service.dart';
export 'category_repository.dart';
export 'drift_backup_service.dart';
export 'drift_category_repository.dart';
export 'drift_settings_repository.dart';
export 'drift_wish_repository.dart';
export 'priority_sort.dart';
export 'settings_repository.dart';
export 'wish_repository.dart';
