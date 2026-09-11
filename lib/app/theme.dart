import 'package:flutter/material.dart';

/// Semantic color tokens for Nuvex.
/// Based on the approved design system in design.md:
/// - bright white background
/// - near-white surfaces
/// - pale gray/blue secondary surfaces
/// - dark navy/near-black text
/// - restrained blue accent
/// - subtle borders and shadows
abstract class NuvexColors {
  // Backgrounds & Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFAFBFC);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color card = Color(0xFFFFFFFF);

  // Text
  static const Color primaryText = Color(0xFF0F172A);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color mutedText = Color(0xFF94A3B8);

  // Accents
  static const Color primaryAccent = Color(0xFF2563EB); // Restrained blue
  static const Color primaryAccentDark = Color(0xFF1D4ED8);
  static const Color primaryAccentLight = Color(0xFFEFF6FF);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFE2E8F0);

  // Status
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFF0FDF4);
}

/// Spacing and radius constants for consistent layout hierarchy.
abstract class NuvexSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;

  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 999.0;
}

/// Light theme configuration for Nuvex.
abstract class NuvexTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: NuvexColors.background,
      colorScheme: const ColorScheme.light(
        primary: NuvexColors.primaryAccent,
        onPrimary: Colors.white,
        surface: NuvexColors.surface,
        onSurface: NuvexColors.primaryText,
        surfaceContainerHighest: NuvexColors.surfaceVariant,
        outline: NuvexColors.border,
        error: NuvexColors.error,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NuvexColors.background,
        foregroundColor: NuvexColors.primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: NuvexColors.primaryText,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: NuvexColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NuvexSpacing.radiusLg),
          side: const BorderSide(color: NuvexColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NuvexColors.primaryAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NuvexSpacing.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NuvexColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NuvexSpacing.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NuvexSpacing.radiusMd),
          borderSide: const BorderSide(color: NuvexColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NuvexSpacing.radiusMd),
          borderSide: const BorderSide(
            color: NuvexColors.primaryAccent,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NuvexSpacing.radiusMd),
          borderSide: const BorderSide(color: NuvexColors.error, width: 1),
        ),
        hintStyle: const TextStyle(color: NuvexColors.mutedText, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: NuvexColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
