import 'package:flutter/material.dart';
import 'package:pharma_assist/core/theme_tokens.dart';

/// PharmaAssist Material 3 design system.
///
/// ThemeData is the source for components. The static color getters below are
/// retained for older feature widgets and resolve from the active system
/// palette selected by [PharmaAssistApp].
class AppTheme {
  static bool _useLightPalette = false;

  static void setPalette(bool light) => _useLightPalette = light;

  static const _light = _Palette(
    background: Color(0xFFF4F8FB),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFEAF4FA),
    elevated: Color(0xFFFFFFFF),
    border: Color(0xFFDCE6ED),
    primary: Color(0xFF25658A),
    accent: Color(0xFF0F8B83),
    deep: Color(0xFF174A6E),
    text: Color(0xFF183247),
    textMuted: Color(0xFF526B7C),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF16845B),
    successContainer: Color(0xFFDDF4EF),
    error: Color(0xFFC74747),
    errorContainer: Color(0xFFFDE8E8),
    warning: Color(0xFF805000),
    warningContainer: Color(0xFFFFF3D9),
  );

  static const _dark = _Palette(
    background: Color(0xFF102A43),
    surface: Color(0xFF193B53),
    surfaceSubtle: Color(0xFF1D4659),
    elevated: Color(0xFF24485A),
    border: Color(0xFF49697B),
    primary: Color(0xFF48C5B3),
    accent: Color(0xFF48C5B3),
    deep: Color(0xFF102A43),
    text: Color(0xFFF0F6FA),
    textMuted: Color(0xFFB9CCD9),
    onPrimary: Color(0xFF092B31),
    success: Color(0xFF6ED6AE),
    successContainer: Color(0xFF244F50),
    error: Color(0xFFFF8585),
    errorContainer: Color(0xFF381418),
    warning: Color(0xFFFFC45C),
    warningContainer: Color(0xFF382A0E),
  );

  static _Palette get _active => _useLightPalette ? _light : _dark;

  // Compatibility tokens used by existing feature screens.
  static Color get background => _active.background;
  static Color get secondaryBackground => _active.surface;
  static Color get elevatedCard => _active.elevated;
  static Color get surface => secondaryBackground;
  static Color get cardColor => elevatedCard;
  static Color get surfaceHighlight => _active.surfaceSubtle;
  static Color get primaryBlue => _active.primary;
  static Color get deepBlue => _active.deep;
  static Color get onPrimary => _active.onPrimary;
  static Color get primaryCyan => _active.primary;
  static Color get secondaryTeal => _active.accent;
  static Color get softMint => _active.successContainer;
  static Color get powderBlue => _active.surfaceSubtle;
  static Color get softViolet => secondaryTeal;
  static Color get violetAccent => secondaryTeal;
  static Color get primaryTeal => secondaryTeal;
  static Color get primaryTealDim => _active.surfaceSubtle;
  static Color get success => _active.success;
  static Color get warning => _active.warning;
  static Color get error => _active.error;
  static Color get authenticGreen => _active.success;
  static Color get authenticBg => _active.successContainer;
  static Color get counterfeitRed => _active.error;
  static Color get counterfeitBg => _active.errorContainer;
  static Color get suspiciousAmber => _active.warning;
  static Color get suspiciousBg => _active.warningContainer;
  static Color get textPrimary => _active.text;
  static Color get textSecondary => _active.textMuted;
  static Color get textMuted => _active.textMuted;
  static Color get border => _active.border;
  static Color get borderSubtle => _active.border;
  static Color get divider => _active.border;

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

  static ThemeData get darkTheme => _buildTheme(_dark, Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(_light, Brightness.light);

  static ThemeData _buildTheme(_Palette colors, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: isDark
          ? const Color(0xFF1D4659)
          : const Color(0xFFDCE8F8),
      onPrimaryContainer: isDark ? colors.text : const Color(0xFF123B56),
      secondary: colors.accent,
      onSecondary: isDark ? colors.deep : Colors.white,
      secondaryContainer: isDark
          ? const Color(0xFF244F50)
          : const Color(0xFFDDF4EF),
      onSecondaryContainer: isDark ? colors.text : const Color(0xFF103D37),
      tertiary: isDark ? const Color(0xFF8CC8E8) : colors.deep,
      onTertiary: isDark ? const Color(0xFF102A43) : Colors.white,
      tertiaryContainer: isDark
          ? const Color(0xFF24485A)
          : const Color(0xFFE4EEF6),
      onTertiaryContainer: colors.text,
      error: colors.error,
      onError: isDark ? const Color(0xFF390B0B) : Colors.white,
      errorContainer: colors.errorContainer,
      onErrorContainer: colors.text,
      surface: colors.surface,
      onSurface: colors.text,
      onSurfaceVariant: colors.textMuted,
      outline: colors.border,
      outlineVariant: isDark ? const Color(0xFF35586C) : colors.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isDark
          ? const Color(0xFFE6F0F4)
          : const Color(0xFF193B53),
      onInverseSurface: isDark ? const Color(0xFF193B53) : Colors.white,
      inversePrimary: isDark
          ? const Color(0xFF25658A)
          : const Color(0xFF48C5B3),
      surfaceTint: colors.primary,
    );

    final textTheme = _textTheme(colors.text, colors.textMuted);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PharmaRadii.card),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PharmaRadii.control),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(PharmaRadii.control),
      borderSide: BorderSide(color: colors.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.surface,
      dividerColor: colors.border,
      fontFamily: 'Inter',
      fontFamilyFallback: fontBodyFamilies,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [isDark ? PharmaThemeTokens.dark : PharmaThemeTokens.light],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: colors.background,
        centerTitle: false,
        iconTheme: IconThemeData(color: colors.textMuted, size: 24),
        actionsIconTheme: IconThemeData(color: colors.textMuted, size: 24),
        titleTextStyle: TextStyle(
          fontFamily: 'Space Grotesk',
          fontFamilyFallback: fontHeadingFamilies,
          color: colors.text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.elevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shape.copyWith(side: BorderSide(color: colors.border)),
        margin: const EdgeInsets.symmetric(vertical: PharmaSpacing.xs),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.surfaceSubtle,
          disabledForegroundColor: colors.textMuted,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: buttonShape,
          textStyle: _buttonTextStyle,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: buttonShape,
          textStyle: _buttonTextStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: colors.border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: buttonShape,
          textStyle: _buttonTextStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: buttonShape,
          textStyle: _buttonTextStyle,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textMuted,
          minimumSize: const Size(48, 48),
          shape: buttonShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PharmaRadii.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PharmaSpacing.md,
          vertical: PharmaSpacing.sm,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 1.7),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.error, width: 1.7),
        ),
        labelStyle: TextStyle(color: colors.textMuted, fontSize: 14),
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
        helperStyle: TextStyle(color: colors.textMuted, fontSize: 12),
        errorStyle: TextStyle(color: colors.error, fontSize: 12),
        prefixIconColor: colors.textMuted,
        suffixIconColor: colors.textMuted,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colors.surface,
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: inputBorder.copyWith(
            borderSide: BorderSide(color: colors.primary, width: 1.7),
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.elevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(shape),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.elevated,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: shape,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PharmaRadii.sheet),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceSubtle,
        selectedColor: colors.primary.withValues(alpha: 0.15),
        disabledColor: colors.surfaceSubtle,
        secondarySelectedColor: colors.primary.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(horizontal: PharmaSpacing.xs),
        labelStyle: textTheme.labelLarge!,
        secondaryLabelStyle: textTheme.labelLarge!,
        shape: StadiumBorder(side: BorderSide(color: colors.border)),
        side: BorderSide(color: colors.border),
        showCheckmark: true,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.textMuted,
        indicatorColor: colors.primary,
        dividerColor: colors.border,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceSubtle,
        circularTrackColor: colors.surfaceSubtle,
        refreshBackgroundColor: colors.elevated,
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textMuted,
        textColor: colors.text,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PharmaSpacing.md,
        ),
        minLeadingWidth: 40,
        minVerticalPadding: PharmaSpacing.xs,
        shape: buttonShape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 76,
        indicatorColor: colors.primary.withValues(alpha: isDark ? 0.2 : 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colors.primary : colors.textMuted,
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.primary : colors.textMuted,
            size: 24,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: isDark ? 0.2 : 0.12),
        selectedIconTheme: IconThemeData(color: colors.primary),
        unselectedIconTheme: IconThemeData(color: colors.textMuted),
        selectedLabelTextStyle: TextStyle(
          color: colors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: colors.textMuted,
          fontSize: 12,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFFE6F0F4)
            : const Color(0xFF193B53),
        contentTextStyle: TextStyle(
          color: isDark ? const Color(0xFF193B53) : Colors.white,
          fontSize: 14,
        ),
        actionTextColor: isDark
            ? const Color(0xFF174A6E)
            : const Color(0xFF48C5B3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PharmaRadii.control),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFFE6F0F4) : const Color(0xFF193B53),
          borderRadius: BorderRadius.circular(PharmaRadii.small),
        ),
        textStyle: TextStyle(
          color: isDark ? const Color(0xFF193B53) : Colors.white,
          fontSize: 12,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return null;
        }),
        checkColor: WidgetStatePropertyAll(colors.onPrimary),
        side: BorderSide(color: colors.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PharmaRadii.small),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.surfaceSubtle,
        ),
        trackOutlineColor: WidgetStatePropertyAll(colors.border),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.textMuted,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.onPrimary
                : colors.text,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.primary
                : colors.surface,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
          shape: WidgetStatePropertyAll(buttonShape),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.elevated,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        textStyle: textTheme.bodyMedium,
      ),
    );
  }

  static const _buttonTextStyle = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: fontBodyFamilies,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static TextTheme _textTheme(Color foreground, Color muted) {
    final base = Typography.material2021().black;
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: fontHeadingFamilies,
        color: foreground,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: fontHeadingFamilies,
        color: foreground,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: fontHeadingFamilies,
        color: foreground,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: fontHeadingFamilies,
        color: foreground,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: fontHeadingFamilies,
        color: foreground,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: fontHeadingFamilies,
        color: foreground,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: fontHeadingFamilies,
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: 'Inter',
        fontFamilyFallback: fontBodyFamilies,
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontFamily: 'Inter',
        fontFamilyFallback: fontBodyFamilies,
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontFamily: 'Inter',
        fontFamilyFallback: fontBodyFamilies,
        color: foreground,
        height: 1.45,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: 'Inter',
        fontFamilyFallback: fontBodyFamilies,
        color: foreground,
        height: 1.45,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontFamily: 'Inter',
        fontFamilyFallback: fontBodyFamilies,
        color: muted,
        height: 1.4,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontFamily: 'Inter',
        fontFamilyFallback: fontBodyFamilies,
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontFamily: 'Inter',
        fontFamilyFallback: fontBodyFamilies,
        color: muted,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontFamily: 'Inter',
        fontFamilyFallback: fontBodyFamilies,
        color: muted,
      ),
    );
  }
}

class _Palette {
  final Color background;
  final Color surface;
  final Color surfaceSubtle;
  final Color elevated;
  final Color border;
  final Color primary;
  final Color accent;
  final Color deep;
  final Color text;
  final Color textMuted;
  final Color onPrimary;
  final Color success;
  final Color successContainer;
  final Color error;
  final Color errorContainer;
  final Color warning;
  final Color warningContainer;

  const _Palette({
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.elevated,
    required this.border,
    required this.primary,
    required this.accent,
    required this.deep,
    required this.text,
    required this.textMuted,
    required this.onPrimary,
    required this.success,
    required this.successContainer,
    required this.error,
    required this.errorContainer,
    required this.warning,
    required this.warningContainer,
  });
}
