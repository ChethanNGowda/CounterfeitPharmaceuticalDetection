import 'package:flutter/material.dart';

/// PharmaAssist Healthcare Design Tokens Extension
/// Providing semantic healthcare colors, borders, and brand accents via Theme.of(context).
@immutable
class PharmaThemeTokens extends ThemeExtension<PharmaThemeTokens> {
  final Color navyBrand;
  final Color tealAccent;
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
    required this.tealAccent,
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

  /// Light theme token specifications
  static const light = PharmaThemeTokens(
    navyBrand: Color(0xFF0B1320),
    tealAccent: Color(0xFF19B6A4),
    surfaceSubtle: Color(0xFFF1F5F9),
    borderSubtle: Color(0xFFE2E8F0),
    authenticGreen: Color(0xFF10B981),
    authenticGreenBg: Color(0xFFECFDF5),
    counterfeitRed: Color(0xFFEF4444),
    counterfeitRedBg: Color(0xFFFEF2F2),
    suspiciousAmber: Color(0xFFF59E0B),
    suspiciousAmberBg: Color(0xFFFFFBEB),
    textMuted: Color(0xFF64748B),
    cardElevated: Color(0xFFFFFFFF),
  );

  /// Dark theme token specifications (Navy Brand #0B1320 + Teal #19B6A4)
  static const dark = PharmaThemeTokens(
    navyBrand: Color(0xFF0B1320),
    tealAccent: Color(0xFF19B6A4),
    surfaceSubtle: Color(0xFF111E33),
    borderSubtle: Color(0xFF1E2D4A),
    authenticGreen: Color(0xFF10B981),
    authenticGreenBg: Color(0xFF063022),
    counterfeitRed: Color(0xFFEF4444),
    counterfeitRedBg: Color(0xFF381418),
    suspiciousAmber: Color(0xFFF59E0B),
    suspiciousAmberBg: Color(0xFF382A0E),
    textMuted: Color(0xFF7E91B0),
    cardElevated: Color(0xFF142036),
  );

  @override
  PharmaThemeTokens copyWith({
    Color? navyBrand,
    Color? tealAccent,
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
      tealAccent: tealAccent ?? this.tealAccent,
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
      tealAccent: Color.lerp(tealAccent, other.tealAccent, t)!,
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
