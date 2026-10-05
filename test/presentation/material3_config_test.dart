/// Smoke test for the central Material 3 theme configuration (task 18.3).
///
/// **Validates: Requirements 13.4**
///
/// R13.4 requires the app to render with Material 3 components and the Material
/// Symbols icon set. [AppTheme.light]/[AppTheme.dark] both return
/// [ThemeData.useMaterial3] = true, and the icon set is centralized through
/// [AppTheme.materialSymbolsFamily] (the bundled `MaterialSymbolsOutlined`
/// font). Every glyph in [AppIcons] binds to that family via its
/// `IconData.fontFamily`, so configuring the font in one place applies the
/// Material Symbols set wherever those icons are used.
///
/// This is a focused smoke test: it asserts the two theme factories enable
/// Material 3, that the Material Symbols family is configured and used by the
/// [AppIcons] glyphs, and that `useMaterial3` propagates through a mounted
/// [MaterialApp] via `Theme.of(context)`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishable/theme/app_theme.dart';

void main() {
  group('Material 3 configuration (R13.4)', () {
    test('AppTheme.light() and dark() enable Material 3', () {
      expect(AppTheme.light().useMaterial3, isTrue);
      expect(AppTheme.dark().useMaterial3, isTrue);
    });

    test('Material Symbols icon set is configured', () {
      expect(AppTheme.materialSymbolsFamily, 'MaterialSymbolsOutlined');

      const glyphs = <IconData>[
        AppIcons.all,
        AppIcons.active,
        AppIcons.inProgress,
        AppIcons.completed,
        AppIcons.settings,
      ];
      for (final glyph in glyphs) {
        expect(glyph.fontFamily, AppTheme.materialSymbolsFamily);
      }
    });

    testWidgets('useMaterial3 propagates through a mounted MaterialApp',
        (tester) async {
      late bool propagatedUseMaterial3;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              propagatedUseMaterial3 = Theme.of(context).useMaterial3;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(propagatedUseMaterial3, isTrue);
    });
  });
}
