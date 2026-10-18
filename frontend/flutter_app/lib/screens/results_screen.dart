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
    final effectiveSampleId =
        sampleId ??
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
            if (result.warning != null &&
                result.warning!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildWarningBox(result.warning!),
            ],

            // 5. Primary Confidence Gauge
            const SizedBox(height: 16),
            if (result.prediction == 'UNKNOWN')
              _buildInferenceNotRunCard()
            else ...[
              ConfidenceGauge(
                confidence: result.confidence,
                authenticProb: result.authenticProbability,
                counterfeitProb: result.counterfeitProbability,
                provisional: result.quality != null && !result.quality!.isValid,
              ),
              if (result.quality != null && !result.quality!.isValid) ...[
                const SizedBox(height: 8),
                _buildProvisionalPredictionNotice(),
              ],
            ],

            // 6. Pipeline Summary Card
            const SizedBox(height: 12),
            _buildPipelineSummary(),

            // 7. Secondary AI Review (Qwen Vision)
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
    final bool isAuthentic =
        verdict.contains('AUTHENTIC') &&
        !verdict.contains('SUSPICIOUS') &&
        !verdict.contains('VERIFICATION');
    final bool isCounterfeit =
        verdict.contains('COUNTERFEIT') &&
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
      outcomeSubtitle = 'The main model found visual patterns that resemble its reference examples. This is a screening estimate, not proof that the medicine is genuine or safe.';
    } else if (isCounterfeit) {
      outcomeColor = AppTheme.counterfeitRed;
      outcomeBg = AppTheme.counterfeitBg;
      outcomeIcon = Icons.gpp_bad_outlined;
      outcomeHeader = 'SCREENING INDICATES COUNTERFEIT';
      outcomeSubtitle = 'The model found visual patterns that need checking. Do not take or discard the medicine based only on this result. Keep its packaging and ask a pharmacist or health authority to inspect it.';
    } else {
      outcomeColor = AppTheme.suspiciousAmber;
      outcomeBg = AppTheme.suspiciousBg;
      outcomeIcon = Icons.warning_amber_rounded;
      outcomeHeader = 'INCONCLUSIVE · MANUAL REVIEW REQUIRED';
      outcomeSubtitle = 'This screening could not reach a clear result. A pharmacist or appropriate health authority should check the product.';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: outcomeColor.withValues(alpha: 0.6),
          width: 1.2,
        ),
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
                          Text(
                            'OVERALL SCREENING RESULT',
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
                          Text(
                            '${result.quality != null && !result.quality!.isValid ? 'Preliminary model suggestion' : 'Main model prediction'}: ${_plainPrediction(result.prediction)}',
                            style: TextStyle(
                              color: outcomeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  outcomeSubtitle,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                if (result.reasons.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(height: 1, color: AppTheme.border),
                  const SizedBox(height: 10),
                  Text(
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
                              style: TextStyle(
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
              Text(
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
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
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
    final qualityFailed = result.quality != null && !result.quality!.isValid;
    final title = qualityFailed
        ? 'Retake photo before relying on this result'
        : 'Ask a pharmacist to review this result';
    final message = qualityFailed
        ? 'The photo did not pass the sharpness check, so this screening is inconclusive. Retake it in bright, even light with the medicine in focus. Do not take or discard the medicine based only on this app.'
        : 'This is a visual screening estimate, not proof of authenticity or safety. Do not take or discard the medicine based only on this app; ask a pharmacist or health authority to check it.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.suspiciousBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppTheme.suspiciousAmber.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag_outlined, color: AppTheme.suspiciousAmber, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.suspiciousAmber,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  message,
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
        border: Border.all(
          color: AppTheme.suspiciousAmber.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppTheme.suspiciousAmber,
            size: 16,
          ),
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
          Text(
            'HOW THIS SCREENING RAN',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _detailRow('Main model', 'Fine-tuned EfficientNet-B0'),
          _detailRow('Model prediction', _plainPrediction(result.prediction)),
          _detailRow(
            'Review threshold',
            '${(result.threshold * 100).toStringAsFixed(0)}%',
          ),
          _detailRow(
            'Additional AI review',
            result.secondaryExecuted
                ? (result.qwen.available
                      ? 'Completed'
                      : 'Tried, but unavailable')
                : 'Not run',
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

  // ── Qwen Vision Secondary Review ───────────────────────────────────────────────

  Widget _buildQwenCard() {
    final qwen = result.qwen;
    final attempted = result.secondaryExecuted;
    final status = !attempted
        ? 'NOT RUN'
        : qwen.available
        ? qwen.assessment
        : 'UNAVAILABLE';
    final subtitle = !attempted
        ? 'Not run for this image'
        : qwen.available
        ? 'Review completed'
        : 'Review attempted but unavailable';
    final explanation = !attempted
        ? _plainReviewReason(result.secondaryReason)
        : qwen.available
        ? 'This is a supporting visual review. It cannot confirm medicine ingredients or safety.'
        : (qwen.error ??
              qwen.warning ??
              'The review service did not return a result. Check the backend AI service and try again.');

    return ExpandableCard(
      title: 'Optional AI visual review',
      subtitle: subtitle,
      icon: Icons.remove_red_eye_outlined,
      trailingBadge: StatusBadge(statusText: status),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            explanation,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          if (attempted)
            _detailRow(
              'AI service',
              qwen.available ? 'Connected' : 'Not responding',
            ),
          if (attempted && qwen.available) ...[
            _detailRow('AI visual opinion', _plainPrediction(qwen.assessment)),
            _detailRow('AI confidence', qwen.confidenceDisplay),
            if (qwen.recommendation != null)
              _detailRow('Recommendation', qwen.recommendation!),
            if (qwen.tabletShape != null)
              _detailRow('Observed shape', qwen.tabletShape!),
            if (qwen.tabletColor != null)
              _detailRow('Observed color', qwen.tabletColor!),
            if (qwen.tabletSurface != null)
              _detailRow('Surface appearance', qwen.tabletSurface!),
            if (qwen.tabletMarkings != null)
              _detailRow('Visible markings', qwen.tabletMarkings!),
            if (qwen.tabletEdges != null)
              _detailRow('Visible edges', qwen.tabletEdges!),
            if (qwen.reasoning.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'WHAT THE AI NOTICED',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ...qwen.reasoning
                  .take(4)
                  .map(
                    (point) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '- $point',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInferenceNotRunCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.suspiciousBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppTheme.suspiciousAmber.withValues(alpha: .45),
      ),
    ),
    child: Text(
      'The photo did not pass the image-quality check, so the main model did not make a prediction. No confidence score is available. Retake the photo using the guide on the scan screen.',
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        height: 1.45,
      ),
    ),
  );

  Widget _buildProvisionalPredictionNotice() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.suspiciousBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppTheme.suspiciousAmber.withValues(alpha: .45),
      ),
    ),
    child: Text(
      'The model was able to inspect the photo, but it did not pass the sharpness check. Treat this suggestion and score as unreliable; the overall result remains inconclusive. Retake the photo in bright, even light and keep the medicine in focus.',
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        height: 1.45,
      ),
    ),
  );

  String _plainPrediction(String value) {
    switch (value.toUpperCase()) {
      case 'AUTHENTIC':
        return 'likely authentic';
      case 'COUNTERFEIT':
        return 'possible counterfeit';
      case 'UNKNOWN':
        return 'no prediction made';
      default:
        return value.toLowerCase().replaceAll('_', ' ');
    }
  }

  String _plainReviewReason(String? reason) {
    if (reason == null || reason.isEmpty) {
      return 'The review policy did not request an additional AI opinion for this scan.';
    }
    final lower = reason.toLowerCase();
    if (lower.contains('high-confidence')) {
      return 'Not needed: the main model result is above the configured review threshold.';
    }
    if (lower.contains('low primary confidence')) {
      return 'Not run: the main model result already requires a person to check the medicine.';
    }
    if (lower.contains('quality check failed')) {
      return 'Not run because the photo did not pass the image-quality check.';
    }
    if (lower.contains("vision mode 'never'")) {
      return 'Turned off in screening settings.';
    }
    return reason.replaceFirst(RegExp(r'^(Skipped|Executed):\s*'), '');
  }

  // ── OpenCV Visual Analysis ──────────────────────────────────────────────────

  Widget _buildVisualAnalysisCard() {
    final v = result.visualAnalysis!;

    return ExpandableCard(
      title: 'What the photo analysis noticed',
      subtitle: 'Visible appearance only; lighting and camera angle can change what is seen.',
      icon: Icons.pattern_outlined,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (v.color != null) ...[
            _sectionLabel('APPROXIMATE PHOTO COLORS'),
            if (v.color!.dominantColor != null)
              _detailRow('Main visible colors', v.color!.dominantColor!),
            if (v.color!.consistency != null)
              _detailRow(
                'Color appearance',
                v.color!.consistency == 'MULTI-COLORED'
                    ? 'More than one main color'
                    : v.color!.consistency!.toLowerCase(),
              ),
            if (v.color!.visibleVariation != null)
              Text(
                v.color!.visibleVariation!,
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
          ],
          if (v.shape != null) ...[
            const SizedBox(height: 8),
            _sectionLabel('VISIBLE SHAPE'),
            if (v.shape!.shapeType != null)
              _detailRow('Approximate shape', v.shape!.shapeType!),

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
      title: 'Photo quality',
      subtitle: q.isValid
          ? 'Clear enough for this screening check'
          : 'Retake the photo before relying on a screening result',
      icon: Icons.high_quality_outlined,
      trailingBadge: _qualityBadge(q.isValid),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('Image size', '${q.dimensions.join(' x ')} pixels'),
          _detailRow(
            'Photo sharpness',
            '${q.blurScore.toStringAsFixed(1)} (minimum 50; higher is clearer)',
          ),
          _detailRow(
            'Photo lighting',
            '${q.brightnessMean.toStringAsFixed(1)} (acceptable range 15 to 245)',
          ),
          if (q.reason != null && q.reason!.isNotEmpty)
            _detailRow(
              'What needs attention',
              q.reason!,
              valueColor: AppTheme.counterfeitRed,
            ),
          if (!q.isValid)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Retake: hold the phone steady, tap the medicine to focus, clean the lens, and use even light without glare.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Action Buttons ──────────────────────────────────────────────────────────

  Widget _buildReportActionButtons(
    BuildContext context,
    String effectiveSampleId,
  ) {
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
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
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
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
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
        valid ? 'READY' : 'RETAKE',
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
        style: TextStyle(
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
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
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
