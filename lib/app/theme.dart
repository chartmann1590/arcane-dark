import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Arcane Dark — Stitch design system `assets/6622902524875945862`
/// Dark fantasy tavern-table aesthetic. Do not retune colors by eye;
/// use these locked tokens verbatim.
class ArcaneTheme {
  // Locked tokens from Stitch — see plan/07
  static const Color background = Color(0xFF0F0D17);
  static const Color surface = Color(0xFF1A162B);
  static const Color surfaceElevated = Color(0xFF24203A);
  static const Color surfaceCard = Color(0xFF1E1B2E);
  static const Color primary = Color(0xFF8B5CF6); // violet / magic / AI state
  static const Color secondary = Color(0xFFC9A227); // aged gold / treasure
  static const Color tertiary = Color(0xFFB0263A); // blood red / danger
  static const Color border = Color(0xFF2E2A44);
  static const Color borderGold = Color(0x33C9A227);
  static const Color textPrimary = Color(0xFFF5F3FF);
  static const Color textSecondary = Color(0xFFB8B2D0);
  static const Color textMuted = Color(0xFF7C7892);

  static const double radius = 12.0;

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final manrope = GoogleFonts.manropeTextTheme(base.textTheme);
    final playfair = GoogleFonts.playfairDisplayTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.black,
        tertiary: tertiary,
        onTertiary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        error: tertiary,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: playfair.displayLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineLarge: playfair.headlineLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: playfair.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: manrope.titleMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: manrope.bodyLarge?.copyWith(
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: manrope.bodyMedium?.copyWith(
          color: textSecondary,
          height: 1.5,
        ),
        bodySmall: manrope.bodySmall?.copyWith(
          color: textMuted,
        ),
        labelLarge: manrope.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: secondary,
          letterSpacing: 1.2,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.manrope(color: textMuted, fontSize: 14),
        labelStyle: GoogleFonts.manrope(color: textSecondary, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0F0D17),
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceElevated,
        selectedColor: primary.withOpacity(0.2),
        secondarySelectedColor: primary,
        labelStyle: GoogleFonts.manrope(
          color: textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Reusable decorations that match Stitch screens
  static BoxDecoration cardDecoration({bool selected = false, bool goldBorder = false}) {
    return BoxDecoration(
      color: surfaceCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: selected
            ? primary
            : goldBorder
                ? secondary.withOpacity(0.5)
                : border,
        width: selected ? 1.5 : 1,
      ),
      boxShadow: selected
          ? [
              BoxShadow(
                color: primary.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 0,
              )
            ]
          : null,
    );
  }

  static BoxDecoration goldCardDecoration = BoxDecoration(
    color: surfaceCard,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: secondary.withOpacity(0.3), width: 1),
  );

  static BoxDecoration violetGlow = BoxDecoration(
    color: primary.withOpacity(0.12),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: primary.withOpacity(0.3)),
  );
}
