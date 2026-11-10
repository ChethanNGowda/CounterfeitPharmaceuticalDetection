import 'dart:convert';
import 'dart:typed_data';

import 'package:pharma_assist/models/scan_history_item.dart';

/// Lightweight pure-Dart PDF (ISO 32000-1) generator for PharmaAssist field reports.
/// Completely dependency-free: no native hooks, C compilers, or native assets needed.
class SimplePdfReportGenerator {
  /// Generate a valid PDF binary representation of an inspection report.
  static Uint8List generateReportPdf(ScanHistoryItem item) {
    final buffer = StringBuffer();
    final objects = <String>[];

    // Build the page text content lines
    final lines = <String>[
      'PHARMAASSIST - FIELD SCREENING REPORT',
      'Preliminary Image-Based Pharmaceutical Screening',
      '--------------------------------------------------------------------------------',
      'Report ID        : ${item.id}',
      'Sample ID        : ${item.sampleId}',
      'Medicine Name    : ${item.medicineName ?? "Not specified"}',
      'Scan Timestamp   : ${item.timestamp.toIso8601String()}',
      'Primary Model    : ${item.primaryModel}',
      'Verdict          : ${item.finalResult}',
      'Prediction Class : ${item.prediction}',
      'Confidence Score : ${(item.confidence * 100).toStringAsFixed(1)}%',
      'Human Review Req : ${item.needsHumanVerification ? "YES - Review Required" : "NO"}',
      'Operating Mode   : ${item.operatingMode}',
      'Cloud Sync State : ${item.syncStatus}',
      '--------------------------------------------------------------------------------',
      'SECONDARY AI VERIFICATION:',
      'AI Status        : ${item.qwenAssessment ?? (item.fullResponse?.qwen.status ?? "NOT RUN")}',
      'AI Assessment    : ${item.qwenAssessment ?? "Not evaluated"}',
      '--------------------------------------------------------------------------------',
      'NOTES & OBSERVATIONS:',
      'Notes            : ${item.notes ?? "None recorded."}',
      '--------------------------------------------------------------------------------',
      'IMPORTANT REGULATORY & SAFETY NOTICE:',
      '1. This screening result is preliminary and based solely on photographic visual features.',
      '2. It does not constitute laboratory chemical assay, dosage, or safety analysis.',
      '3. Visual inspection cannot definitively prove pharmaceutical authenticity.',
      '4. Consult licensed pharmacists and medical laboratory testing for suspicious medicine.',
    ];

    // Escape text for PDF literal string
    String escapePdf(String s) {
      return s
          .replaceAll('\\', '\\\\')
          .replaceAll('(', '\\(')
          .replaceAll(')', '\\)');
    }

    // Stream content
    final streamContent = StringBuffer();
    streamContent.writeln('BT');
    streamContent.writeln('/F1 10 Tf');
    streamContent.writeln('50 780 Td');
    streamContent.writeln('14 TL'); // 14pt line spacing

    for (int i = 0; i < lines.length; i++) {
      if (i == 0) {
        streamContent.writeln('/F2 13 Tf');
        streamContent.writeln('(${escapePdf(lines[i])}) Tj');
        streamContent.writeln('/F1 10 Tf');
      } else {
        streamContent.writeln('T* (${escapePdf(lines[i])}) Tj');
      }
    }
    streamContent.writeln('ET');

    final contentStr = streamContent.toString();
    final contentBytes = utf8.encode(contentStr);

    // PDF Object 1: Catalog
    objects.add('<< /Type /Catalog /Pages 2 0 R >>');

    // PDF Object 2: Pages
    objects.add('<< /Type /Pages /Kids [3 0 R] /Count 1 >>');

    // PDF Object 3: Page
    objects.add(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>',
    );

    // PDF Object 4: Content Stream
    objects.add(
      '<< /Length ${contentBytes.length} >>\nstream\n${contentStr}endstream',
    );

    // PDF Object 5: Standard Font Courier
    objects.add('<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>');

    // PDF Object 6: Standard Font Courier-Bold
    objects.add('<< /Type /Font /Subtype /Type1 /BaseFont /Courier-Bold >>');

    // Assemble PDF
    buffer.write('%PDF-1.4\n');
    final offsets = <int>[];

    for (int i = 0; i < objects.length; i++) {
      offsets.add(utf8.encode(buffer.toString()).length);
      buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }

    final xrefOffset = utf8.encode(buffer.toString()).length;
    buffer.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final offset in offsets) {
      buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }

    buffer.write(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n',
    );

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }
}
