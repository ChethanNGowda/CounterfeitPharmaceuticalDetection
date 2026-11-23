import 'dart:convert';
import 'dart:typed_data';

import 'package:pharma_assist/models/prediction_response.dart';
import 'package:pharma_assist/models/medicine_profile.dart';
import 'package:pharma_assist/models/scan_history_item.dart';

/// Dependency-free, paginated PDF generator for saved PharmaAssist reports.
class SimplePdfReportGenerator {
  static Uint8List generateReportPdf(ScanHistoryItem item) {
    final lines = <String>[
      'PHARMAASSIST - FIELD SCREENING REPORT',
      'Preliminary image-based screening | Not a laboratory verification',
      '',
      'SCREENING RECORD',
      'Report ID: ${item.id}',
      'Sample ID: ${item.sampleId}',
      'Medicine: ${item.medicineName ?? "Not specified"}',
      'Photo file: ${item.fileName ?? "Not recorded"}',
      'Date and time: ${item.timestamp.toIso8601String()}',
      'Primary model: ${item.primaryModel}',
      'Outcome: ${item.finalResult}',
      'Model prediction: ${item.prediction}',
      'Model-reported score: ${(item.confidence * 100).toStringAsFixed(1)}% (not a calibrated probability)',
      'Manual review: ${item.needsHumanVerification ? "Recommended" : "Not flagged by screening"}',
      'Operating mode: ${item.operatingMode}',
      'Sync state: ${item.syncStatus}',
      '',
      ..._qualityLines(item.fullResponse?.quality),
      ..._visualLines(item.fullResponse?.visualAnalysis),
      ..._aiLines(item.fullResponse),
      'USER NOTES',
      item.notes?.trim().isNotEmpty == true
          ? item.notes!.trim()
          : 'No notes recorded.',
      '',
      'LIMITATIONS AND SAFETY',
      'This is a preliminary visual screening result and may be uncertain or wrong.',
      'It cannot prove authenticity or determine ingredients, composition, dosage, or safety.',
      'Visual observations and any optional AI review describe visible image features only.',
      'A barcode, model score, or heatmap is not proof of product authenticity.',
      'For concerns, do not rely on this report alone; contact a licensed pharmacist or relevant authority.',
    ];

    return _generatePdfLines(lines);
  }

  static Uint8List generateMedicineProfilePdf(MedicineProfile profile) {
    final lines = <String>[
      'PHARMAASSIST - MEDICINE RECORD',
      'Local user-reviewed package information; not product authentication',
      '',
      'MEDICINE DETAILS',
      'Record ID: ${profile.id}',
      'Medicine / brand name: ${_value(profile.medicineName)}',
      'Generic name: ${_value(profile.genericName)}',
      'Strength: ${_value(profile.strength)}',
      'Dosage form: ${_value(profile.dosageForm)}',
      'Composition as printed: ${_value(profile.composition)}',
      'Manufacturer: ${_value(profile.manufacturer)}',
      'Marketed by: ${_value(profile.marketer)}',
      'Manufacturing licence: ${_value(profile.manufacturingLicenceNumber)}',
      'Pack size: ${_value(profile.packSize)}',
      '',
      'BATCH RECORDS',
      if (profile.allBatches.isEmpty) 'No batch details recorded.',
      for (final batch in profile.allBatches) ...[
        'Batch: ${_value(batch.batchNumber)}',
        'Manufacturing date: ${_value(batch.manufacturingDate)}',
        'Expiry date: ${_value(batch.expiryDate)}',
        'MRP: ${_value(batch.mrp)}',
        'Source: ${batch.sourceType}; recorded ${batch.recordedAt.toIso8601String()}',
        '',
      ],
      'PRODUCT CODES',
      if (profile.allProductIdentifiers.isEmpty)
        'No QR/barcode values recorded.',
      for (final code in profile.allProductIdentifiers) ...[
        'Format: ${code.format}',
        'Raw decoded value: ${code.value}',
        for (final entry in code.parsedFields.entries)
          if (!entry.key.endsWith('_check_digit_valid'))
            '${entry.key.replaceAll('_', ' ')}: ${entry.value}',
        if (code.unparsedData.isNotEmpty)
          'Unparsed data retained: ${code.unparsedData}',
        'Captured: ${code.capturedAt.toIso8601String()}',
        'Decoded values are not verified product information.',
        '',
      ],
      'PACKAGE PHOTOGRAPHS',
      if (profile.packageImageRecords.isEmpty) 'No package photos recorded.',
      if (profile.packageImageRecords.isNotEmpty)
        '${profile.packageImageRecords.length} package photo(s) stored locally; image files are not embedded in this report.',
      for (final image in profile.packageImageRecords) ...[
        '${image.label} · ${image.capturedAt.toIso8601String()}',
        if (image.rawOcrText.isNotEmpty)
          'Original OCR text (${image.label}): ${image.rawOcrText}',
        for (final field in image.extractedFields.entries)
          'OCR suggestion ${field.key.replaceAll('_', ' ')}: ${field.value}',
      ],
      '',
      'FIELD REVIEW HISTORY',
      if (profile.auditHistory.isEmpty) 'No field correction history recorded.',
      for (final entry in profile.auditHistory) ...[
        '${entry.fieldKey}: ${entry.originalValue} -> ${entry.savedValue}',
        'Source: ${entry.sourceType}${entry.sourceId == null ? '' : ' (${entry.sourceId})'}; reviewed: ${entry.userReviewed}; changed: ${entry.changedAt.toIso8601String()}',
        if (entry.confidence != null)
          'Source-provided confidence: ${entry.confidence}',
        if (entry.correctionReason?.isNotEmpty == true)
          'Correction reason: ${entry.correctionReason}',
      ],
      '',
      'PUBLIC ALERT LOOKUP HISTORY',
      if (profile.verificationHistory.isEmpty)
        'No public-source alert lookups recorded.',
      for (final report in profile.verificationHistory) ...[
        '${report.statusLabel} · ${report.checkedAt.toIso8601String()}',
        if (report.explanation?.isNotEmpty == true)
          'Evidence explanation: ${report.explanation}',
        'Outcome note: ${report.warning}',
        for (final source in report.sources) ...[
          'Source organisation/document: ${source.title}',
          'Source URL: ${source.url}',
          'Retrieved: ${source.retrievedAt?.toIso8601String() ?? "Unknown"}',
          if (source.publishedAt?.isNotEmpty == true)
            'Published: ${source.publishedAt}',
          if (source.excerpt.isNotEmpty) 'Relevant excerpt: ${source.excerpt}',
        ],
      ],
      '',
      'LIMITATIONS',
      'OCR and code decoding preserve observations from package images and payloads; they do not confirm identity or authenticity.',
      'No missing fields have been inferred. Review the physical packaging and consult an appropriate professional when needed.',
      'An absent public alert match is not proof that a medicine is genuine.',
    ];
    return _generatePdfLines(lines);
  }

  static String _value(String value) =>
      value.trim().isEmpty ? 'Not recorded' : value;

  static Uint8List _generatePdfLines(List<String> lines) {
    // Courier is a built-in PDF font. Wrap long and non-ASCII input so text
    // remains readable and within page bounds on all Android PDF viewers.
    final wrapped = <String>[];
    for (final line in lines) {
      wrapped.addAll(_wrap(_ascii(line), 84));
    }
    const linesPerPage = 47;
    final pageLines = <List<String>>[];
    for (var i = 0; i < wrapped.length; i += linesPerPage) {
      pageLines.add(
        wrapped.sublist(
          i,
          i + linesPerPage > wrapped.length ? wrapped.length : i + linesPerPage,
        ),
      );
    }
    if (pageLines.isEmpty) pageLines.add(const []);

    String escape(String value) => value
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');

    final contentStreams = <String>[];
    for (var pageIndex = 0; pageIndex < pageLines.length; pageIndex++) {
      final stream = StringBuffer()
        ..writeln('BT')
        ..writeln('/F1 10 Tf')
        ..writeln('48 790 Td')
        ..writeln('15 TL');
      for (var i = 0; i < pageLines[pageIndex].length; i++) {
        final line = pageLines[pageIndex][i];
        if (pageIndex == 0 && i == 0) {
          stream
            ..writeln('/F2 15 Tf')
            ..writeln('(${escape(line)}) Tj')
            ..writeln('/F1 10 Tf');
        } else {
          stream.writeln('T* (${escape(line)}) Tj');
        }
      }
      stream.writeln('ET');
      contentStreams.add(stream.toString());
    }

    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '', // Pages tree filled after page/content object numbers are known.
    ];
    final firstPageObject = 3;
    final firstContentObject = firstPageObject + pageLines.length;
    final regularFontObject = firstContentObject + pageLines.length;
    final boldFontObject = regularFontObject + 1;
    objects[1] =
        '<< /Type /Pages /Kids [${List.generate(pageLines.length, (i) => '${firstPageObject + i} 0 R').join(' ')}] /Count ${pageLines.length} >>';

    for (var i = 0; i < pageLines.length; i++) {
      final contentRef = firstContentObject + i;
      objects.add(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Contents $contentRef 0 R /Resources << /Font << '
        '/F1 $regularFontObject 0 R /F2 $boldFontObject 0 R >> >> >>',
      );
    }
    for (final content in contentStreams) {
      final length = utf8.encode(content).length;
      objects.add('<< /Length $length >>\nstream\n${content}endstream');
    }
    objects
      ..add('<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>')
      ..add('<< /Type /Font /Subtype /Type1 /BaseFont /Courier-Bold >>');

    final pdf = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(utf8.encode(pdf.toString()).length);
      pdf.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }
    final xrefOffset = utf8.encode(pdf.toString()).length;
    pdf
      ..write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n')
      ..writeAll(
        offsets.map(
          (offset) => '${offset.toString().padLeft(10, '0')} 00000 n \n',
        ),
      )
      ..write(
        'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n',
      );
    return Uint8List.fromList(utf8.encode(pdf.toString()));
  }

  static List<String> _qualityLines(QualityMetrics? quality) {
    if (quality == null) {
      return [
        'PHOTO QUALITY',
        'Photo-quality analysis was not saved with this record.',
        '',
      ];
    }
    final dimensions = quality.dimensions.length >= 2
        ? '${quality.dimensions[0]} x ${quality.dimensions[1]} px'
        : 'Not available';
    final lines = <String>[
      'PHOTO QUALITY',
      'Assessment: ${quality.isValid ? "Accepted for screening" : "Quality concern recorded"}',
      'Image dimensions: $dimensions',
      'Sharpness score: ${quality.blurScore.toStringAsFixed(2)}${quality.sharpnessStatus == null ? "" : " (${quality.sharpnessStatus})"}',
      'Brightness mean: ${quality.brightnessMean.toStringAsFixed(1)}${quality.exposureStatus == null ? "" : " (${quality.exposureStatus})"}',
      'Color mode: ${quality.colorMode}',
      'Quality checks describe the submitted image, not the medicine contents.',
      '',
    ];
    if (quality.contrast != null) {
      lines.insert(6, 'Contrast: ${quality.contrast!.toStringAsFixed(2)}');
    }
    if (quality.suitability?.trim().isNotEmpty == true) {
      lines.insert(lines.length - 2, 'Suitability: ${quality.suitability}');
    }
    if (quality.reason?.trim().isNotEmpty == true) {
      lines.insert(lines.length - 2, 'Quality note: ${quality.reason}');
    }
    return lines;
  }

  static List<String> _visualLines(VisualAnalysisReport? visual) {
    if (visual == null) {
      return [
        'VISIBLE PHOTO OBSERVATIONS',
        'No visual-analysis details were saved.',
        '',
      ];
    }
    final lines = <String>['VISIBLE PHOTO OBSERVATIONS'];
    void add(String label, String? value) {
      if (value?.trim().isNotEmpty == true) {
        lines.add('$label: ${value!.trim()}');
      }
    }

    add('Visible color', visual.color?.dominantColor);
    add('Color consistency', visual.color?.consistency);
    add('Visible variation', visual.color?.visibleVariation);
    add('Detected shape', visual.shape?.shapeType);
    add('Shape symmetry', visual.shape?.symmetry);
    add('Surface texture', visual.surface?.textureVariation);
    add('Surface uniformity', visual.surface?.surfaceUniformity);
    add('Visible spots', visual.surface?.visibleSpots);
    add('Surface irregularities', visual.surface?.surfaceIrregularities);
    add('Markings visible', visual.markings?.markingsVisible);
    add('Marking legibility', visual.markings?.legibility);
    add('Edge condition', visual.edges?.edgeIntegrity);
    add('Cracks', visual.edges?.cracks);
    add('Chipping', visual.edges?.chipping);
    add('Packaging condition', visual.packaging?.condition);
    if (lines.length == 1) {
      lines.add('No detailed observations were returned.');
    }
    lines
      ..add(
        'These are image-based observations only and are not ingredient or authenticity verification.',
      )
      ..add('');
    return lines;
  }

  static List<String> _aiLines(PredictionResponse? response) {
    final lines = <String>['OPTIONAL AI VISUAL REVIEW'];
    if (response == null || !response.secondaryExecuted) {
      lines.add('Not run or not included in the saved screening record.');
      lines.add('');
      return lines;
    }
    final review = response.qwen;
    if (!review.available) {
      lines.add('Attempted but unavailable for this screening.');
      if (response.secondaryReason?.trim().isNotEmpty == true) {
        lines.add('Availability note: ${response.secondaryReason}');
      }
      lines.add('');
      return lines;
    }
    lines
      ..add('Assessment: ${review.assessment}')
      ..add(
        'Model-reported score: ${review.confidenceDisplay} (not a calibrated probability)',
      );
    if (review.recommendation?.trim().isNotEmpty == true) {
      lines.add('Recommendation: ${review.recommendation}');
    }
    if (review.finalExplanation?.trim().isNotEmpty == true) {
      lines.add('Explanation: ${review.finalExplanation}');
    }
    final observations = [...review.observationsList, ...review.reasoning];
    for (final observation in observations.toSet()) {
      if (observation.trim().isNotEmpty) {
        lines.add('Noticed: ${observation.trim()}');
      }
    }
    for (final concern in review.concernsList) {
      if (concern.trim().isNotEmpty) {
        lines.add('Concern noted: ${concern.trim()}');
      }
    }
    if (observations.isEmpty &&
        review.finalExplanation?.trim().isNotEmpty != true) {
      lines.add('No detailed observations were returned.');
    }
    lines
      ..add(
        'Optional AI review is advisory and does not override the primary model result.',
      )
      ..add('');
    return lines;
  }

  static List<String> _wrap(String value, int width) {
    if (value.isEmpty) return [''];
    final words = value.split(RegExp(r'\s+'));
    final result = <String>[];
    var current = '';
    for (final word in words) {
      if (word.length > width) {
        if (current.isNotEmpty) result.add(current);
        current = '';
        for (var i = 0; i < word.length; i += width) {
          final part = word.substring(
            i,
            i + width > word.length ? word.length : i + width,
          );
          if (part.length == width) {
            result.add(part);
          } else {
            current = part;
          }
        }
      } else if (current.isEmpty) {
        current = word;
      } else if (current.length + word.length + 1 <= width) {
        current = '$current $word';
      } else {
        result.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) result.add(current);
    return result;
  }

  static String _ascii(String value) => value
      .replaceAll('\u00d7', 'x')
      .replaceAll('\u2013', '-')
      .replaceAll('\u2014', '-')
      .replaceAll('\u2019', "'")
      .replaceAll('\u201c', '"')
      .replaceAll('\u201d', '"')
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
}
