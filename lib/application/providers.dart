/// Riverpod providers for the Drift [AppDatabase] and the data-access
/// repositories / backup service (task 11.1).
///
/// ## Interface-only exposure (R14.3)
///
/// Every repository/service provider is typed as its ABSTRACT interface
/// ([WishRepository], [CategoryRepository], [SettingsRepository],
/// [BackupService]). Consumers in the application and presentation layers that
/// read these providers therefore depend only on the Drift-free interfaces and
/// never on the concrete `Drift*` classes. The concrete Drift-backed types
/// ([DriftWishRepository], [DriftCategoryRepository],
/// [DriftSettingsRepository], [DriftBackupService]) appear ONLY inside the
/// provider bodies here, where the data layer is wired together.
///
/// The one exception is [appDatabaseProvider], which must expose the concrete
/// [AppDatabase] because the repositories are constructed over it. It is the
/// single composition-root seam where the Drift database is instantiated; no
/// consumer above the data layer needs to read it directly.
///
/// ## Lifecycle
///
/// [appDatabaseProvider] constructs a single [AppDatabase] over the platform
/// connection opener and closes it when the provider is disposed, so the
/// SQLite connection is released cleanly on teardown. The repository and
/// backup providers are plain derivations that `watch` the database and each
/// other, so Riverpod rebuilds them if the database is ever recreated.
library wishable.application.providers;

import 'package:riverpod/riverpod.dart';

import '../data/data.dart';

/// Provides the application's single Drift [AppDatabase].
///
/// Constructs [AppDatabase] with its default constructor, which opens the
/// platform connection via the conditional-import opener. The database is
/// closed when the provider is disposed so the underlying connection is
/// released.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>(
  (Ref ref) {
    final AppDatabase db = AppDatabase();
    ref.onDispose(db.close);
    return db;
  },
  name: 'appDatabaseProvider',
);

/// Provides the [WishRepository], backed by [DriftWishRepository] over the
/// shared [AppDatabase]. Typed as the interface so consumers never see Drift
/// (R14.3).
final Provider<WishRepository> wishRepositoryProvider =
    Provider<WishRepository>(
  (Ref ref) => DriftWishRepository(ref.watch(appDatabaseProvider)),
  name: 'wishRepositoryProvider',
);

/// Provides the [CategoryRepository], backed by [DriftCategoryRepository] over
/// the shared [AppDatabase]. Typed as the interface so consumers never see
/// Drift (R14.3).
final Provider<CategoryRepository> categoryRepositoryProvider =
    Provider<CategoryRepository>(
  (Ref ref) => DriftCategoryRepository(ref.watch(appDatabaseProvider)),
  name: 'categoryRepositoryProvider',
);

/// Provides the [WishImageRepository], backed by [DriftWishImageRepository]
/// over the shared [AppDatabase]. Typed as the interface so consumers never
/// see Drift (R14.3).
final Provider<WishImageRepository> wishImageRepositoryProvider =
    Provider<WishImageRepository>(
  (Ref ref) => DriftWishImageRepository(ref.watch(appDatabaseProvider)),
  name: 'wishImageRepositoryProvider',
);

/// Provides the [SettingsRepository], backed by [DriftSettingsRepository] over
/// the shared [AppDatabase]. Typed as the interface so consumers never see
/// Drift (R14.3).
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
  (Ref ref) => DriftSettingsRepository(ref.watch(appDatabaseProvider)),
  name: 'settingsRepositoryProvider',
);

/// Provides the [BackupService], backed by [DriftBackupService] over the
/// shared [AppDatabase] and the wish/category repositories. Typed as the
/// interface so consumers never see Drift (R14.3).
final Provider<BackupService> backupServiceProvider = Provider<BackupService>(
  (Ref ref) => DriftBackupService(
    ref.watch(appDatabaseProvider),
    wishRepository: ref.watch(wishRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
  ),
  name: 'backupServiceProvider',
);
