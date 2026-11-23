import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/models/prediction_response.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/models/medicine_profile.dart';
import 'package:pharma_assist/models/medicine_package_image.dart';
import 'package:pharma_assist/models/medicine_record_metadata.dart';
import 'package:pharma_assist/models/product_identifier.dart';
import 'package:pharma_assist/services/simple_pdf_report_generator.dart';

void main() {
  test('PDF includes saved photo quality and optional visual review', () {
    final item = _item();
    final pdf = _pdfText(item);

    expect(pdf, contains('PHOTO QUALITY'));
    expect(pdf, contains('1280 x 960 px'));
    expect(pdf, contains('Sharpness score: 82.50 (CLEAR)'));
    expect(pdf, contains('VISIBLE PHOTO OBSERVATIONS'));
    expect(pdf, contains('Visible color: white'));
    expect(pdf, contains('Markings visible: readable imprint'));
    expect(pdf, contains('OPTIONAL AI VISUAL REVIEW'));
    expect(pdf, contains('Noticed: tablet edges visible'));
    expect(pdf, contains('advisory'));
  });

  test('PDF paginates and wraps long report content', () {
    final item = _item(
      reasoning: List<String>.filled(
        70,
        'A detailed observation with a long value that should wrap to another line and remain readable in the generated PDF report.',
      ),
    );
    final pdf = _pdfText(item);

    final pageCount = int.parse(
      RegExp(r'/Count (\d+)').firstMatch(pdf)!.group(1)!,
    );
    expect(pageCount, greaterThan(1));
    expect(RegExp(r'/Type /Page /Parent').allMatches(pdf).length, pageCount);
    expect(pdf, contains('startxref'));
    expect(pdf, contains('%%EOF'));
  });

  test('PDF clearly reports when optional data was not saved', () {
    final item = _item(includeResponse: false);
    final pdf = _pdfText(item);

    expect(pdf, contains('Photo-quality analysis was not saved'));
    expect(pdf, contains('No visual-analysis details were saved'));
    expect(pdf, contains('Not run or not included'));
  });

  test('medicine PDF includes saved batches, code, OCR and audit details', () {
    final at = DateTime.utc(2026, 11, 23);
    final profile = MedicineProfile(
      id: 'medicine-pdf-1',
      medicineName: 'Example brand',
      genericName: 'Example generic',
      composition: 'As printed on package',
      manufacturer: 'Example maker',
      marketer: 'Example marketer',
      manufacturingLicenceNumber: 'LIC-42',
      packSize: '10 tablets',
      batchNumber: 'LOT-1',
      expiryDate: '11/2027',
      createdAt: at,
      packagingImages: [
        MedicinePackageImage(
          id: 'image-back',
          path: '/private/back.jpg',
          label: 'Back of package',
          capturedAt: at,
          rawOcrText: 'Batch: LOT-1',
          extractedFields: const {'batch_number': 'LOT-1'},
        ),
      ],
      productIdentifiers: [
        ProductIdentifier.tryCreate(
          '(01)09506000134352(10)LOT-1',
          format: 'dataMatrix',
          capturedAt: at,
        )!,
      ],
      batches: [
        MedicineBatchRecord(
          id: 'batch-1',
          batchNumber: 'LOT-1',
          expiryDate: '11/2027',
          recordedAt: at,
          sourceType: 'qr_barcode',
        ),
      ],
      auditHistory: [
        MedicineFieldAuditEntry(
          id: 'audit-1',
          fieldKey: 'batch_number',
          originalValue: 'LOT-I',
          savedValue: 'LOT-1',
          sourceType: 'ocr',
          sourceId: 'image-back',
          userCorrected: true,
          userReviewed: true,
          changedAt: at,
        ),
      ],
    );
    final pdf = String.fromCharCodes(
      SimplePdfReportGenerator.generateMedicineProfilePdf(profile),
    ).replaceAll(r'\(', '(').replaceAll(r'\)', ')');

    expect(pdf, contains('MEDICINE DETAILS'));
    expect(pdf, contains('Example generic'));
    expect(pdf, contains('BATCH RECORDS'));
    expect(pdf, contains('LOT-1'));
    expect(pdf, contains('PRODUCT CODES'));
    expect(pdf, contains('dataMatrix'));
    expect(pdf, contains('PACKAGE PHOTOGRAPHS'));
    expect(pdf, contains('Original OCR text'));
    expect(pdf, contains('FIELD REVIEW HISTORY'));
    expect(pdf, contains('image-back'));
    expect(pdf, contains('image files are not embedded'));
    expect(pdf, contains('%%EOF'));
  });
}

ScanHistoryItem _item({
  PredictionResponse? fullResponse,
  bool includeResponse = true,
  List<String> reasoning = const ['tablet edges visible'],
}) {
  return ScanHistoryItem(
    id: 'record-123',
    sampleId: 'sample-456',
    medicineName: 'Example medicine',
    fileName: 'package-photo.jpg',
    timestamp: DateTime.utc(2026, 6, 1, 12),
    finalResult: 'INCONCLUSIVE - MANUAL REVIEW REQUIRED',
    prediction: 'UNKNOWN',
    confidence: 0.61,
    primaryModel: 'efficientnet_b0',
    needsHumanVerification: true,
    fullResponse: includeResponse
        ? (fullResponse ?? _response(reasoning))
        : null,
  );
}

String _pdfText(ScanHistoryItem item) =>
    String.fromCharCodes(SimplePdfReportGenerator.generateReportPdf(item))
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\');

PredictionResponse _response(List<String> reasoning) => PredictionResponse(
  primaryModel: 'efficientnet_b0',
  modelName: 'efficientnet_b0',
  prediction: 'UNKNOWN',
  confidence: 0.61,
  authenticProbability: 0.40,
  counterfeitProbability: 0.39,
  finalResult: 'INCONCLUSIVE - MANUAL REVIEW REQUIRED',
  threshold: 0.70,
  needsHumanVerification: true,
  qwen: QwenReviewDetails(
    available: true,
    status: 'COMPLETED',
    assessment: 'UNCERTAIN',
    rawConfidence: 0.55,
    reasoning: reasoning,
  ),
  secondaryExecuted: true,
  disagreement: false,
  disclaimer: 'Preliminary screening only.',
  status: 'SUCCESS',
  quality: QualityMetrics(
    isValid: true,
    blurScore: 82.5,
    brightnessMean: 119,
    dimensions: const [1280, 960],
    contrast: 38,
    colorMode: 'RGB',
    exposureStatus: 'BALANCED',
    sharpnessStatus: 'CLEAR',
    suitability: 'SUITABLE',
  ),
  visualAnalysis: VisualAnalysisReport(
    color: VisualColorAnalysis(dominantColor: 'white'),
    markings: VisualMarkingsAnalysis(markingsVisible: 'readable imprint'),
  ),
);
