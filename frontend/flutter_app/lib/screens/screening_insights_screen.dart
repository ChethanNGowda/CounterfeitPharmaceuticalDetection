import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/core/theme_tokens.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/widgets/pharma_components.dart';

/// Clinical & Operational Screening Insights derived entirely from real local records
class ScreeningInsightsScreen extends StatefulWidget {
  final StorageService storage;

  const ScreeningInsightsScreen({super.key, required this.storage});

  @override
  State<ScreeningInsightsScreen> createState() =>
      _ScreeningInsightsScreenState();
}

class _ScreeningInsightsScreenState extends State<ScreeningInsightsScreen> {
  late List<ScanHistoryItem> _history;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _history = widget.storage.getScanHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pharmaTokens;
    final theme = Theme.of(context);

    final total = _history.length;
    final authenticCount = _history.where((h) => h.isLikelyAuthentic).length;
    final counterfeitCount = _history
        .where((h) => h.isLikelyCounterfeit)
        .length;
    final reviewCount = _history
        .where((h) => h.isSuspicious || h.needsHumanVerification)
        .length;

    final qualityPassCount = _history.where((h) => h.qualityAccepted).length;
    final qualityFailCount = total - qualityPassCount;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Screening Insights'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh Insights',
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: total == 0
          ? _buildEmptyState(tokens)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Prominent Regulatory & Prevalence Notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: tokens.tealAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Data Notice: These metrics reflect inspection scans recorded on this local device. '
                          'They describe user screening history only, and do NOT represent actual counterfeit pharmaceutical market prevalence.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Top Metric Cards Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'Total Screenings',
                        '$total',
                        'Recorded Scans',
                        tokens.deepBlue,
                        tokens.surfaceSubtle,
                        tokens,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        'Authentic',
                        '$authenticCount',
                        total > 0
                            ? '${(authenticCount / total * 100).toStringAsFixed(1)}%'
                            : '0%',
                        tokens.authenticGreen,
                        tokens.authenticGreenBg,
                        tokens,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'Counterfeit',
                        '$counterfeitCount',
                        total > 0
                            ? '${(counterfeitCount / total * 100).toStringAsFixed(1)}%'
                            : '0%',
                        tokens.counterfeitRed,
                        tokens.counterfeitRedBg,
                        tokens,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        'Manual Review',
                        '$reviewCount',
                        total > 0
                            ? '${(reviewCount / total * 100).toStringAsFixed(1)}%'
                            : '0%',
                        tokens.suspiciousAmber,
                        tokens.suspiciousAmberBg,
                        tokens,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Outcome Breakdown Bar
                PharmaCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Screening Outcome Distribution',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 14,
                          child: Row(
                            children: [
                              if (authenticCount > 0)
                                Expanded(
                                  flex: authenticCount,
                                  child: Container(
                                    color: tokens.authenticGreen,
                                  ),
                                ),
                              if (counterfeitCount > 0)
                                Expanded(
                                  flex: counterfeitCount,
                                  child: Container(
                                    color: tokens.counterfeitRed,
                                  ),
                                ),
                              if (reviewCount > 0)
                                Expanded(
                                  flex: reviewCount,
                                  child: Container(
                                    color: tokens.suspiciousAmber,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _legendItem(
                            'Authentic ($authenticCount)',
                            tokens.authenticGreen,
                          ),
                          _legendItem(
                            'Counterfeit ($counterfeitCount)',
                            tokens.counterfeitRed,
                          ),
                          _legendItem(
                            'Review ($reviewCount)',
                            tokens.suspiciousAmber,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Image Quality Gate Analysis
                PharmaCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Image Quality Validation',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(
                            Icons.camera_enhance_outlined,
                            size: 18,
                            color: tokens.tealAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'The OpenCV image quality gate verifies illumination, blur, and focus before inference runs.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _miniStat(
                              'Accepted',
                              '$qualityPassCount',
                              total > 0
                                  ? '${(qualityPassCount / total * 100).toInt()}%'
                                  : '0%',
                              tokens.authenticGreen,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _miniStat(
                              'Retakes Advised',
                              '$qualityFailCount',
                              total > 0
                                  ? '${(qualityFailCount / total * 100).toInt()}%'
                                  : '0%',
                              tokens.suspiciousAmber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Recent Screening Activity
                Text(
                  'Recent Screening Activity',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ..._history.take(5).map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.elevatedCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item.isLikelyAuthentic
                                ? tokens.authenticGreen
                                : item.isLikelyCounterfeit
                                ? tokens.counterfeitRed
                                : tokens.suspiciousAmber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.medicineName ?? item.sampleId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                              Text(
                                '${DateFormat('MMM d, HH:mm').format(item.timestamp)} • ${item.verdictDisplay}',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(item.confidence * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: tokens.deepBlue,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    String subtitle,
    Color color,
    Color bg,
    PharmaThemeTokens tokens,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String count, String pct, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.secondaryBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            '$count ($pct)',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(PharmaThemeTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights_outlined, size: 48, color: tokens.textMuted),
            const SizedBox(height: 14),
            Text('No Screening Insights Yet', style: AppTheme.headingSmall()),
            const SizedBox(height: 6),
            Text(
              'Conduct pharmaceutical tablet screenings to view breakdown trends, image quality rates, and activity statistics.',
              style: AppTheme.bodyText(color: tokens.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
