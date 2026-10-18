import 'package:flutter/material.dart';
import 'package:pharma_assist/core/theme.dart';

class StatusBadge extends StatelessWidget {
  final String statusText;
  final bool isLarge;

  const StatusBadge({
    super.key,
    required this.statusText,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final String upper = statusText.toUpperCase();
    final bool isAuthentic = upper.contains('AUTHENTIC') &&
        !upper.contains('SUSPICIOUS') &&
        !upper.contains('VERIFICATION');
    final bool isCounterfeit = upper.contains('COUNTERFEIT') &&
        !upper.contains('SUSPICIOUS') &&
        !upper.contains('VERIFICATION');

    Color bg;
    Color fg;
    Color border;
    IconData icon;
    String displayLabel = statusText;

    if (isAuthentic) {
      bg = AppTheme.authenticBg;
      fg = AppTheme.authenticGreen;
      border = AppTheme.authenticGreen.withValues(alpha: 0.5);
      icon = Icons.verified_outlined;
    } else if (isCounterfeit) {
      bg = AppTheme.counterfeitBg;
      fg = AppTheme.counterfeitRed;
      border = AppTheme.counterfeitRed.withValues(alpha: 0.5);
      icon = Icons.gpp_bad_outlined;
    } else {
      bg = AppTheme.suspiciousBg;
      fg = AppTheme.suspiciousAmber;
      border = AppTheme.suspiciousAmber.withValues(alpha: 0.5);
      icon = Icons.warning_amber_rounded;
    }

    final double padH = isLarge ? 14 : 10;
    final double padV = isLarge ? 8 : 4;
    final double fontSize = isLarge ? 15 : 12;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: isLarge ? 18 : 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              displayLabel,
              style: TextStyle(
                color: fg,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
