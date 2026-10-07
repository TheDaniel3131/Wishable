/// Data-access layer — the ONLY layer permitted to reference Drift types
/// (design R14.3). Holds the Drift `AppDatabase`, the repository
/// implementations, and the BackupService.
///
/// Layering discipline (design "Module boundaries"):
///   - MAY depend on: Domain, Drift, file I/O.
///   - MUST NOT depend on: Presentation, Application.
///
/// The repositories and BackupService are added by later tasks (8, 9).
library wishable.data;

export 'app_database.dart';
export 'auth/auth.dart';
export 'notify/notify.dart';
export 'repositories/repositories.dart';
export 'tables.dart';
