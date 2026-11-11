import 'package:flutter/material.dart';

/// PharmaAssist Healthcare Design Tokens Extension
/// Providing semantic healthcare colors, borders, and brand accents via Theme.of(context).
@immutable
class PharmaThemeTokens extends ThemeExtension<PharmaThemeTokens> {
  final Color navyBrand;
  final Color primaryBlue;
  final Color deepBlue;
  final Color tealAccent;
  final Color softMint;
  final Color powderBlue;
  final Color surfaceSubtle;
  final Color borderSubtle;
  final Color authenticGreen;
  final Color authenticGreenBg;
  final Color counterfeitRed;
  final Color counterfeitRedBg;
  final Color suspiciousAmber;
  final Color suspiciousAmberBg;
  final Color textMuted;
  final Color cardElevated;

  const PharmaThemeTokens({
    required this.navyBrand,
    required this.primaryBlue,
    required this.deepBlue,
    required this.tealAccent,
    required this.softMint,
    required this.powderBlue,
    required this.surfaceSubtle,
    required this.borderSubtle,
    required this.authenticGreen,
    required this.authenticGreenBg,
    required this.counterfeitRed,
    required this.counterfeitRedBg,
    required this.suspiciousAmber,
    required this.suspiciousAmberBg,
    required this.textMuted,
    required this.cardElevated,
  });

  /// Light theme token specifications — Refined pharmaceutical technology palette
  static const light = PharmaThemeTokens(
    navyBrand: Color(0xFF174A6E),
    primaryBlue: Color(0xFF25658A),
    deepBlue: Color(0xFF174A6E),
    tealAccent: Color(0xFF0F8B83),
    softMint: Color(0xFFDDF4EF),
    powderBlue: Color(0xFFDCE8F8),
    surfaceSubtle: Color(0xFFEAF4FA),
    borderSubtle: Color(0xFFDCE6ED),
    authenticGreen: Color(0xFF16845B),
    authenticGreenBg: Color(0xFFDDF4EF),
    counterfeitRed: Color(0xFFC74747),
    counterfeitRedBg: Color(0xFFFDE8E8),
    suspiciousAmber: Color(0xFFC47A18),
    suspiciousAmberBg: Color(0xFFFFF3D9),
    textMuted: Color(0xFF647B8C),
    cardElevated: Color(0xFFFFFFFF),
  );

  /// Dark theme token specifications — Blue-slate surfaces rather than black
  static const dark = PharmaThemeTokens(
    navyBrand: Color(0xFF102A43),
    primaryBlue: Color(0xFF24485A),
    deepBlue: Color(0xFF102A43),
    tealAccent: Color(0xFF48C5B3),
    softMint: Color(0xFF244F50),
    powderBlue: Color(0xFF1D4659),
    surfaceSubtle: Color(0xFF193B53),
    borderSubtle: Color(0xFF35586C),
    authenticGreen: Color(0xFF16845B),
    authenticGreenBg: Color(0xFF244F50),
    counterfeitRed: Color(0xFFEF4444),
    counterfeitRedBg: Color(0xFF381418),
    suspiciousAmber: Color(0xFFF59E0B),
    suspiciousAmberBg: Color(0xFF382A0E),
    textMuted: Color(0xFFB9CCD9),
    cardElevated: Color(0xFF24485A),
  );

  @override
  PharmaThemeTokens copyWith({
    Color? navyBrand,
    Color? primaryBlue,
    Color? deepBlue,
    Color? tealAccent,
    Color? softMint,
    Color? powderBlue,
    Color? surfaceSubtle,
    Color? borderSubtle,
    Color? authenticGreen,
    Color? authenticGreenBg,
    Color? counterfeitRed,
    Color? counterfeitRedBg,
    Color? suspiciousAmber,
    Color? suspiciousAmberBg,
    Color? textMuted,
    Color? cardElevated,
  }) {
    return PharmaThemeTokens(
      navyBrand: navyBrand ?? this.navyBrand,
      primaryBlue: primaryBlue ?? this.primaryBlue,
      deepBlue: deepBlue ?? this.deepBlue,
      tealAccent: tealAccent ?? this.tealAccent,
      softMint: softMint ?? this.softMint,
      powderBlue: powderBlue ?? this.powderBlue,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      authenticGreen: authenticGreen ?? this.authenticGreen,
      authenticGreenBg: authenticGreenBg ?? this.authenticGreenBg,
      counterfeitRed: counterfeitRed ?? this.counterfeitRed,
      counterfeitRedBg: counterfeitRedBg ?? this.counterfeitRedBg,
      suspiciousAmber: suspiciousAmber ?? this.suspiciousAmber,
      suspiciousAmberBg: suspiciousAmberBg ?? this.suspiciousAmberBg,
      textMuted: textMuted ?? this.textMuted,
      cardElevated: cardElevated ?? this.cardElevated,
    );
  }

  @override
  PharmaThemeTokens lerp(ThemeExtension<PharmaThemeTokens>? other, double t) {
    if (other is! PharmaThemeTokens) return this;
    return PharmaThemeTokens(
      navyBrand: Color.lerp(navyBrand, other.navyBrand, t)!,
      primaryBlue: Color.lerp(primaryBlue, other.primaryBlue, t)!,
      deepBlue: Color.lerp(deepBlue, other.deepBlue, t)!,
      tealAccent: Color.lerp(tealAccent, other.tealAccent, t)!,
      softMint: Color.lerp(softMint, other.softMint, t)!,
      powderBlue: Color.lerp(powderBlue, other.powderBlue, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      authenticGreen: Color.lerp(authenticGreen, other.authenticGreen, t)!,
      authenticGreenBg: Color.lerp(
        authenticGreenBg,
        other.authenticGreenBg,
        t,
      )!,
      counterfeitRed: Color.lerp(counterfeitRed, other.counterfeitRed, t)!,
      counterfeitRedBg: Color.lerp(
        counterfeitRedBg,
        other.counterfeitRedBg,
        t,
      )!,
      suspiciousAmber: Color.lerp(suspiciousAmber, other.suspiciousAmber, t)!,
      suspiciousAmberBg: Color.lerp(
        suspiciousAmberBg,
        other.suspiciousAmberBg,
        t,
      )!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      cardElevated: Color.lerp(cardElevated, other.cardElevated, t)!,
    );
  }
}

/// Extension on BuildContext for quick access to PharmaThemeTokens
extension PharmaThemeContext on BuildContext {
  PharmaThemeTokens get pharmaTokens =>
      Theme.of(this).extension<PharmaThemeTokens>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? PharmaThemeTokens.dark
          : PharmaThemeTokens.light);
}
