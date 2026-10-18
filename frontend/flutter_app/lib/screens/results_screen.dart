import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/models/prediction_response.dart';
import 'package:pharma_assist/services/report_service.dart';
import 'package:pharma_assist/widgets/confidence_gauge.dart';
import 'package:pharma_assist/widgets/disclaimer_banner.dart';
import 'package:pharma_assist/widgets/expandable_card.dart';
import 'package:pharma_assist/widgets/status_badge.dart';

class ResultsScreen extends StatelessWidget {
  final PredictionResponse result;
  final File? imageFile;
  final String? sampleId;
  final String? medicineName;
  final String? notes;

  const ResultsScreen({
    super.key,
    required this.result,
    this.imageFile,
    this.sampleId,
    this.medicineName,
    this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSampleId = sampleId ??
        'SMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Field Screening Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 19),
            tooltip: 'Export Report',
            onPressed: () => _exportReport(context, effectiveSampleId),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            // 1. Primary Verdict Banner (3 distinct outcome states)
            _buildOutcomeBanner(),

            // 2. Sample Details Card
            const SizedBox(height: 12),
            _buildSampleInfoCard(effectiveSampleId),

            // 3. Human Review Alert if required
            if (result.needsHumanVerification) ...[
              const SizedBox(height: 12),
              _buildHumanReviewAlert(),
            ],

            // 4. Warning Box if present
            if (result.warning != null && result.warning!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildWarningBox(result.warning!),
            ],

            // 5. Primary Confidence Gauge
            const SizedBox(height: 16),
            ConfidenceGauge(
              confidence: result.confidence,
              authenticProb: result.authenticProbability,
              counterfeitProb: result.counterfeitProbability,
            ),

            // 6. Pipeline Summary Card
            const SizedBox(height: 12),
            _buildPipelineSummary(),

            // 7. Secondary AI Review (Qwen3-VL)
            const SizedBox(height: 6),
            _buildQwenCard(),

            // 8. Visual Feature Inspection (OpenCV)
            if (result.visualAnalysis != null) ...[
              const SizedBox(height: 6),
              _buildVisualAnalysisCard(),
            ],

            // 9. Image Quality Assessment
            if (result.quality != null) ...[
              const SizedBox(height: 6),
              _buildQualityCard(),
            ],

            // 10. Report Action Buttons
            const SizedBox(height: 20),
            _buildReportActionButtons(context, effectiveSampleId),

            // 11. Mandatory Regulatory Disclaimer
            const SizedBox(height: 20),
            DisclaimerBanner(customText: result.disclaimer),
          ],
        ),
      ),
    );
  }

  // ── Three Distinct Outcome States ───────────────────────────────────────────

  Widget _buildOutcomeBanner() {
    final String verdict = result.finalResult.toUpperCase();
    final bool isAuthentic = verdict.contains('AUTHENTIC') &&
        !verdict.contains('SUSPICIOUS') &&
        !verdict.contains('VERIFICATION');
    final bool isCounterfeit = verdict.contains('COUNTERFEIT') &&
        !verdict.contains('SUSPICIOUS') &&
        !verdict.contains('VERIFICATION');

    Color outcomeColor;
    Color outcomeBg;
    IconData outcomeIcon;
    String outcomeHeader;
    String outcomeSubtitle;

    if (isAuthentic) {
      outcomeColor = AppTheme.authenticGreen;
      outcomeBg = AppTheme.authenticBg;
      outcomeIcon = Icons.verified_outlined;
      outcomeHeader = 'SCREENING INDICATES AUTHENTIC';
      outcomeSubtitle =
          'Optical and convolutional surface patterns match authentic reference models. '
          'Notice: Preliminary optical triage only; does not certify chemical purity or API bioequivalence.';
    } else if (isCounterfeit) {
      outcomeColor = AppTheme.counterfeitRed;
      outcomeBg = AppTheme.counterfeitBg;
      outcomeIcon = Icons.gpp_bad_outlined;
      outcomeHeader = 'SCREENING INDICATES COUNTERFEIT';
      outcomeSubtitle =
          'Optical irregularities, imprint deviations, or classifier confidence indicate potential adulteration. '
          'Immediately quarantine sample from dispensing supply chain and submit for laboratory testing.';
    } else {
      outcomeColor = AppTheme.suspiciousAmber;
      outcomeBg = AppTheme.suspiciousBg;
      outcomeIcon = Icons.warning_amber_rounded;
      outcomeHeader = 'INCONCLUSIVE · MANUAL REVIEW REQUIRED';
      outcomeSubtitle =
          'Borderline confidence score, conflicting secondary review, or optical variances detected. '
          'Visual automated screening cannot provide conclusive clearance. Laboratory testing required.';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: outcomeColor.withValues(alpha: 0.6), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colored accent header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: outcomeBg,
            child: Row(
              children: [
                Icon(outcomeIcon, color: outcomeColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    outcomeHeader,
                    style: TextStyle(
                      color: outcomeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageFile != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          imageFile!,
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'FINAL VERDICT LABEL',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            result.finalResult,
                            style: TextStyle(
                              color: outcomeColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          StatusBadge(statusText: result.prediction),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  outcomeSubtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                if (result.reasons.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(height: 1, color: AppTheme.border),
                  const SizedBox(height: 10),
                  const Text(
                    'DECISION RATIONALE:',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ...result.reasons.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 5, right: 8),
                            decoration: BoxDecoration(
                              color: outcomeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              r,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sample Details Card ─────────────────────────────────────────────────────

  Widget _buildSampleInfoCard(String effectiveSampleId) {
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String timeStr = formatter.format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SAMPLE SPECIFICATIONS',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                timeStr,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _detailRow('Sample ID', effectiveSampleId),
          if (medicineName != null && medicineName!.isNotEmpty)
            _detailRow('Product / Medicine', medicineName!),
          if (notes != null && notes!.isNotEmpty)
            _detailRow('Field Notes', notes!),
          _detailRow('Primary Architecture', result.primaryModel),
          _detailRow('Classification Status', result.status),
        ],
      ),
    );
  }

  // ── Human Review Alert ──────────────────────────────────────────────────────

  Widget _buildHumanReviewAlert() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.suspiciousBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.suspiciousAmber.withValues(alpha: 0.6)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag_outlined, color: AppTheme.suspiciousAmber, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Physical Laboratory Verification Required',
                  style: TextStyle(
                    color: AppTheme.suspiciousAmber,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'This sample triggered the conservative safety rule due to low primary confidence, '
                  'secondary vision disagreement, or image quality variances. Quarantine the lot and submit for spectrometry.',
                  style: TextStyle(
                    color: Color(0xFFFED7AA),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Warning Box ─────────────────────────────────────────────────────────────

  Widget _buildWarningBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1500),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.suspiciousAmber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppTheme.suspiciousAmber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFFEF3C7),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pipeline Summary ────────────────────────────────────────────────────────

  Widget _buildPipelineSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PIPELINE EXECUTION TRACE',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _detailRow('Primary Classifier', result.primaryModel),
          _detailRow('Primary Prediction', result.prediction),
          _detailRow('Confidence Threshold', '${(result.threshold * 100).toStringAsFixed(0)}%'),
          _detailRow(
            'Secondary Executed',
            result.secondaryExecuted ? 'Yes (Qwen3-VL:4b)' : 'No (Fast Path / Skipped)',
          ),
          if (result.secondaryReason != null)
            _detailRow('Gating Reason', result.secondaryReason!),
          if (result.disagreement)
            _detailRow(
              'Model Agreement',
              'DISAGREEMENT DETECTED',
              valueColor: AppTheme.counterfeitRed,
            ),
        ],
      ),
    );
  }

  // ── Qwen3-VL Secondary Review ───────────────────────────────────────────────

  Widget _buildQwenCard() {
    final qwen = result.qwen;
    final String qwenStatus = qwen.available ? qwen.assessment : 'UNAVAILABLE';

    return ExpandableCard(
      title: 'Secondary AI Review (Qwen3-VL)',
      subtitle: qwen.available
          ? 'Qwen3-VL:4b · Assessment: ${qwen.assessment}'
          : 'Qwen3-VL · Service Offline or Skipped',
      icon: Icons.remove_red_eye_outlined,
      trailingBadge: StatusBadge(statusText: qwenStatus),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('Model', qwen.modelName ?? 'qwen3-vl:4b'),
          _detailRow('Service Availability', qwen.available ? 'Online' : 'Offline / Skipped'),
          _detailRow('Visual Assessment', qwen.assessment),
          _detailRow('Visual Confidence', qwen.confidenceDisplay),
          if (qwen.recommendation != null)
            _detailRow('Recommendation', qwen.recommendation!),
          if (qwen.imageQuality != null)
            _detailRow('Image Quality', qwen.imageQuality!),
          if (qwen.tabletShape != null)
            _detailRow('Detected Shape', qwen.tabletShape!),
          if (qwen.tabletColor != null)
            _detailRow('Detected Color', qwen.tabletColor!),
          if (qwen.tabletSurface != null)
            _detailRow('Surface Condition', qwen.tabletSurface!),
          if (qwen.tabletMarkings != null)
            _detailRow('Markings & Imprints', qwen.tabletMarkings!),
          if (qwen.tabletEdges != null)
            _detailRow('Edge Integrity', qwen.tabletEdges!),
          if (qwen.reasoning.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'REASONING POINTS:',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            ...qwen.reasoning.map(
              (pt) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• $pt', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.35)),
              ),
            ),
          ],
          if (qwen.finalExplanation != null && qwen.finalExplanation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              qwen.finalExplanation!,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10.5, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  // ── OpenCV Visual Analysis ──────────────────────────────────────────────────

  Widget _buildVisualAnalysisCard() {
    final v = result.visualAnalysis!;

    return ExpandableCard(
      title: 'Deterministic Feature Inspection',
      subtitle: 'OpenCV color centroid & contour analysis',
      icon: Icons.pattern_outlined,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (v.color != null) ...[
            _sectionLabel('COLOR CENTROIDS'),
            if (v.color!.dominantColor != null)
              _detailRow('Dominant Color', v.color!.dominantColor!),
            if (v.color!.consistency != null)
              _detailRow('Consistency', v.color!.consistency!),
            if (v.color!.averageRgb != null)
              _detailRow('Average RGB', v.color!.averageRgb!.map((e) => e.toStringAsFixed(1)).join(', ')),
          ],
          if (v.shape != null) ...[
            const SizedBox(height: 8),
            _sectionLabel('GEOMETRY & CONTOURS'),
            if (v.shape!.shapeType != null)
              _detailRow('Shape', v.shape!.shapeType!),
            if (v.shape!.circularity != null)
              _detailRow('Circularity', v.shape!.circularity!.toStringAsFixed(3)),
            if (v.shape!.symmetry != null)
              _detailRow('Symmetry', v.shape!.symmetry!),
          ],
          if (v.edges != null) ...[
            const SizedBox(height: 8),
            _sectionLabel('EDGE & SURFACE INTEGRITY'),
            if (v.edges!.edgeIntegrity != null)
              _detailRow('Edge Integrity', v.edges!.edgeIntegrity!),
            if (v.edges!.cracks != null)
              _detailRow('Cracks Detected', v.edges!.cracks!),
            if (v.edges!.chipping != null)
              _detailRow('Chipping', v.edges!.chipping!),
          ],
          if (v.packaging != null) ...[
            const SizedBox(height: 8),
            _sectionLabel('PACKAGING CLASSIFICATION'),
            if (v.packaging!.status != null)
              _detailRow('Status', v.packaging!.status!),
            if (v.packaging!.packagingType != null)
              _detailRow('Packaging Type', v.packaging!.packagingType!),
            if (v.packaging!.condition != null)
              _detailRow('Condition', v.packaging!.condition!),
          ],
        ],
      ),
    );
  }

  // ── OpenCV Quality Metrics ──────────────────────────────────────────────────

  Widget _buildQualityCard() {
    final q = result.quality!;

    return ExpandableCard(
      title: 'Image Quality Assessment',
      subtitle: q.isValid ? 'Passed sharpness & exposure criteria' : 'Quality checks flagged',
      icon: Icons.high_quality_outlined,
      trailingBadge: _qualityBadge(q.isValid),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('Resolution Dimensions', '${q.dimensions.join("×")} px (min 64×64)'),
          _detailRow('Laplacian Variance (Blur)', '${q.blurScore.toStringAsFixed(1)} (min 50.0)'),
          _detailRow('Mean Brightness Exposure', '${q.brightnessMean.toStringAsFixed(1)} (range 15-245)'),
          if (q.contrast != null)
            _detailRow('RMS Contrast Metric', q.contrast!.toStringAsFixed(1)),
          if (q.sharpnessStatus != null)
            _detailRow('Sharpness Classification', q.sharpnessStatus!),
          if (q.exposureStatus != null)
            _detailRow('Exposure Status', q.exposureStatus!),
          if (q.reason != null && q.reason!.isNotEmpty)
            _detailRow('Quality Flag Reason', q.reason!, valueColor: AppTheme.counterfeitRed),
        ],
      ),
    );
  }

  // ── Action Buttons ──────────────────────────────────────────────────────────

  Widget _buildReportActionButtons(BuildContext context, String effectiveSampleId) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: () => _exportReport(context, effectiveSampleId),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text(
              'SHARE / EXPORT INSPECTION REPORT',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'START NEW INSPECTION',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6),
            ),
          ),
        ),
      ],
    );
  }

  // ── Report Exporter ─────────────────────────────────────────────────────────

  void _exportReport(BuildContext context, String effectiveSampleId) {
    final report = ReportService.generateTextReport(
      result: result,
      sampleId: effectiveSampleId,
      medicineName: medicineName,
      notes: notes,
      fileName: imageFile?.path.split(Platform.pathSeparator).last,
      timestamp: DateTime.now(),
    );

    ReportService.showReportDialog(
      context: context,
      reportText: report,
      sampleId: effectiveSampleId,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _qualityBadge(bool valid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: valid ? AppTheme.authenticBg : AppTheme.counterfeitBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: valid
              ? AppTheme.authenticGreen.withValues(alpha: 0.4)
              : AppTheme.counterfeitRed.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        valid ? 'VALID' : 'FLAGGED',
        style: TextStyle(
          color: valid ? AppTheme.authenticGreen : AppTheme.counterfeitRed,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? AppTheme.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
