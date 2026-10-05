/// Wish-list view controllers (application layer, task 11.2).
///
/// These providers expose the reactive wish lists that back the browsing
/// views: all wishes, each lifecycle status (Active / In-Progress / Completed),
/// and wishes filtered by category. Each one watches the corresponding
/// [WishRepository] stream (via [wishRepositoryProvider]) so the views
/// auto-refresh whenever the database changes (R9.1–R9.4, R6.5), and applies
/// [sortByPriorityHighToLow] so every emitted list is ordered High -> Low
/// (R4.2).
///
/// ## Interface-only / Drift-free (R14.3)
///
/// The providers depend solely on the [WishRepository] interface and the
/// domain types [Wish] and [LifecycleStatus]. No Drift-generated type is
/// referenced, keeping the application layer on the Drift-free side of the
/// data-access seam.
///
/// ## Shape
///
/// Each view is a [StreamProvider] (or [StreamProvider.family] for the
/// per-category view) yielding `AsyncValue<List<Wish>>`, so consuming widgets
/// get loading / error / data states for free and the priority sort is applied
/// lazily to each emission as it arrives.
library wishable.application.controllers.wish_list_controller;

import 'package:riverpod/riverpod.dart';

import '../../data/repositories/priority_sort.dart';
import '../../data/repositories/wish_repository.dart';
import '../../domain/ids.dart';
import '../../domain/lifecycle_status.dart';
import '../../domain/wish.dart';
import '../providers.dart';

/// Watches every Wish, sorted by priority High -> Low (R9.1, R4.2).
///
/// `ref.keepAlive()` holds the underlying Drift stream subscription open even
/// when no widget is currently listening (e.g. while the user is on another
/// tab or a detail route). Returning to the list then shows the cached data
/// instantly instead of re-running the loading state — a lightweight in-memory
/// cache layered over the local database.
final StreamProvider<List<Wish>> allWishesProvider = StreamProvider<List<Wish>>(
  (Ref ref) {
    ref.keepAlive();
    return ref
        .watch(wishRepositoryProvider)
        .watchAll()
        .map(sortByPriorityHighToLow);
  },
  name: 'allWishesProvider',
);

/// Watches Active Wishes, sorted by priority High -> Low (R9.2, R4.2).
final StreamProvider<List<Wish>> activeWishesProvider =
    StreamProvider<List<Wish>>(
  (Ref ref) {
    ref.keepAlive();
    return ref
        .watch(wishRepositoryProvider)
        .watchByStatus(LifecycleStatus.active)
        .map(sortByPriorityHighToLow);
  },
  name: 'activeWishesProvider',
);

/// Watches In-Progress Wishes, sorted by priority High -> Low (R9.3, R4.2).
final StreamProvider<List<Wish>> inProgressWishesProvider =
    StreamProvider<List<Wish>>(
  (Ref ref) {
    ref.keepAlive();
    return ref
        .watch(wishRepositoryProvider)
        .watchByStatus(LifecycleStatus.inProgress)
        .map(sortByPriorityHighToLow);
  },
  name: 'inProgressWishesProvider',
);

/// Watches Completed Wishes, sorted by priority High -> Low (R9.4, R6.5,
/// R4.2).
final StreamProvider<List<Wish>> completedWishesProvider =
    StreamProvider<List<Wish>>(
  (Ref ref) {
    ref.keepAlive();
    return ref
        .watch(wishRepositoryProvider)
        .watchByStatus(LifecycleStatus.completed)
        .map(sortByPriorityHighToLow);
  },
  name: 'completedWishesProvider',
);

/// Watches the Wishes in the category identified by `categoryId`, sorted by
/// priority High -> Low (R3.4, R4.2). Keyed by [CategoryId] so each category
/// view maintains its own subscription.
final StreamProviderFamily<List<Wish>, CategoryId> wishesByCategoryProvider =
    StreamProvider.family<List<Wish>, CategoryId>(
  (Ref ref, CategoryId categoryId) => ref
      .watch(wishRepositoryProvider)
      .watchByCategory(categoryId)
      .map(sortByPriorityHighToLow),
  name: 'wishesByCategoryProvider',
);
