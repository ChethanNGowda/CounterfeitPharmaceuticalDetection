import 'package:flutter/material.dart';
import 'package:pharma_assist/core/theme.dart';

class ConfidenceGauge extends StatelessWidget {
  final double confidence; // Normalized 0.0 to 1.0 or already percentage
  final double? authenticProb;
  final double? counterfeitProb;

  const ConfidenceGauge({
    super.key,
    required this.confidence,
    this.authenticProb,
    this.counterfeitProb,
  });

  @override
  Widget build(BuildContext context) {
    // Correctly normalize to 0.0 .. 1.0 range
    final double norm = confidence > 1.0 ? confidence / 100.0 : confidence;
    final double clamped = norm.clamp(0.0, 1.0);
    final String pctString = '${(clamped * 100).toStringAsFixed(1)}%';

    Color progressColor;
    if (clamped >= 0.90) {
      progressColor = AppTheme.authenticGreen;
    } else if (clamped >= 0.70) {
      progressColor = AppTheme.primaryTeal;
    } else {
      progressColor = AppTheme.suspiciousAmber;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Primary Model Confidence',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                pctString,
                style: TextStyle(
                  color: progressColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 10,
              backgroundColor: AppTheme.cardColor,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          if (authenticProb != null && counterfeitProb != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _probIndicator(
                    label: 'Authentic Prob',
                    prob: authenticProb!,
                    color: AppTheme.authenticGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _probIndicator(
                    label: 'Counterfeit Prob',
                    prob: counterfeitProb!,
                    color: AppTheme.counterfeitRed,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _probIndicator({
    required String label,
    required double prob,
    required Color color,
  }) {
    final double norm = prob > 1.0 ? prob / 100.0 : prob;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${(norm * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
