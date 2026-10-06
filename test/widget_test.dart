/// Smoke test for the assembled application entry point (task 16).
///
/// Boots the real [WishableApp] — a Material 3 `MaterialApp.router` wired to
/// the shared [goRouterProvider], the responsive shell, and the Material 3
/// theme — and asserts the app comes up on the "All" lifecycle tab.
///
/// The shell opens on `/all`, whose [AllWishesView] watches the lifecycle
/// stream providers. Those are normally backed by the Drift [AppDatabase]; the
/// four streams are overridden here to emit an empty `List<Wish>` so the boot
/// test exercises the real widget graph without opening a database (same
/// pattern as `test/presentation/responsive_shell_test.dart`).
library wishable.test.widget_test;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishable/application/application.dart';
import 'package:wishable/domain/domain.dart';
import 'package:wishable/main.dart';

void main() {
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

  testWidgets('App boots the Material 3 shell on the All tab',
      (WidgetTester tester) async {
    // Pin a compact viewport so the shell renders its single-column layout with
    // a bottom NavigationBar deterministically (R13.2), independent of the
    // default test surface size.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: emptyWishStreamOverrides(),
        child: const WishableApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The responsive shell is mounted (compact layout shows a NavigationBar).
    expect(find.byType(NavigationBar), findsOneWidget);
    // The app opens on the "All" lifecycle tab (R9.1): its AppBar title shows.
    expect(find.text('All Wishlists'), findsOneWidget);
  });
}
