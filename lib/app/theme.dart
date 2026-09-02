import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Arcane Dark — Stitch design system `assets/6622902524875945862`
/// Dark fantasy tavern-table aesthetic. Do not retune colors by eye;
/// use these locked tokens verbatim.
class ArcaneTheme {
  // "Ember & Void" — a torch-lit dungeon rather than a violet AI-app tint.
  // Warm near-black grounds, a hot ember-orange as the everyday accent, aged
  // brass instead of storybook gold, and violet demoted to a rare "arcane
  // magic" highlight instead of the dominant color on every button.
  static const Color background = Color(0xFF0A0806);
  static const Color surface = Color(0xFF17110C);
  static const Color surfaceElevated = Color(0xFF221A12);
  static const Color surfaceCard = Color(0xFF1C150F);
  static const Color primary = Color(0xFFE0793F); // ember orange / everyday accent
  static const Color secondary = Color(0xFFB68A46); // aged brass / treasure
  static const Color tertiary = Color(0xFFA6394A); // blood red / danger
  static const Color arcane = Color(0xFF8C6BFF); // reserved: magic/AI-specific moments only
  static const Color border = Color(0xFF352A1E);
  static const Color borderGold = Color(0x33B68A46);
  static const Color textPrimary = Color(0xFFF6EDE2);
  static const Color textSecondary = Color(0xFFC9B9A6);
  static const Color textMuted = Color(0xFF8C7B68);

  static const double radius = 12.0;

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final manrope = GoogleFonts.ibmPlexSansTextTheme(base.textTheme);
    final playfair = GoogleFonts.cinzelTextTheme(base.textTheme);

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
        titleTextStyle: GoogleFonts.cinzel(
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
          textStyle: GoogleFonts.ibmPlexSans(
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
        hintStyle: GoogleFonts.ibmPlexSans(color: textMuted, fontSize: 14),
        labelStyle: GoogleFonts.ibmPlexSans(color: textSecondary, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
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
        labelStyle: GoogleFonts.ibmPlexSans(
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

  // Reusable decorations. A flat single-color fill on every card is what
  // made the whole app read as flat — a faint top-to-bottom gradient (a hair
  // lighter at the top, as if catching torchlight) gives every card real
  // depth for free, everywhere it's used, with no per-screen changes needed.
  static BoxDecoration cardDecoration({bool selected = false, bool goldBorder = false}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(surfaceCard, Colors.white, 0.035)!, surfaceCard],
      ),
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
    color: arcane.withOpacity(0.12),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: arcane.withOpacity(0.3)),
  );

  /// A more ornate card for hero moments (campaign banner, character sheet
  /// header): a warm radial glow behind a gold-bordered panel, instead of
  /// just another flat rectangle.
  static BoxDecoration ornateDecoration({Color glow = secondary}) {
    return BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.topCenter,
        radius: 1.4,
        colors: [Color.lerp(surfaceCard, glow, 0.10)!, surfaceCard],
      ),
      borderRadius: BorderRadius.circular(radius + 2),
      border: Border.all(color: glow.withOpacity(0.45), width: 1.2),
      boxShadow: [BoxShadow(color: glow.withOpacity(0.12), blurRadius: 20, spreadRadius: -4)],
    );
  }
}
