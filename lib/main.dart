import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'presentation/presentation.dart';
import 'theme/app_theme.dart';

/// Entry point for Wishable (task 16).
///
/// Assembles the application: a Riverpod [ProviderScope] hosts the whole graph,
/// [WishableApp] mounts a `MaterialApp.router` driven by the shared
/// [goRouterProvider] (the responsive shell + lifecycle tabs), and the
/// Material 3 theme ([AppTheme]) is applied for both brightnesses.
///
/// Wiring notes:
///   - The Drift [AppDatabase] is created lazily the first time
///     `appDatabaseProvider` is read (R10.1); no eager initialization is
///     needed here.
///   - The lifecycle list views watch their stream providers
///     (`allWishesProvider` and friends), which subscribe to the repository's
///     Drift-backed streams. Because the app opens on `/all`, that view begins
///     watching on the first frame, so persisted Wishes load on startup
///     (R10.4) without an explicit preload step.
///   - [CelebrationListener] is installed via `MaterialApp.router`'s `builder`
///     so completion celebrations (R7) float above whichever route is active.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: WishableApp()));
}

/// Root widget: a Material 3 `MaterialApp.router` wired to the app's router,
/// theme, and celebration overlay.
class WishableApp extends ConsumerWidget {
  const WishableApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Wishable',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      // On launch, show the branded splash briefly while startup settles, then
      // crossfade into the app. The app lock gate (Option A) withholds the Wish
      // UI while locked (R2.1); the celebration overlay (R7) sits inside it.
      builder: (BuildContext context, Widget? child) => _StartupGate(
        child: AuthGate(
          child: CelebrationListener(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// Shows the branded [WishableSplash] for a short window on launch, then
/// crossfades into [child]. This gives startup work (database open, auth-state
/// restore) a moment to settle behind a premium brand screen instead of a
/// flash of empty UI.
class _StartupGate extends StatefulWidget {
  const _StartupGate({required this.child});

  final Widget child;

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Minimum splash duration so the brand is seen; real init (DB/auth) runs
    // concurrently and is near-instant locally.
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _ready
          ? KeyedSubtree(
              key: const ValueKey<String>('app'), child: widget.child)
          : const WishableSplash(key: ValueKey<String>('splash')),
    );
  }
}
