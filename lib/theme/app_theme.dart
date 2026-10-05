import 'package:flutter/material.dart';

/// Central Material 3 theme configuration for Wishable (design R13.4).
///
/// Material 3 is enabled via [ThemeData.useMaterial3]. Icons use the Material
/// Symbols variable font declared in `pubspec.yaml` under the
/// `MaterialSymbolsOutlined` family; [AppIcons] exposes the glyphs the UI uses
/// so the icon set is configured in one place.
abstract final class AppTheme {
  /// Brand seed — a deep indigo/violet that reads modern and premium.
  static const Color _seed = Color(0xFF5B5BD6);

  /// Warm amber accent used for highlights and the brand gradient.
  static const Color brandAccent = Color(0xFFF5A524);

  /// The two brand gradient stops used by the logo and splash.
  static const Color brandGradientStart = Color(0xFF6D5BF8);
  static const Color brandGradientEnd = Color(0xFF9B4DFF);

  /// The icon family bundled for the Material Symbols set.
  static const String materialSymbolsFamily = 'MaterialSymbolsOutlined';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    ).copyWith(
      // A warm secondary gives the UI a two-tone, premium feel rather than a
      // single monochrome hue.
      secondary: brandAccent,
      surfaceTint: Colors.transparent,
    );

    final Color scaffold = isDark
        ? const Color(0xFF0F0F17) // near-black with a violet undertone
        : const Color(0xFFF7F7FB); // soft off-white

    final TextTheme baseText =
        (isDark ? Typography.whiteMountainView : Typography.blackMountainView)
            .apply(fontFamilyFallback: const <String>['Roboto']);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // Rounder, calmer typography scale.
      textTheme: baseText.copyWith(
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: isDark ? const Color(0xFF191926) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.6),
          ),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF191926) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF14141F) : Colors.white,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(
          baseText.labelMedium ?? const TextStyle(),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? const Color(0xFF14141F) : Colors.white,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    );
  }
}

/// Material Symbols glyphs used across the app, keyed to the bundled
/// `MaterialSymbolsOutlined` font family. Code points follow the Material
/// Symbols set. Centralizing them keeps the icon set configuration in one spot.
abstract final class AppIcons {
  static const IconData all =
      IconData(0xe8f1, fontFamily: AppTheme.materialSymbolsFamily);
  static const IconData active =
      IconData(0xe837, fontFamily: AppTheme.materialSymbolsFamily);
  static const IconData inProgress =
      IconData(0xe922, fontFamily: AppTheme.materialSymbolsFamily);
  static const IconData completed =
      IconData(0xe86c, fontFamily: AppTheme.materialSymbolsFamily);
  static const IconData settings =
      IconData(0xe8b8, fontFamily: AppTheme.materialSymbolsFamily);

  /// Database / raw SQLite export (R11.1). Material Symbols `database`.
  static const IconData database =
      IconData(0xf20e, fontFamily: AppTheme.materialSymbolsFamily);

  /// JSON export (R11.2). Material Symbols `data_object`.
  static const IconData json =
      IconData(0xeae6, fontFamily: AppTheme.materialSymbolsFamily);

  /// CSV / tabular export (R11.3). Material Symbols `csv`.
  static const IconData csv =
      IconData(0xf838, fontFamily: AppTheme.materialSymbolsFamily);

  /// Restore / import from a backup file (R12.1). Material Symbols
  /// `restore_page`.
  static const IconData restore =
      IconData(0xf3fb, fontFamily: AppTheme.materialSymbolsFamily);

  /// Completion celebration (R7.1). Material Symbols `celebration`.
  static const IconData celebration =
      IconData(0xea65, fontFamily: AppTheme.materialSymbolsFamily);
}
