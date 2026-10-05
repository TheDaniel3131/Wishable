/// Widget test for the responsive navigation shell breakpoints (task 12.3).
///
/// **Validates: Requirements 13.2, 13.3**
///
/// [AppShell] uses a [LayoutBuilder] that switches layouts at the
/// [kShellBreakpoint] of 600 logical pixels:
///
///   - width <= 600 — single-column layout with a bottom [NavigationBar]
///     (R13.2);
///   - width > 600 — [NavigationRail] + content-pane (multi-column) layout
///     (R13.3).
///
/// Note the exact boundary semantics encoded by `constraints.maxWidth <=
/// kShellBreakpoint`: width **600 is still compact** (NavigationBar) and width
/// **601 is wide** (NavigationRail). This test asserts all four widths —
/// 360, 600, 601, 1200 — hit the correct side of that boundary.
///
/// The test mounts the REAL app graph: [buildRouter] inside a
/// [MaterialApp.router], wrapped in a [ProviderScope]. The shell always opens
/// on the "All" branch, whose view ([AllWishesView]) watches
/// [allWishesProvider] (and the other lifecycle streams back the remaining
/// branches). Those stream providers are normally backed by the Drift
/// [AppDatabase]; here they are overridden to emit an empty `List<Wish>` so the
/// test exercises the shell's layout logic without opening a real database.
///
/// The viewport is resized per width via `tester.view.physicalSize` with a
/// device-pixel-ratio of 1.0 (so logical == physical pixels), and reset after
/// each case with `addTearDown(tester.view.reset)`.
library wishable.test.presentation.responsive_shell_test;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishable/application/application.dart';
import 'package:wishable/domain/domain.dart';
import 'package:wishable/presentation/router/app_router.dart';

void main() {
  // A generous height so the chosen layout is never height-constrained; only
  // the width should drive the compact/wide decision.
  const double height = 2000;

  /// Overrides the lifecycle list streams so the branch views render without a
  /// real Drift database. Each emits a single empty list and then stays open.
  List<Override> emptyWishStreamOverrides() => <Override>[
        allWishesProvider.overrideWith(
          (Ref ref) => Stream<List<Wish>>.value(const <Wish>[]),
        ),
        activeWishesProvider.overrideWith(
          (Ref ref) => Stream<List<Wish>>.value(const <Wish>[]),
        ),
        inProgressWishesProvider.overrideWith(
          (Ref ref) => Stream<List<Wish>>.value(const <Wish>[]),
        ),
        completedWishesProvider.overrideWith(
          (Ref ref) => Stream<List<Wish>>.value(const <Wish>[]),
        ),
      ];

  /// Pumps the real app at the given logical [width], returning once the first
  /// frame has settled.
  Future<void> pumpAppAtWidth(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);

    final GoRouter router = buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: emptyWishStreamOverrides(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('responsive shell breakpoints (R13.2, R13.3)', () {
    testWidgets('width 360 is single-column: NavigationBar, no NavigationRail',
        (WidgetTester tester) async {
      await pumpAppAtWidth(tester, 360);

      expect(find.byType(NavigationBar), findsOneWidget,
          reason: 'width 360 (<= 600) must use the bottom NavigationBar '
              '(single column, R13.2)');
      expect(find.byType(NavigationRail), findsNothing,
          reason: 'width 360 must not show a NavigationRail');
    });

    testWidgets(
        'width 600 (boundary) is single-column: NavigationBar, no '
        'NavigationRail', (WidgetTester tester) async {
      await pumpAppAtWidth(tester, 600);

      // The breakpoint is inclusive on the compact side: width == 600 is still
      // the single-column layout (constraints.maxWidth <= kShellBreakpoint).
      expect(find.byType(NavigationBar), findsOneWidget,
          reason: 'width 600 is at the breakpoint and must still use the '
              'bottom NavigationBar (single column, R13.2)');
      expect(find.byType(NavigationRail), findsNothing,
          reason: 'width 600 must not show a NavigationRail');
    });

    testWidgets(
        'width 601 (just over boundary) is rail/multi-column: NavigationRail, '
        'no NavigationBar', (WidgetTester tester) async {
      await pumpAppAtWidth(tester, 601);

      // One pixel over the breakpoint flips to the rail + content-pane layout.
      expect(find.byType(NavigationRail), findsOneWidget,
          reason: 'width 601 (> 600) must use the NavigationRail '
              '(rail/multi-column, R13.3)');
      expect(find.byType(NavigationBar), findsNothing,
          reason: 'width 601 must not show a bottom NavigationBar');
    });

    testWidgets(
        'width 1200 is rail/multi-column: NavigationRail, no NavigationBar',
        (WidgetTester tester) async {
      await pumpAppAtWidth(tester, 1200);

      expect(find.byType(NavigationRail), findsOneWidget,
          reason: 'width 1200 (> 600) must use the NavigationRail '
              '(rail/multi-column, R13.3)');
      expect(find.byType(NavigationBar), findsNothing,
          reason: 'width 1200 must not show a bottom NavigationBar');
    });
  });
}
