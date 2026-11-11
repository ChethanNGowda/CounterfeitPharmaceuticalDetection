import 'package:flutter/material.dart';
import 'package:pharma_assist/core/theme_tokens.dart';

/// Centralized scientific design system and color tokens for PharmaAssist.
/// Brand specifications:
/// - Light Theme: #F4F8FB bg, #FFFFFF surface, #25658A primary blue, #0F8B83 accent teal, #DDF4EF soft mint
/// - Dark Theme: #102A43 bg, #193B53 surface, #24485A elevated, #48C5B3 accent teal, #244F50 soft mint
class AppTheme {
  // Flag for backward compatibility with existing tests
  static bool _useLightPalette = false;

  static void setPalette(bool light) => _useLightPalette = light;

  // ── Surface and Background Tokens ───────────────────────────────────────────
  static Color get background =>
      _useLightPalette ? const Color(0xFFF4F8FB) : const Color(0xFF102A43);
  static Color get secondaryBackground =>
      _useLightPalette ? const Color(0xFFEAF4FA) : const Color(0xFF193B53);
  static Color get elevatedCard =>
      _useLightPalette ? const Color(0xFFFFFFFF) : const Color(0xFF24485A);

  // Backward compatibility aliases
  static Color get surface => secondaryBackground;
  static Color get cardColor => elevatedCard;
  static Color get surfaceHighlight =>
      _useLightPalette ? const Color(0xFFDDF4EF) : const Color(0xFF1D4659);

  // ── Brand & Accent Colors ───────────────────────────────────────────────────
  static Color get primaryBlue =>
      _useLightPalette ? const Color(0xFF25658A) : const Color(0xFF24485A);
  static Color get deepBlue =>
      _useLightPalette ? const Color(0xFF174A6E) : const Color(0xFF102A43);
  static Color get primaryCyan =>
      _useLightPalette ? const Color(0xFF25658A) : const Color(0xFF48C5B3);
  static Color get secondaryTeal =>
      _useLightPalette ? const Color(0xFF0F8B83) : const Color(0xFF48C5B3);
  static Color get softMint =>
      _useLightPalette ? const Color(0xFFDDF4EF) : const Color(0xFF244F50);
  static Color get powderBlue =>
      _useLightPalette ? const Color(0xFFDCE8F8) : const Color(0xFF1D4659);
  static Color get softViolet => secondaryTeal;
  static Color get violetAccent => secondaryTeal;

  // Backward compatibility aliases
  static Color get primaryTeal => secondaryTeal;
  static Color get primaryTealDim =>
      _useLightPalette ? const Color(0xFF0F8B83) : const Color(0xFF35586C);

  // ── Semantic Feedback Colors ────────────────────────────────────────────────
  static const Color success = Color(0xFF16845B);
  static const Color warning = Color(0xFFC47A18);
  static const Color error = Color(0xFFC74747);

  // Backward compatibility aliases
  static const Color authenticGreen = Color(0xFF16845B);
  static Color get authenticBg =>
      _useLightPalette ? const Color(0xFFDDF4EF) : const Color(0xFF244F50);
  static const Color counterfeitRed = Color(0xFFC74747);
  static Color get counterfeitBg =>
      _useLightPalette ? const Color(0xFFFDE8E8) : const Color(0xFF381418);
  static const Color suspiciousAmber = Color(0xFFC47A18);
  static Color get suspiciousBg =>
      _useLightPalette ? const Color(0xFFFFF3D9) : const Color(0xFF382A0E);

  // ── Text & Typography Colors ────────────────────────────────────────────────
  static Color get textPrimary =>
      _useLightPalette ? const Color(0xFF183247) : const Color(0xFFF0F6FA);
  static Color get textSecondary =>
      _useLightPalette ? const Color(0xFF647B8C) : const Color(0xFFB9CCD9);
  static Color get textMuted =>
      _useLightPalette ? const Color(0xFF647B8C) : const Color(0xFFB9CCD9);

  // ── Borders & Dividers ──────────────────────────────────────────────────────
  static Color get border =>
      _useLightPalette ? const Color(0xFFDCE6ED) : const Color(0xFF35586C);
  static Color get borderSubtle =>
      _useLightPalette ? const Color(0xFFDCE6ED) : const Color(0xFF35586C);
  static Color get divider => border;

  // ── Distinct Typography Tokens with Graceful Fallbacks ──────────────────────
  static const List<String> fontHeadingFamilies = [
    'Space Grotesk',
    'Roboto',
    'sans-serif',
  ];
  static const List<String> fontBodyFamilies = [
    'Inter',
    'Roboto',
    'sans-serif',
  ];
  static const List<String> fontCodeFamilies = ['JetBrains Mono', 'monospace'];

  static TextStyle headingLarge({Color? color}) => TextStyle(
    fontFamily: 'Space Grotesk',
    fontFamilyFallback: fontHeadingFamilies,
    color: color ?? textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static TextStyle headingMedium({Color? color}) => TextStyle(
    fontFamily: 'Space Grotesk',
    fontFamilyFallback: fontHeadingFamilies,
    color: color ?? textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static TextStyle headingSmall({Color? color}) => TextStyle(
    fontFamily: 'Space Grotesk',
    fontFamilyFallback: fontHeadingFamilies,
    color: color ?? textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static TextStyle bodyText({
    Color? color,
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: fontBodyFamilies,
    color: color ?? textPrimary,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: 1.45,
  );

  static TextStyle monoNumeric({
    Color? color,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
  }) => TextStyle(
    fontFamily: 'JetBrains Mono',
    fontFamilyFallback: fontCodeFamilies,
    color: color ?? textPrimary,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: 0.2,
  );

  // ── Dark Theme (Refined Blue-Slate #102A43 + Teal #48C5B3) ───────────────────
  static ThemeData get darkTheme {
    const navyBackground = Color(0xFF102A43);
    const darkSurface = Color(0xFF193B53);
    const elevatedCardColor = Color(0xFF24485A);
    const darkBorder = Color(0xFF35586C);
    const tealPrimary = Color(0xFF48C5B3);
    const textLight = Color(0xFFF0F6FA);
    const textDim = Color(0xFFB9CCD9);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navyBackground,
      dividerColor: darkBorder,
      fontFamily: 'Inter',
      fontFamilyFallback: fontBodyFamilies,
      extensions: const [PharmaThemeTokens.dark],
      colorScheme: const ColorScheme.dark(
        primary: tealPrimary,
        secondary: Color(0xFF24485A),
        tertiary: Color(0xFF1D4659),
        surface: darkSurface,
        error: Color(0xFFEF4444),
        onPrimary: navyBackground,
        onSecondary: textLight,
        onSurface: textLight,
        outline: darkBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: navyBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textDim),
        actionsIconTheme: IconThemeData(color: textDim),
        titleTextStyle: TextStyle(
          fontFamily: 'Space Grotesk',
          fontFamilyFallback: fontHeadingFamilies,
          color: textLight,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
      cardTheme: CardThemeData(
        color: elevatedCardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tealPrimary,
          foregroundColor: navyBackground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontFamilyFallback: fontHeadingFamilies,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tealPrimary,
          side: const BorderSide(color: darkBorder, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: fontBodyFamilies,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: tealPrimary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textDim, fontSize: 13),
        hintStyle: TextStyle(
          color: textDim.withValues(alpha: 0.6),
          fontSize: 13,
        ),
        prefixIconColor: textDim,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: tealPrimary,
        inactiveTrackColor: darkBorder,
        thumbColor: tealPrimary,
        overlayColor: Color(0x2248C5B3),
        valueIndicatorColor: elevatedCardColor,
        valueIndicatorTextStyle: TextStyle(color: textLight, fontSize: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: const Color(0x3048C5B3),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            inherit: false,
            fontFamily: 'Inter',
            fontFamilyFallback: fontBodyFamilies,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? const Color(0xFF48C5B3) : const Color(0xFFB9CCD9),
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? const Color(0xFF48C5B3) : const Color(0xFFB9CCD9),
          );
        }),
      ),
    );
  }

  // ── Light Theme Architecture (Refined Blue/Teal/Mint Palette) ────────────────
  static ThemeData get lightTheme {
    const lightBg = Color(0xFFF4F8FB);
    const lightSurface = Color(0xFFFFFFFF);
    const lightCard = Color(0xFFFFFFFF);
    const lightBorder = Color(0xFFDCE6ED);
    const lightTextPrimary = Color(0xFF183247);
    const lightTextSecondary = Color(0xFF647B8C);
    const primaryBlue = Color(0xFF25658A);
    const accentTeal = Color(0xFF0F8B83);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      dividerColor: lightBorder,
      fontFamily: 'Inter',
      fontFamilyFallback: fontBodyFamilies,
      extensions: const [PharmaThemeTokens.light],
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: accentTeal,
        tertiary: Color(0xFF174A6E),
        surface: lightSurface,
        error: Color(0xFFC74747),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
        outline: lightBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextSecondary),
        actionsIconTheme: IconThemeData(color: lightTextSecondary),
        titleTextStyle: TextStyle(
          fontFamily: 'Space Grotesk',
          fontFamilyFallback: fontHeadingFamilies,
          color: lightTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontFamilyFallback: fontHeadingFamilies,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: lightBorder, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: fontBodyFamilies,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        labelStyle: const TextStyle(color: lightTextSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: lightTextSecondary, fontSize: 13),
        prefixIconColor: lightTextSecondary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: const Color(0x2025658A),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            inherit: false,
            fontFamily: 'Inter',
            fontFamilyFallback: fontBodyFamilies,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? const Color(0xFF25658A) : const Color(0xFF647B8C),
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? const Color(0xFF25658A) : const Color(0xFF647B8C),
          );
        }),
      ),
    );
  }
}
