import 'package:pharma_assist/models/scan_history_item.dart';

/// Produces an RFC 4180 compatible metadata export. Images and local paths are
/// deliberately excluded from the export for privacy.
class HistoryCsvExporter {
  static const headers = <String>[
    'ID',
    'Sample_ID',
    'Medicine_Name',
    'Verdict',
    'Prediction',
    'Confidence_Pct',
    'Primary_Model',
    'Human_Review_Required',
    'Timestamp',
    'Notes',
    'AI_Review_Status',
    'AI_Assessment',
    'AI_Confidence',
    'AI_Model',
    'AI_Recommendation',
    'AI_Findings',
    'AI_Review_Message',
  ];

  static String encode(Iterable<ScanHistoryItem> records) {
    final rows = <List<Object?>>[headers];
    for (final item in records) {
      final response = item.fullResponse;
      final qwen = response?.qwen;
      final reviewStatus = response == null
          ? 'DETAILS NOT SAVED'
          : !response.secondaryExecuted
          ? 'NOT RUN'
          : qwen?.available == true
          ? 'COMPLETED'
          : 'UNAVAILABLE';
      final confidence = item.confidence <= 1
          ? item.confidence * 100
          : item.confidence;
      final aiConfidence = qwen?.confidenceDisplay;
      rows.add([
        item.id,
        item.sampleId,
        item.medicineName,
        item.finalResult,
        item.prediction,
        confidence.toStringAsFixed(1),
        item.primaryModel,
        item.needsHumanVerification,
        item.timestamp.toIso8601String(),
        item.notes,
        reviewStatus,
        qwen?.assessment,
        aiConfidence == 'N/A' ? null : aiConfidence,
        qwen?.modelName,
        qwen?.recommendation,
        qwen?.reasoning.join('; '),
        response == null
            ? null
            : (!response.secondaryExecuted
                ? response.secondaryReason
                : qwen?.error ?? qwen?.warning),
      ]);
    }
    return '${rows.map((row) => row.map(_escape).join(',')).join('\r\n')}\r\n';
  }

  static String _escape(Object? value) {
    final text = value?.toString() ?? '';
    if (!text.contains(',') &&
        !text.contains('"') &&
        !text.contains('\r') &&
        !text.contains('\n')) {
      return text;
    }
    return '"${text.replaceAll('"', '""')}"';
  }
}
