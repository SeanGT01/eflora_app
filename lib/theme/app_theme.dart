import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors mirror the website's CSS custom properties in `base.html` so the app
/// and the web store read as one product.
class AppColors {
  // ── Core palette (web :root) ──
  static const cream = Color(0xFFFAF6F0); // --cream
  static const pageCream = Color(0xFFFFFCF8); // landing / inner page base
  static const warmWhite = Color(0xFFFFFDF9); // --warm-white
  static const blush = Color(0xFFF2C4CE); // --blush
  static const deepRose = Color(0xFFB5445A); // --deep-rose
  static const dustyRose = Color(0xFFD4788A); // --dusty-rose
  static const sage = Color(0xFF7A9E7E); // --sage
  static const deepSage = Color(0xFF4A6B4E); // --deep-sage
  static const terracotta = Color(0xFFC4714B); // --terracotta
  static const bark = Color(0xFF6B4C3B); // --bark
  static const charcoal = Color(0xFF2C2520); // --charcoal
  static const muted = Color(0xFF9A8D85); // --muted

  static const border = Color(0x1F6B4C3B); // rgba(107,76,59,0.12)
  static const borderStrong = Color(0x406B4C3B); // rgba(107,76,59,0.25)

  // ── Signature pink → purple ramp ──
  static const roseCta = Color(0xFFC24E68);
  static const pinkMid = Color(0xFFD878A0);
  static const purpleEnd = Color(0xFFB070C8);
  static const labelPink = Color(0xFFC44A7A); // store / category labels

  static const successGreen = Color(0xFF27AE60);
  static const error = Color(0xFFC0392B);

  // ── Glass surfaces ──
  static const glassFill = Color(0x8CFFFFFF); // rgba(255,255,255,0.55)
  static const glassFillHover = Color(0xB8FFFFFF); // rgba(255,255,255,0.72)
  static const glassBorder = Color(0xB3FFFFFF); // rgba(255,255,255,0.7)
  static const glassHighlight = Color(0xBFFFFFFF); // inset top highlight
  static const glassBorderActive = Color(0x8CE6AAC3); // rgba(230,170,195,0.55)

  // ── Page background washes ──
  static const washPink = Color(0x59FFBED2); // rgba(255,190,210,0.35)
  static const washLavender = Color(0x47D2BEF0); // rgba(210,190,240,0.28)

  /// 135°, `#c24e68 → #d878a0 (55%) → #b070c8`. The primary CTA gradient.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [roseCta, pinkMid, purpleEnd],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient brandGradientHover = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB04058), Color(0xFFC86890), Color(0xFF9F60B8)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Horizontal variant used for underlines and progress bars.
  static const LinearGradient brandGradientH = LinearGradient(
    colors: [roseCta, pinkMid, purpleEnd],
  );

  /// Two-stop version used on small badges and chips.
  static const LinearGradient badgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [roseCta, pinkMid],
  );

  /// Soft avatar fill (`--blush` → `--dusty-rose`).
  static const LinearGradient blushGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blush, dustyRose],
  );

  /// Product image placeholder wash (web `.product-image`).
  static const LinearGradient imageWash = LinearGradient(
    begin: Alignment(-0.4, -0.6),
    end: Alignment(0.8, 0.9),
    colors: [Color(0xFFF8D0DC), Color(0xFFE8D8F4), Color(0xFFF5EBE8)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Header / bottom-nav glass wash (web `.main-header` / `.main-nav`).
  static const LinearGradient headerGlass = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0x73FFBED2), // rgba(255,190,210,0.45)
      Color(0x6BFFFAFC), // rgba(255,250,252,0.42)
      Color(0x66D2BEF0), // rgba(210,190,240,0.40)
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Auth brand panel (login left column).
  static const LinearGradient authBrandPanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC24E68), Color(0xFFD878A0), Color(0xFFB888D0)],
    stops: [0.0, 0.45, 1.0],
  );

  /// Kept for older call sites; now follows the web CTA ramp.
  static const LinearGradient roseGradient = brandGradient;
}

/// Radii, shadows and motion copied from the site's design tokens.
class AppRadius {
  static const double sm = 6;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 32;
  static const double pill = 100;
}

class AppShadows {
  static const List<BoxShadow> petal = [
    BoxShadow(color: Color(0x14B5445A), blurRadius: 24, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> leaf = [
    BoxShadow(color: Color(0x1F2A231E), blurRadius: 40, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> deep = [
    BoxShadow(color: Color(0x2E2A231E), blurRadius: 64, offset: Offset(0, 16)),
  ];

  /// Standard glass card: soft plum drop shadow + inset-style top highlight.
  static const List<BoxShadow> glass = [
    BoxShadow(color: Color(0x0F502846), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> glassRaised = [
    BoxShadow(color: Color(0x1A502846), blurRadius: 36, offset: Offset(0, 16)),
  ];

  /// Glow under primary gradient buttons.
  static const List<BoxShadow> roseButton = [
    BoxShadow(color: Color(0x40B5445A), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

class AppMotion {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration base = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 700);
  static const Curve curve = Cubic(0.4, 0, 0.2, 1);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.pageCream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.roseCta,
          primary: AppColors.roseCta,
          secondary: AppColors.purpleEnd,
          surface: AppColors.warmWhite,
          error: AppColors.error,
        ),
        textTheme: _buildTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppColors.charcoal,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: AppColors.charcoal,
            letterSpacing: 0.3,
          ),
          iconTheme: const IconThemeData(color: AppColors.charcoal, size: 22),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.roseCta,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            textStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.charcoal,
            backgroundColor: AppColors.glassFill,
            side: const BorderSide(color: AppColors.glassBorder, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            textStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.roseCta,
            textStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.glassFill,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: _inputBorder(AppColors.glassBorder, 1.5),
          enabledBorder: _inputBorder(AppColors.glassBorder, 1.5),
          focusedBorder: _inputBorder(const Color(0x8CD878A0), 2),
          errorBorder: _inputBorder(AppColors.error, 1.5),
          focusedErrorBorder: _inputBorder(AppColors.error, 2),
          labelStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13.5),
          hintStyle: GoogleFonts.dmSans(
            color: AppColors.muted.withOpacity(0.7),
            fontSize: 13.5,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.glassFill,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: const BorderSide(color: AppColors.glassBorder, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0x40E6AAC3),
          thickness: 1,
          space: 0,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.warmWhite,
          selectedItemColor: AppColors.roseCta,
          unselectedItemColor: AppColors.muted,
          selectedLabelStyle: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 10),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.charcoal,
          contentTextStyle: GoogleFonts.dmSans(color: AppColors.cream, fontSize: 13.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          behavior: SnackBarBehavior.floating,
          insetPadding: const EdgeInsets.all(16),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.glassFill,
          selectedColor: AppColors.roseCta,
          labelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
          side: const BorderSide(color: AppColors.glassBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.warmWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.warmWhite,
          surfaceTintColor: Colors.transparent,
        ),
      );

  static OutlineInputBorder _inputBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextTheme _buildTextTheme() => TextTheme(
        displayLarge: GoogleFonts.cormorantGaramond(fontSize: 48, fontWeight: FontWeight.w400, color: AppColors.charcoal, height: 1.1),
        displayMedium: GoogleFonts.cormorantGaramond(fontSize: 38, fontWeight: FontWeight.w400, color: AppColors.charcoal, height: 1.15),
        displaySmall: GoogleFonts.cormorantGaramond(fontSize: 30, fontWeight: FontWeight.w400, color: AppColors.charcoal, height: 1.2),
        headlineLarge: GoogleFonts.cormorantGaramond(fontSize: 26, fontWeight: FontWeight.w500, color: AppColors.charcoal),
        headlineMedium: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w500, color: AppColors.charcoal),
        headlineSmall: GoogleFonts.cormorantGaramond(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.charcoal),
        titleLarge: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.charcoal),
        titleMedium: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.charcoal),
        titleSmall: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.charcoal),
        bodyLarge: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.charcoal),
        bodyMedium: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w400, color: AppColors.charcoal),
        bodySmall: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.muted),
        labelLarge: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        labelMedium: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.08),
        labelSmall: GoogleFonts.dmSans(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.15),
      );
}
