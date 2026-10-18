import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/models/prediction_response.dart';
import 'package:pharma_assist/models/scan_history_item.dart';

class ReportService {
  /// Generate a clean, structured field inspection text report
  static String generateTextReport({
    required PredictionResponse result,
    required String sampleId,
    String? medicineName,
    String? notes,
    String? fileName,
    DateTime? timestamp,
  }) {
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String timeStr = formatter.format(timestamp ?? DateTime.now());
    final String genTime = formatter.format(DateTime.now());

    final double normConf = result.confidence <= 1.0
        ? result.confidence * 100
        : result.confidence;
    final double authProb = result.authenticProbability <= 1.0
        ? result.authenticProbability * 100
        : result.authenticProbability;
    final double countProb = result.counterfeitProbability <= 1.0
        ? result.counterfeitProbability * 100
        : result.counterfeitProbability;
    // A failed quality gate can still carry a provisional classifier suggestion
    // for moderate blur. Only UNKNOWN means that inference did not run.
    final bool qualityRejected =
        result.quality != null && !result.quality!.isValid;
    final bool inferenceRan = result.prediction.toUpperCase() != 'UNKNOWN';

    final buffer = StringBuffer();
    buffer.writeln(
      '================================================================',
    );
    buffer.writeln(
      '${AppConstants.appName.toUpperCase()} - FIELD SCREENING REPORT',
    );
    buffer.writeln(AppConstants.appSubtitle);
    buffer.writeln(
      '================================================================',
    );
    buffer.writeln('Report Generated : $genTime');
    buffer.writeln('Inspection ID    : $sampleId');
    if (medicineName != null && medicineName.isNotEmpty) {
      buffer.writeln('Product/Medicine : $medicineName');
    }
    buffer.writeln('Scan Timestamp   : $timeStr');
    if (fileName != null && fileName.isNotEmpty) {
      buffer.writeln('Source Image     : $fileName');
    }
    buffer.writeln('Primary Model    : ${result.primaryModel}');
    buffer.writeln(
      'Threshold Used   : ${(result.threshold * 100).toStringAsFixed(0)}%',
    );
    buffer.writeln(
      '----------------------------------------------------------------',
    );
    buffer.writeln('SCREENING OUTCOME:');
    if (qualityRejected && !inferenceRan) {
      buffer.writeln(
        '  Result            : INCONCLUSIVE - MANUAL REVIEW REQUIRED',
      );
      buffer.writeln('  Screening status  : NOT COMPLETED');
      buffer.writeln(
        '  Classifier output : Not generated; image-quality gate stopped screening',
      );
      buffer.writeln('  Model confidence  : Not available');
      buffer.writeln('  Probability dist. : Not generated');
    } else {
      buffer.writeln(
        '  Result            : ${result.finalResult.toUpperCase()}',
      );
      buffer.writeln(
        '  Classifier output : ${qualityRejected ? "PRELIMINARY ONLY - ${result.prediction}" : result.prediction}',
      );
      buffer.writeln('  Model confidence  : ${normConf.toStringAsFixed(1)}%');
      buffer.writeln(
        '  Probability dist. : Authentic ${authProb.toStringAsFixed(1)}% | Counterfeit ${countProb.toStringAsFixed(1)}%',
      );
    }
    buffer.writeln(
      'Manual Review Req  : ${result.needsHumanVerification ? "YES (Mandatory Physical Inspection)" : "NO (Standard Result)"}',
    );
    buffer.writeln(
      '----------------------------------------------------------------',
    );

    // Decision Rationale
    if (result.reasons.isNotEmpty) {
      buffer.writeln('DECISION RATIONALE:');
      for (final r in result.reasons) {
        buffer.writeln('  - $r');
      }
      buffer.writeln(
        '----------------------------------------------------------------',
      );
    }

    // Secondary AI Vision
    final qwen = result.qwen;
    buffer.writeln('SECONDARY AI INSPECTION (Qwen Vision):');
    buffer.writeln(
      '  Execution Status : ${result.secondaryExecuted ? "Executed" : "Not run"}',
    );
    if (result.secondaryReason != null) {
      buffer.writeln('  Gating Reason    : ${result.secondaryReason}');
    }
    buffer.writeln(
      '  AI Availability  : ${!result.secondaryExecuted
          ? "Not assessed for this scan"
          : qwen.available
          ? "Available"
          : "Unavailable"}',
    );
    if (result.secondaryExecuted && qwen.available) {
      buffer.writeln('  Visual Assessment: ${qwen.assessment}');
      buffer.writeln('  AI Confidence    : ${qwen.confidenceDisplay}');
      if (qwen.recommendation != null) {
        buffer.writeln('  Recommendation   : ${qwen.recommendation}');
      }
      if (qwen.tabletShape != null) {
        buffer.writeln('  Detected Shape   : ${qwen.tabletShape}');
      }
      if (qwen.tabletColor != null) {
        buffer.writeln('  Detected Color   : ${qwen.tabletColor}');
      }
      if (qwen.tabletSurface != null) {
        buffer.writeln('  Surface Integrity: ${qwen.tabletSurface}');
      }
      if (qwen.tabletMarkings != null) {
        buffer.writeln('  Imprint/Markings : ${qwen.tabletMarkings}');
      }
      if (qwen.tabletEdges != null) {
        buffer.writeln('  Edge Integrity   : ${qwen.tabletEdges}');
      }
    }
    buffer.writeln(
      '----------------------------------------------------------------',
    );

    // Quality gate metrics
    if (result.quality != null) {
      final q = result.quality!;
      buffer.writeln('OPENCV IMAGE QUALITY METRICS:');
      buffer.writeln(
        '  Gate Status      : ${q.isValid
            ? "PASSED"
            : inferenceRan
            ? "FAILED - MODEL OUTPUT PROVISIONAL"
            : "FAILED - INFERENCE NOT RUN"}',
      );
      buffer.writeln('  Dimensions       : ${q.dimensions.join("x")} px');
      buffer.writeln(
        '  Laplacian sharpness score: ${q.blurScore.toStringAsFixed(1)} (minimum: 50.0)',
      );
      buffer.writeln(
        '  Mean brightness  : ${q.brightnessMean.toStringAsFixed(1)} (acceptable: 15-245)',
      );
      if (q.contrast != null) {
        buffer.writeln(
          '  RMS Contrast     : ${q.contrast!.toStringAsFixed(1)}',
        );
      }
      if (q.reason != null && q.reason!.isNotEmpty) {
        buffer.writeln('  Quality Warning  : ${q.reason}');
      }
      if (!q.isValid) {
        buffer.writeln(
          '  Retake guidance  : Hold the phone steady, clean the lens, focus on the medicine, and use bright, even light.',
        );
      }
      buffer.writeln(
        '----------------------------------------------------------------',
      );
    }

    if (qualityRejected) {
      buffer.writeln('RECOMMENDED NEXT STEPS:');
      buffer.writeln(
        '  - Retake a clear, in-focus image; do not rely on any provisional model suggestion.',
      );
      buffer.writeln(
        '  - Do not consume or discard medicine based only on this result.',
      );
      buffer.writeln(
        '  - Ask a pharmacist or appropriate health authority to inspect a suspicious product.',
      );
      buffer.writeln(
        '----------------------------------------------------------------',
      );
    }

    // Notes
    if (notes != null && notes.isNotEmpty) {
      buffer.writeln('FIELD INSPECTION NOTES:');
      buffer.writeln('  $notes');
      buffer.writeln(
        '----------------------------------------------------------------',
      );
    }

    // Regulatory disclaimer
    buffer.writeln('REGULATORY & MEDICAL DISCLAIMER:');
    buffer.writeln(
      result.disclaimer.isNotEmpty
          ? result.disclaimer
          : AppConstants.persistentDisclaimer,
    );
    buffer.writeln();
    buffer.writeln(AppConstants.legalNotice);
    buffer.writeln(
      '================================================================',
    );

    return buffer.toString();
  }

  /// Generate report directly from a ScanHistoryItem
  static String generateReportFromHistory(ScanHistoryItem item) {
    if (item.fullResponse != null) {
      return generateTextReport(
        result: item.fullResponse!,
        sampleId: item.sampleId,
        medicineName: item.medicineName,
        notes: item.notes,
        fileName: item.fileName,
        timestamp: item.timestamp,
      );
    }

    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String timeStr = formatter.format(item.timestamp);
    final double normConf = item.confidence <= 1.0
        ? item.confidence * 100
        : item.confidence;

    final buffer = StringBuffer();
    buffer.writeln(
      '================================================================',
    );
    buffer.writeln(
      '${AppConstants.appName.toUpperCase()} - FIELD SCREENING RECORD',
    );
    buffer.writeln(
      '================================================================',
    );
    buffer.writeln('Inspection ID    : ${item.sampleId}');
    if (item.medicineName != null) {
      buffer.writeln('Medicine Name    : ${item.medicineName}');
    }
    buffer.writeln('Timestamp        : $timeStr');
    buffer.writeln('Primary Model    : ${item.primaryModel}');
    buffer.writeln('Screening Result : ${item.finalResult}');
    buffer.writeln('Prediction       : ${item.prediction}');
    buffer.writeln('Confidence       : ${normConf.toStringAsFixed(1)}%');
    buffer.writeln(
      'Manual Review    : ${item.needsHumanVerification ? "REQUIRED" : "STANDARD"}',
    );
    if (item.notes != null) {
      buffer.writeln('Notes            : ${item.notes}');
    }
    buffer.writeln(
      '----------------------------------------------------------------',
    );
    buffer.writeln(AppConstants.persistentDisclaimer);
    buffer.writeln(
      '================================================================',
    );

    return buffer.toString();
  }

  /// Shows an interactive inspection report dialog with copy action
  static Future<void> showReportDialog({
    required BuildContext context,
    required String reportText,
    required String sampleId,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: AppTheme.border),
          ),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: AppTheme.primaryTeal,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Field Inspection Report',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                onPressed: () => Navigator.of(ctx).pop(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  reportText,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: reportText));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Inspection report copied to clipboard'),
                      backgroundColor: AppTheme.authenticGreen,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 14),
              label: const Text(
                'Copy to Clipboard',
                style: TextStyle(fontSize: 12),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );
  }
}
