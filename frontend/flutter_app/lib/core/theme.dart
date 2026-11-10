import 'package:flutter/material.dart';
import 'package:pharma_assist/core/theme_tokens.dart';

/// Centralized scientific design system and color tokens for PharmaAssist.
/// Brand specifications:
/// - Primary Dark Navy: #0B1320
/// - Teal Accent: #19B6A4
/// - Clean light surface: #F8FAFC
/// - Dark surface: #0B1320 / #111E33 / #142036
class AppTheme {
  // Flag for backward compatibility with existing tests
  static bool _useLightPalette = false;

  static void setPalette(bool light) => _useLightPalette = light;

  // ── Surface and Background Tokens ───────────────────────────────────────────
  static Color get background =>
      _useLightPalette ? const Color(0xFFF5F8FC) : const Color(0xFF0B1020);
  static Color get secondaryBackground =>
      _useLightPalette ? const Color(0xFFEDF2F8) : const Color(0xFF111A2E);
  static Color get elevatedCard =>
      _useLightPalette ? Colors.white : const Color(0xFF17243A);

  // Backward compatibility aliases
  static Color get surface => secondaryBackground;
  static Color get cardColor => elevatedCard;
  static Color get surfaceHighlight =>
      _useLightPalette ? const Color(0xFFE0F2F1) : const Color(0xFF1F2F4A);

  // ── Brand & Accent Colors ───────────────────────────────────────────────────
  static Color get primaryCyan =>
      _useLightPalette ? const Color(0xFF087E8B) : const Color(0xFF25D9F8);
  static Color get secondaryTeal =>
      _useLightPalette ? const Color(0xFF0D9488) : const Color(0xFF35D6B4);
  static Color get softViolet =>
      _useLightPalette ? const Color(0xFF0F766E) : const Color(0xFF14B8A6);
  static Color get violetAccent => softViolet;

  // Backward compatibility aliases
  static Color get primaryTeal => secondaryTeal;
  static Color get primaryTealDim =>
      _useLightPalette ? const Color(0xFF087E73) : const Color(0xFF209A80);

  // ── Semantic Feedback Colors ────────────────────────────────────────────────
  static const Color success = Color(0xFF36C98F);
  static const Color warning = Color(0xFFF6BD60);
  static const Color error = Color(0xFFFF647C);

  // Backward compatibility aliases
  static const Color authenticGreen = Color(0xFF36C98F);
  static Color get authenticBg =>
      _useLightPalette ? const Color(0xFFE5F5EC) : const Color(0xFF0E2E20);
  static const Color counterfeitRed = Color(0xFFFF647C);
  static Color get counterfeitBg =>
      _useLightPalette ? const Color(0xFFFCE8EC) : const Color(0xFF34141E);
  static const Color suspiciousAmber = Color(0xFFF6BD60);
  static Color get suspiciousBg =>
      _useLightPalette ? const Color(0xFFFFF3D9) : const Color(0xFF332612);

  // ── Text & Typography Colors ────────────────────────────────────────────────
  static Color get textPrimary =>
      _useLightPalette ? const Color(0xFF17212F) : const Color(0xFFF3F6FC);
  static Color get textSecondary =>
      _useLightPalette ? const Color(0xFF46566B) : const Color(0xFFA5B2C7);
  static Color get textMuted =>
      _useLightPalette ? const Color(0xFF5B6B80) : const Color(0xFF6B7C96);

  // ── Borders & Dividers ──────────────────────────────────────────────────────
  static Color get border =>
      _useLightPalette ? const Color(0xFFD5DEE9) : const Color(0xFF293952);
  static Color get borderSubtle =>
      _useLightPalette ? const Color(0xFFE3EAF2) : const Color(0xFF1D2A3D);
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

  // ── Dark Theme (Navy #0B1320 + Teal #19B6A4) ───────────────────────────────
  static ThemeData get darkTheme {
    const navyBackground = Color(0xFF0B1320);
    const darkSurface = Color(0xFF111E33);
    const elevatedCardColor = Color(0xFF142036);
    const darkBorder = Color(0xFF1E2D4A);
    const tealPrimary = Color(0xFF19B6A4);
    const textLight = Color(0xFFF8FAFC);
    const textDim = Color(0xFFA5B4CB);

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
        secondary: Color(0xFF2DD4BF),
        tertiary: Color(0xFF0F766E),
        surface: darkSurface,
        error: Color(0xFFEF4444),
        onPrimary: navyBackground,
        onSecondary: navyBackground,
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
        overlayColor: Color(0x2219B6A4),
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
        indicatorColor: const Color(0x2419B6A4),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            inherit: false,
            fontFamily: 'Inter',
            fontFamilyFallback: fontBodyFamilies,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? const Color(0xFF19B6A4) : const Color(0xFF7E91B0),
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? const Color(0xFF19B6A4) : const Color(0xFF7E91B0),
          );
        }),
      ),
    );
  }

  // ── Light Theme Architecture ────────────────────────────────────────────────
  static ThemeData get lightTheme {
    const lightBg = Color(0xFFF8FAFC);
    const lightSurface = Color(0xFFFFFFFF);
    const lightCard = Color(0xFFFFFFFF);
    const lightBorder = Color(0xFFE2E8F0);
    const lightTextPrimary = Color(0xFF0F172A);
    const lightTextSecondary = Color(0xFF475569);
    const lightTextMuted = Color(0xFF94A3B8);
    const tealPrimary = Color(0xFF0D9488);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      dividerColor: lightBorder,
      fontFamily: 'Inter',
      fontFamilyFallback: fontBodyFamilies,
      extensions: const [PharmaThemeTokens.light],
      colorScheme: const ColorScheme.light(
        primary: tealPrimary,
        secondary: Color(0xFF14B8A6),
        tertiary: Color(0xFF102A43),
        surface: lightSurface,
        error: Color(0xFFEF4444),
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
          backgroundColor: tealPrimary,
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
          foregroundColor: tealPrimary,
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
          borderSide: const BorderSide(color: tealPrimary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: lightTextSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: lightTextMuted, fontSize: 13),
        prefixIconColor: lightTextMuted,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: const Color(0x200D9488),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            inherit: false,
            fontFamily: 'Inter',
            fontFamilyFallback: fontBodyFamilies,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
          );
        }),
      ),
    );
  }
}
