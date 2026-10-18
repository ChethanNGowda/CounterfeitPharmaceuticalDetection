import 'package:flutter/material.dart';

/// Centralized scientific design system and color tokens for PharmaAssist.
/// Palette specifications:
/// - Primary background: #0B1020
/// - Secondary background: #111A2E
/// - Elevated cards: #17243A
/// - Primary cyan: #25D9F8
/// - Secondary teal: #35D6B4
/// - Soft violet accent: #8B7CFF
/// - Primary text: #F3F6FC
/// - Secondary text: #A5B2C7
/// - Borders and dividers: #293952
/// - Success: #36C98F
/// - Warning: #F6BD60
/// - Error: #FF647C
class AppTheme {
  // ── Surface and Background Tokens ───────────────────────────────────────────
  static const Color background = Color(0xFF0B1020);
  static const Color secondaryBackground = Color(0xFF111A2E);
  static const Color elevatedCard = Color(0xFF17243A);
  
  // Backward compatibility aliases
  static const Color surface = Color(0xFF111A2E);
  static const Color cardColor = Color(0xFF17243A);
  static const Color surfaceHighlight = Color(0xFF1F2F4A);

  // ── Brand & Accent Colors ───────────────────────────────────────────────────
  static const Color primaryCyan = Color(0xFF25D9F8);
  static const Color secondaryTeal = Color(0xFF35D6B4);
  static const Color softViolet = Color(0xFF8B7CFF);
  static const Color violetAccent = Color(0xFF8B7CFF);

  // Backward compatibility aliases
  static const Color primaryTeal = Color(0xFF35D6B4);
  static const Color primaryTealDim = Color(0xFF209A80);

  // ── Semantic Feedback Colors ────────────────────────────────────────────────
  static const Color success = Color(0xFF36C98F);
  static const Color warning = Color(0xFFF6BD60);
  static const Color error = Color(0xFFFF647C);

  // Backward compatibility aliases
  static const Color authenticGreen = Color(0xFF36C98F);
  static const Color authenticBg = Color(0xFF0E2E20);
  static const Color counterfeitRed = Color(0xFFFF647C);
  static const Color counterfeitBg = Color(0xFF34141E);
  static const Color suspiciousAmber = Color(0xFFF6BD60);
  static const Color suspiciousBg = Color(0xFF332612);

  // ── Text & Typography Colors ────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF3F6FC);
  static const Color textSecondary = Color(0xFFA5B2C7);
  static const Color textMuted = Color(0xFF6B7C96);

  // ── Borders & Dividers ──────────────────────────────────────────────────────
  static const Color border = Color(0xFF293952);
  static const Color borderSubtle = Color(0xFF1D2A3D);
  static const Color divider = Color(0xFF293952);

  // ── Distinct Typography Tokens with Graceful Fallbacks ──────────────────────
  static const List<String> fontHeadingFamilies = ['Space Grotesk', 'Roboto', 'sans-serif'];
  static const List<String> fontBodyFamilies = ['Inter', 'Roboto', 'sans-serif'];
  static const List<String> fontCodeFamilies = ['JetBrains Mono', 'monospace'];

  static TextStyle headingLarge({Color color = textPrimary}) => TextStyle(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: fontHeadingFamilies,
        color: color,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      );

  static TextStyle headingMedium({Color color = textPrimary}) => TextStyle(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: fontHeadingFamilies,
        color: color,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      );

  static TextStyle headingSmall({Color color = textPrimary}) => TextStyle(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: fontHeadingFamilies,
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      );

  static TextStyle bodyText({Color color = textPrimary, double fontSize = 13, FontWeight fontWeight = FontWeight.w400}) => TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: fontBodyFamilies,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: 1.45,
      );

  static TextStyle monoNumeric({Color color = textPrimary, double fontSize = 14, FontWeight fontWeight = FontWeight.w600}) => TextStyle(
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: fontCodeFamilies,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: 0.2,
      );

  // ── Dark Theme (Default) ────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      dividerColor: divider,
      fontFamily: 'Inter',
      fontFamilyFallback: fontBodyFamilies,
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: secondaryTeal,
        tertiary: softViolet,
        surface: secondaryBackground,
        error: error,
        onPrimary: Color(0xFF0B1020),
        onSecondary: Color(0xFF0B1020),
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textSecondary),
        actionsIconTheme: IconThemeData(color: textSecondary),
        titleTextStyle: TextStyle(
          fontFamily: 'Space Grotesk',
          fontFamilyFallback: fontHeadingFamilies,
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
      cardTheme: CardThemeData(
        color: elevatedCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCyan,
          foregroundColor: const Color(0xFF0B1020),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontFamilyFallback: fontHeadingFamilies,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryCyan,
          side: const BorderSide(color: border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: fontBodyFamilies,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: secondaryBackground,
        selectedItemColor: primaryCyan,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: fontBodyFamilies,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: fontBodyFamilies,
          fontSize: 11,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryCyan, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        prefixIconColor: textMuted,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryCyan,
        inactiveTrackColor: border,
        thumbColor: primaryCyan,
        overlayColor: Color(0x2225D9F8),
        valueIndicatorColor: elevatedCard,
        valueIndicatorTextStyle: TextStyle(color: textPrimary, fontSize: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ── Light Theme Architecture ────────────────────────────────────────────────
  static ThemeData get lightTheme {
    const lightBg = Color(0xFFF4F7FC);
    const lightSurface = Color(0xFFFFFFFF);
    const lightCard = Color(0xFFF9FAFD);
    const lightBorder = Color(0xFFD6DFEC);
    const lightTextPrimary = Color(0xFF0F172A);
    const lightTextSecondary = Color(0xFF475569);
    const lightTextMuted = Color(0xFF94A3B8);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      dividerColor: lightBorder,
      fontFamily: 'Inter',
      fontFamilyFallback: fontBodyFamilies,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0891B2),
        secondary: Color(0xFF0D9488),
        tertiary: Color(0xFF7C3AED),
        surface: lightSurface,
        error: Color(0xFFE11D48),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
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
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0891B2),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontFamilyFallback: fontHeadingFamilies,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0891B2),
          side: const BorderSide(color: lightBorder, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: Color(0xFF0891B2),
        unselectedItemColor: lightTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0891B2), width: 1.5),
        ),
        labelStyle: const TextStyle(color: lightTextSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: lightTextMuted, fontSize: 13),
      ),
    );
  }
}
