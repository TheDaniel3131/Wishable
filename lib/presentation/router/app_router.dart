/// GoRouter configuration for Wishable's navigation (task 12.1).
///
/// ## Structure (design "Navigation structure (GoRouter)")
///
/// A single [StatefulShellRoute.indexedStack] hosts the five top-level
/// destinations as independent navigation branches, each with its own
/// [Navigator] and navigation state:
///
///   - `/all`          — all Wishes regardless of status (R9.1)
///   - `/active`       — Wishes with status `Active` (R9.2)
///   - `/in-progress`  — Wishes with status `In_Progress` (R9.3)
///   - `/completed`    — Wishes with status `Completed` (R9.4)
///   - `/settings`     — backup / restore / configuration (R11, R12)
///
/// Because the shell uses `indexedStack`, each branch's `Navigator` stays
/// mounted when the user switches tabs, so per-tab scroll position, filter
/// selection, and any pushed sub-routes are preserved across tab switches
/// (R9.1–R9.4). The root path `/` redirects to `/all` so the app always opens
/// on a concrete destination.
///
/// Detail (R9.5), editor (R1, R2), and new-wish routes are declared as routed
/// children of the first branch and are driven by the path:
///
///   - `/wish/new`       — create a new Wish
///   - `/wish/:id`       — view a Wish's full details (R9.5)
///   - `/wish/:id/edit`  — edit an existing Wish (R2)
///
/// The `:id` path parameter is the Wish's stable UUID (R14.1); it is extracted
/// from [GoRouterState.pathParameters] and handed to the detail/editor screens.
///
/// ## Placeholders
///
/// The responsive shell (task 12.2, [AppShell]) wraps the branches; the
/// concrete views (list/detail/editor views 13.x, celebration overlay 15.x)
/// are built by later tasks. This file wires lightweight placeholder
/// [Scaffold]s to each route so the router is complete and navigable now;
/// later tasks replace the placeholder builders with the real widgets without
/// changing the route graph.
///
/// ## Layering (design "Module boundaries")
///
/// This is a presentation-layer file. It references the domain
/// [LifecycleStatus] enum (read-only model) to label the lifecycle tabs and
/// never touches the data-access layer or Drift. The router is exposed as a
/// Riverpod [Provider] ([goRouterProvider]) so `main.dart` (task 16) and the
/// responsive shell (task 12.2) consume one shared instance.
library wishable.presentation.router.app_router;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_shell.dart';
import '../views/settings_view.dart';
import '../views/wish_detail_view.dart';
import '../views/wish_edit_form_view.dart';
import '../views/wish_list_view.dart';

/// Route path and name constants for Wishable's navigation graph.
///
/// Centralizing the strings keeps the branch definitions, redirects, and any
/// `context.goNamed(...)` call sites in agreement. Named routes let later
/// tasks navigate by name (e.g. `WishRoutes.detailName`) and build parametered
/// locations without string-concatenating paths by hand.
abstract final class WishRoutes {
  const WishRoutes._();

  /// Root location; redirects to [all].
  static const String root = '/';

  /// All Wishes (R9.1) — first lifecycle tab.
  static const String all = '/all';
  static const String allName = 'all';

  /// Active Wishes (R9.2).
  static const String active = '/active';
  static const String activeName = 'active';

  /// In-progress Wishes (R9.3).
  static const String inProgress = '/in-progress';
  static const String inProgressName = 'in-progress';

  /// Completed Wishes (R9.4).
  static const String completed = '/completed';
  static const String completedName = 'completed';

  /// Settings / backup-restore (R11, R12).
  static const String settings = '/settings';
  static const String settingsName = 'settings';

  /// Create a new Wish.
  static const String newWish = '/wish/new';
  static const String newWishName = 'wish-new';

  /// View a Wish's details (R9.5). Expects a `:id` path parameter.
  static const String detail = '/wish/:id';
  static const String detailName = 'wish-detail';

  /// Edit a Wish (R2). Expects a `:id` path parameter.
  static const String edit = '/wish/:id/edit';
  static const String editName = 'wish-edit';

  /// The ordered lifecycle/settings destinations shown in the shell, matching
  /// the five [StatefulShellRoute] branches by index. The responsive shell
  /// (task 12.2) consumes this to build its `NavigationBar`/`NavigationRail`
  /// destinations and to map a selected index back to a branch.
  static const List<ShellDestination> destinations = <ShellDestination>[
    ShellDestination(
      label: 'All',
      location: all,
      icon: Icons.format_list_bulleted_outlined,
      selectedIcon: Icons.format_list_bulleted,
    ),
    ShellDestination(
      label: 'Active',
      location: active,
      icon: Icons.star_outline,
      selectedIcon: Icons.star,
    ),
    ShellDestination(
      label: 'In progress',
      location: inProgress,
      icon: Icons.timelapse_outlined,
      selectedIcon: Icons.timelapse,
    ),
    ShellDestination(
      label: 'Completed',
      location: completed,
      icon: Icons.check_circle_outline,
      selectedIcon: Icons.check_circle,
    ),
    ShellDestination(
      label: 'Settings',
      location: settings,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];
}

/// A single top-level destination in the responsive shell. Pairs a human label
/// and Material Symbols icons with the branch's root [location]. Used by the
/// shell (task 12.2) to render navigation controls; defined here so the route
/// graph and the navigation chrome stay in sync.
@immutable
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.location,
    required this.icon,
    required this.selectedIcon,
  });

  /// Visible label for the destination.
  final String label;

  /// The branch root path this destination navigates to.
  final String location;

  /// Icon shown when the destination is not selected.
  final IconData icon;

  /// Icon shown when the destination is selected.
  final IconData selectedIcon;
}

/// Provides the application's single [GoRouter], configured with the
/// lifecycle-tab [StatefulShellRoute] and the detail/editor/new routed
/// children.
///
/// Exposed as a plain [Provider] so `main.dart` (task 16) passes it to
/// `MaterialApp.router` and the shell (task 12.2) reuses the same instance.
/// The router is created once per [ProviderScope]; its state (including the
/// per-branch navigation stacks) lives for the life of the provider.
final Provider<GoRouter> goRouterProvider = Provider<GoRouter>(
  (Ref ref) => buildRouter(),
  name: 'goRouterProvider',
);

/// Builds the Wishable [GoRouter].
///
/// Factored out of [goRouterProvider] so tests (task 12.3 and beyond) can
/// construct a router without a [ProviderScope]. [initialLocation] defaults to
/// [WishRoutes.all]; tests may override it to start on a specific destination.
GoRouter buildRouter({String initialLocation = WishRoutes.all}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      // Open on a concrete lifecycle tab rather than the bare root.
      GoRoute(
        path: WishRoutes.root,
        redirect: (BuildContext context, GoRouterState state) => WishRoutes.all,
      ),
      StatefulShellRoute.indexedStack(
        // indexedStack keeps every branch Navigator mounted, preserving each
        // tab's navigation + scroll/filter state across tab switches
        // (R9.1–R9.4).
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          // Branch 0 — All (R9.1). The detail/editor/new routes hang off this
          // branch so opening a Wish keeps the user within a lifecycle tab.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: WishRoutes.all,
                name: WishRoutes.allName,
                builder: (BuildContext context, GoRouterState state) =>
                    const AllWishesView(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'wish/new',
                    name: WishRoutes.newWishName,
                    builder: (BuildContext context, GoRouterState state) =>
                        const WishEditFormView(wishId: null),
                  ),
                  GoRoute(
                    path: 'wish/:id',
                    name: WishRoutes.detailName,
                    builder: (BuildContext context, GoRouterState state) =>
                        WishDetailView(
                      wishId: state.pathParameters['id']!,
                    ),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'edit',
                        name: WishRoutes.editName,
                        builder: (
                          BuildContext context,
                          GoRouterState state,
                        ) =>
                            WishEditFormView(
                          wishId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Branch 1 — Active (R9.2).
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: WishRoutes.active,
                name: WishRoutes.activeName,
                builder: (BuildContext context, GoRouterState state) =>
                    const ActiveWishesView(),
              ),
            ],
          ),
          // Branch 2 — In progress (R9.3).
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: WishRoutes.inProgress,
                name: WishRoutes.inProgressName,
                builder: (BuildContext context, GoRouterState state) =>
                    const InProgressWishesView(),
              ),
            ],
          ),
          // Branch 3 — Completed (R9.4).
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: WishRoutes.completed,
                name: WishRoutes.completedName,
                builder: (BuildContext context, GoRouterState state) =>
                    const CompletedWishesView(),
              ),
            ],
          ),
          // Branch 4 — Settings (R11, R12).
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: WishRoutes.settings,
                name: WishRoutes.settingsName,
                builder: (BuildContext context, GoRouterState state) =>
                    const SettingsView(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) =>
        _RouteErrorPlaceholder(error: state.error),
  );
}

// ---------------------------------------------------------------------------
// Placeholder widgets.
//
// These stand in for the real views until tasks 12.2–15.x replace them. They
// are intentionally minimal: a Scaffold with a label and (for list routes)
// buttons that exercise the detail/editor/new routes so the route graph is
// navigable end to end. Replacing a placeholder with a real view only requires
// swapping the corresponding `builder` above.
// ---------------------------------------------------------------------------

/// Fallback shown for an unknown route or a navigation error.
class _RouteErrorPlaceholder extends StatelessWidget {
  const _RouteErrorPlaceholder({required this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Text(error?.toString() ?? 'The requested page was not found.'),
      ),
    );
  }
}
