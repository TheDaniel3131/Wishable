/// Domain layer — pure Dart. Value objects (Wish, Category, AppSettings), the
/// LifecyclePolicy state machine, validators, and the JSON/CSV serializers.
///
/// Layering discipline (design "Module boundaries"):
///   - MAY depend on: Dart core only.
///   - MUST NOT depend on: Flutter, Drift, dart:io.
///
/// Serializers (JSON/CSV) and validators are added by later tasks (5–6).
library wishable.domain;

export 'app_settings.dart';
export 'backup.dart';
export 'category.dart';
export 'ids.dart';
export 'lifecycle_event.dart';
export 'lifecycle_policy.dart';
export 'lifecycle_status.dart';
export 'priority.dart';
export 'wish.dart';
export 'wish_csv_codec.dart';
export 'wish_image.dart';
export 'wish_input.dart';
export 'wish_json_codec.dart';
export 'wish_validator.dart';
