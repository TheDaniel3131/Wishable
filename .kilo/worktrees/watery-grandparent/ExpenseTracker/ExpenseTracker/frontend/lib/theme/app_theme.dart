import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary palette
  static const background   = Color(0xFF0A0A0F);
  static const surface      = Color(0xFF13131A);
  static const surfaceAlt   = Color(0xFF1C1C28);
  static const surfaceHigh  = Color(0xFF252535);

  // Accent
  static const violet       = Color(0xFF7C6EF7);
  static const violetDark   = Color(0xFF5B4FD4);
  static const violetLight  = Color(0xFFA889F7);

  // Semantic
  static const green        = Color(0xFF22C97E);
  static const red          = Color(0xFFF05252);
  static const amber        = Color(0xFFF0A922);
  static const blue         = Color(0xFF2296F0);

  // Text
  static const textPrimary  = Color(0xFFF0F0FF);
  static const textSecondary= Color(0xFF9898BB);
  static const textMuted    = Color(0xFF5A5A7A);

  // Borders
  static const border       = Color(0x12FFFFFF);
  static const borderMid    = Color(0x1FFFFFFF);

  // Category colors
  static const catFood      = Color(0xFFF07C22);
  static const catTransport = Color(0xFF2296F0);
  static const catShopping  = Color(0xFFEC4899);
  static const catHealth    = Color(0xFF22C97E);
  static const catBills     = Color(0xFFF0A922);
  static const catFun       = Color(0xFFA855F7);
  static const catGroceries = Color(0xFF16A34A);
  static const catOther     = Color(0xFF6B7280);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.violet,
        secondary: AppColors.violetLight,
        surface:   AppColors.surface,
        error:     AppColors.red,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(
        const TextTheme(
          displayLarge:  TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -2),
          displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -1),
          displaySmall:  TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -.5),
          headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          headlineMedium:TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          headlineSmall: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
          bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
          bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted),
          labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          labelMedium:   TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          labelSmall:    TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted, letterSpacing: .5),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.violet, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.violet,
        unselectedItemColor: AppColors.textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS:   CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux:   CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

// ── Category metadata ─────────────────────────────────────────────────────
class CategoryMeta {
  final String id;
  final String label;
  final String emoji;
  final Color  color;
  const CategoryMeta({required this.id, required this.label, required this.emoji, required this.color});
}

const List<CategoryMeta> kCategories = [
  CategoryMeta(id: 'food',       label: 'Food',       emoji: '🍔', color: AppColors.catFood),
  CategoryMeta(id: 'transport',  label: 'Transport',  emoji: '🚗', color: AppColors.catTransport),
  CategoryMeta(id: 'shopping',   label: 'Shopping',   emoji: '🛍️', color: AppColors.catShopping),
  CategoryMeta(id: 'health',     label: 'Health',     emoji: '💊', color: AppColors.catHealth),
  CategoryMeta(id: 'bills',      label: 'Bills',      emoji: '⚡', color: AppColors.catBills),
  CategoryMeta(id: 'fun',        label: 'Fun',        emoji: '🎬', color: AppColors.catFun),
  CategoryMeta(id: 'groceries',  label: 'Groceries',  emoji: '🛒', color: AppColors.catGroceries),
  CategoryMeta(id: 'other',      label: 'Other',      emoji: '📦', color: AppColors.catOther),
];

CategoryMeta categoryById(String id) =>
  kCategories.firstWhere((c) => c.id == id, orElse: () => kCategories.last);
