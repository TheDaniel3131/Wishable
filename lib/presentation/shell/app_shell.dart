/// [AppShell] — the responsive navigation shell that hosts the five top-level
/// branches of the [StatefulShellRoute] (design "Responsive shell"; R13.2,
/// R13.3, R13.4).
///
/// A [LayoutBuilder] measures the available width and switches between two
/// layouts at the 600 logical-pixel breakpoint:
///
///   - **width ≤ 600** — a single-column body with a bottom [NavigationBar]
///     (R13.2). This is the phone/narrow layout.
///   - **width > 600** — a [Row] with a [NavigationRail] on the left and the
///     active branch body ([StatefulNavigationShell]) filling the remaining
///     space (R13.3). This is the tablet/desktop wide (rail + content pane)
///     layout.
///
/// Selection is driven entirely by [StatefulNavigationShell.currentIndex], and
/// taps call [StatefulNavigationShell.goBranch] with
/// `initialLocation: index == currentIndex`. Re-selecting the current tab
/// resets it to its initial location, while switching tabs restores the target
/// branch's existing navigation stack rather than rebuilding it — preserving
/// per-tab scroll position, filter selection, and pushed sub-routes
/// (R9.1–R9.4).
///
/// Destinations come from [WishRoutes.destinations] so the navigation chrome
/// stays in sync with the route graph. Icons prefer the Material Symbols
/// glyphs in [AppIcons] (R13.4) where a destination maps to one, falling back
/// to the icons declared on the [ShellDestination] otherwise.
///
/// This is a presentation-layer widget: it depends only on the router
/// definitions and the theme, never on the data-access layer or Drift (design
/// "Module boundaries").
library wishable.presentation.shell.app_shell;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../router/app_router.dart';

/// The viewport width (in logical pixels) at or below which the shell uses a
/// single-column, bottom-[NavigationBar] layout (R13.2). Above it, the shell
/// uses a [NavigationRail] + content-pane layout (R13.3).
const double kShellBreakpoint = 600;

/// Responsive shell hosting the lifecycle/settings branches of the app's
/// [StatefulShellRoute]. See the library doc for the layout rules.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  /// The branch navigation state provided by the [StatefulShellRoute] builder.
  /// Its [StatefulNavigationShell.currentIndex] drives which destination is
  /// selected, and its widget value is the body of the active branch.
  final StatefulNavigationShell navigationShell;

  /// Switches to the branch at [index], preserving its navigation state unless
  /// the current branch is re-selected (in which case it resets to the
  /// branch's initial location). See R9.1–R9.4.
  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // At or below the breakpoint: single column + bottom bar (R13.2).
        // Above it: navigation rail + content pane (R13.3).
        if (constraints.maxWidth <= kShellBreakpoint) {
          return _buildCompact(context);
        }
        return _buildWide(context);
      },
    );
  }

  /// Single-column layout with a bottom [NavigationBar] (R13.2).
  Widget _buildCompact(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: <NavigationDestination>[
          for (final ShellDestination d in WishRoutes.destinations)
            NavigationDestination(
              icon: Icon(_iconFor(d, selected: false)),
              selectedIcon: Icon(_iconFor(d, selected: true)),
              label: d.label,
            ),
        ],
      ),
    );
  }

  /// Wide (rail + content pane) layout with a [NavigationRail] on the left and
  /// the active branch body filling the rest (R13.3).
  Widget _buildWide(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            destinations: <NavigationRailDestination>[
              for (final ShellDestination d in WishRoutes.destinations)
                NavigationRailDestination(
                  icon: Icon(_iconFor(d, selected: false)),
                  selectedIcon: Icon(_iconFor(d, selected: true)),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // The branch body fills the remaining width of the content pane.
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  /// Resolves the Material Symbols glyph for [destination], preferring the
  /// mapped [AppIcons] glyph (R13.4) and falling back to the icon declared on
  /// the [ShellDestination]. [selected] chooses the selected vs unselected
  /// variant for the fallback.
  IconData _iconFor(ShellDestination destination, {required bool selected}) {
    switch (destination.location) {
      case WishRoutes.all:
        return AppIcons.all;
      case WishRoutes.active:
        return AppIcons.active;
      case WishRoutes.inProgress:
        return AppIcons.inProgress;
      case WishRoutes.completed:
        return AppIcons.completed;
      case WishRoutes.settings:
        return AppIcons.settings;
      default:
        return selected ? destination.selectedIcon : destination.icon;
    }
  }
}
