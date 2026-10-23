import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/models/health_response.dart';
import 'package:pharma_assist/models/prediction_response.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/screens/history_screen.dart';
import 'package:pharma_assist/screens/home_screen.dart';
import 'package:pharma_assist/screens/model_lab_screen.dart';
import 'package:pharma_assist/screens/results_screen.dart';
import 'package:pharma_assist/screens/scan_screen.dart';
import 'package:pharma_assist/screens/settings_screen.dart';
import 'package:pharma_assist/services/api_service.dart';
import 'package:pharma_assist/services/report_service.dart';
import 'package:pharma_assist/services/history_csv_exporter.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/widgets/confidence_gauge.dart';
import 'package:pharma_assist/widgets/disclaimer_banner.dart';
import 'package:pharma_assist/widgets/status_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Test Payloads ────────────────────────────────────────────────────────────

Map<String, dynamic> _authenticJson({
  String prediction = 'AUTHENTIC',
  double confidence = 0.985,
  bool qwenAvailable = true,
}) {
  return {
    'primary_model': 'efficientnet_b0',
    'prediction': prediction,
    'confidence': confidence,
    'qwen': {
      'available': qwenAvailable,
      'status': qwenAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
      'assessment': qwenAvailable ? 'AUTHENTIC' : 'UNAVAILABLE',
      'confidence': qwenAvailable ? 'HIGH' : null,
      'image_quality': qwenAvailable ? 'GOOD' : null,
      'recommendation': qwenAvailable ? 'AUTOMATED SCREENING' : null,
      'reasoning': qwenAvailable
          ? ['Tablet features match authentic baseline.']
          : [],
      'needs_human_verification': false,
    },
    'final_result': 'LIKELY AUTHENTIC',
    'needs_human_verification': false,
    'warning': null,
    'disclaimer': 'AI-assisted preliminary screening only.',
    'secondary_executed': qwenAvailable,
    'secondary_reason': qwenAvailable
        ? 'Verification executed'
        : 'Qwen unavailable',
    'reasons': [
      'Primary classifier indicates authentic',
      'Qwen vision verifier corroborated',
    ],
    'disagreement': false,
    'primary_prediction': prediction,
    'primary_confidence': confidence,
    'status': prediction,
    'model_name': 'efficientnet_b0',
    'threshold': 0.70,
    'authentic_probability': confidence,
    'counterfeit_probability': 1.0 - confidence,
    'quality': {
      'is_valid': true,
      'blur_score': 120.4,
      'brightness_mean': 142.1,
      'dimensions': [224, 224],
    },
    'visual_analysis': {
      'color': {'dominant_color': 'White', 'consistency': 'Uniform'},
      'shape': {'shape_type': 'Round', 'circularity': 0.95},
      'edges': {'edge_integrity': 'Intact'},
      'packaging': {'status': 'Single Tablet'},
    },
  };
}

Map<String, dynamic> _counterfeitJson() {
  return {
    'primary_model': 'efficientnet_b0',
    'prediction': 'COUNTERFEIT',
    'confidence': 0.942,
    'qwen': {
      'available': true,
      'assessment': 'COUNTERFEIT',
      'confidence': 'HIGH',
      'reasoning': ['Chipped edges and irregular imprint detected.'],
      'needs_human_verification': true,
    },
    'final_result': 'LIKELY COUNTERFEIT',
    'needs_human_verification': true,
    'warning': 'Potential counterfeit identified; quarantine sample.',
    'disclaimer': 'AI-assisted preliminary screening only.',
    'secondary_executed': true,
    'disagreement': false,
    'status': 'COUNTERFEIT',
    'model_name': 'efficientnet_b0',
    'threshold': 0.70,
    'authentic_probability': 0.058,
    'counterfeit_probability': 0.942,
    'reasons': ['Primary classifier flagged anomalous surface texture'],
  };
}

void main() {
  group('App theme palette', () {
    test('light and dark selections update the shared screen palette', () {
      AppTheme.setPalette(true);
      expect(AppTheme.background, const Color(0xFFF5F8FC));
      expect(AppTheme.textPrimary, const Color(0xFF17212F));
      expect(AppTheme.primaryCyan, const Color(0xFF087E8B));

      AppTheme.setPalette(false);
      expect(AppTheme.background, const Color(0xFF0B1020));
      expect(AppTheme.textPrimary, const Color(0xFFF3F6FC));
      expect(AppTheme.primaryCyan, const Color(0xFF25D9F8));
    });
  });

  // ── 1. PredictionResponse Schema Parsing Tests ─────────────────────────────
  group('PredictionResponse Parsing Tests', () {
    test('Correctly parses authentic dual-model response from backend', () {
      final response = PredictionResponse.fromJson(_authenticJson());

      expect(response.prediction, 'AUTHENTIC');
      expect(response.finalResult, 'LIKELY AUTHENTIC');
      expect(response.isLikelyAuthentic, isTrue);
      expect(response.isLikelyCounterfeit, isFalse);
      expect(response.isSuspicious, isFalse);
      expect(response.needsHumanVerification, isFalse);
      expect(response.confidenceDisplay, '98.5%');
      expect(response.qwen.available, isTrue);
      expect(response.qwen.assessment, 'AUTHENTIC');
      expect(response.quality?.isValid, isTrue);
      expect(response.visualAnalysis?.color?.dominantColor, 'White');
    });

    test(
      'Correctly parses counterfeit response with human verification flag',
      () {
        final response = PredictionResponse.fromJson(_counterfeitJson());

        expect(response.prediction, 'COUNTERFEIT');
        expect(response.finalResult, 'LIKELY COUNTERFEIT');
        expect(response.isLikelyCounterfeit, isTrue);
        expect(response.needsHumanVerification, isTrue);
        expect(response.counterfeitProbDisplay, '94.2%');
        expect(response.warning, contains('quarantine'));
      },
    );

    test('Qwen unavailable response parsed gracefully with fallback flags', () {
      final response = PredictionResponse.fromJson(
        _authenticJson(qwenAvailable: false),
      );

      expect(response.secondaryExecuted, isFalse);
      expect(response.qwen.available, isFalse);
      expect(response.qwen.assessment, 'UNAVAILABLE');
    });

    test('Defensively parses sparse JSON without throwing exceptions', () {
      final Map<String, dynamic> sparseJson = {
        'prediction': 'UNKNOWN',
        'confidence': 0.52,
        'final_result': 'SUSPICIOUS / NEEDS VERIFICATION',
        'needs_human_verification': true,
        'status': 'NEEDS MANUAL REVIEW',
      };

      final response = PredictionResponse.fromJson(sparseJson);

      expect(response.prediction, 'UNKNOWN');
      expect(response.isSuspicious, isTrue);
      expect(response.qwen.available, isFalse);
      expect(response.quality, isNull);
      expect(response.visualAnalysis, isNull);
      expect(response.confidenceDisplay, 'N/A');
    });

    test('invalid quality blocks verdict display and hides skipped confidence', () {
      final response = PredictionResponse.fromJson({
        ..._authenticJson(),
        'prediction': 'UNKNOWN',
        'primary_prediction': 'UNKNOWN',
        'confidence': 0.0,
        'final_result': 'SUSPICIOUS / NEEDS VERIFICATION',
        'status': 'NEEDS MANUAL REVIEW',
        'needs_human_verification': true,
        'quality': {
          'is_valid': false,
          'reason': 'Poor image quality: excessive blur (score 23.6 < 50.0)',
          'blur_score': 23.64,
          'brightness_mean': 120,
          'dimensions': [225, 225],
        },
        'secondary_executed': false,
        'qwen': {
          'available': false,
          'status': 'SKIPPED',
          'assessment': 'SKIPPED',
          'confidence': 0.0,
        },
      });

      expect(response.isLikelyAuthentic, isFalse);
      expect(response.isLikelyCounterfeit, isFalse);
      expect(response.imageQualityAccepted, isFalse);
      expect(response.confidenceDisplay, 'N/A');
      expect(response.qwen.status, 'SKIPPED');
    });

    test('Parses HealthResponse accurately', () {
      final json = {
        'status': 'ok',
        'version': '1.0.0',
        'device': 'cpu',
        'default_model': 'efficientnet_b0',
        'available_models': ['efficientnet_b0', 'mobilenet_v3'],
        'secondary_ai_model': 'qwen3-vl:4b',
        'secondary_ai_endpoint': 'http://localhost:11434',
      };

      final health = HealthResponse.fromJson(json);
      expect(health.status, 'ok');
      expect(health.device, 'cpu');
      expect(health.secondaryAiModel, 'qwen3-vl:4b');
      expect(health.availableModels.length, 2);
    });
  });

  // ── 2. StorageService Unit Tests ───────────────────────────────────────────
  group('StorageService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      StorageService.resetForTesting();
    });

    test('Default backend URL points to the physical dev endpoint', () async {
      final storage = await StorageService.getInstance();
      expect(storage.getBackendUrl(), AppConstants.defaultDevUrl);
    });

    test('Persists and retrieves custom backend URL', () async {
      final storage = await StorageService.getInstance();
      await storage.setBackendUrl('http://192.168.1.55:8000');
      expect(storage.getBackendUrl(), 'http://192.168.1.55:8000');
    });

    test('Normalizes URL formats correctly', () {
      expect(
        StorageService.normalizeUrl('192.168.1.100:8000'),
        'http://192.168.1.100:8000',
      );
      expect(
        StorageService.normalizeUrl('http://10.0.2.2:8000/'),
        'http://10.0.2.2:8000',
      );
      expect(
        StorageService.normalizeUrl('https://api.example.com///'),
        'https://api.example.com',
      );
    });

    test('Persists classifier threshold, model, and vision mode', () async {
      final storage = await StorageService.getInstance();
      await storage.setThreshold(0.85);
      await storage.setModelName('mobilenet_v3');
      await storage.setVisionMode('always');
      await storage.setEnableQwen(false);

      expect(storage.getThreshold(), 0.85);
      expect(storage.getModelName(), 'mobilenet_v3');
      expect(storage.getVisionMode(), 'always');
      expect(storage.getEnableQwen(), isFalse);
    });

    test('Scan history starts empty', () async {
      final storage = await StorageService.getInstance();
      expect(storage.getScanHistory(), isEmpty);
    });

    test('addScanHistoryItem persists with sample ID and notes', () async {
      final storage = await StorageService.getInstance();
      final response = PredictionResponse.fromJson(_authenticJson());
      final item = ScanHistoryItem.fromPrediction(
        response,
        sampleId: 'SMP-20261018-01',
        medicineName: 'Amoxicillin 500mg',
        notes: 'Lot #A419',
        fileName: 'tablet.jpg',
      );

      await storage.addScanHistoryItem(item);

      final history = storage.getScanHistory();
      expect(history.length, 1);
      expect(history.first.sampleId, 'SMP-20261018-01');
      expect(history.first.medicineName, 'Amoxicillin 500mg');
      expect(history.first.notes, 'Lot #A419');
      expect(history.first.finalResult, 'LIKELY AUTHENTIC');
    });

    test(
      'history CSV safely quotes fields and exports the saved AI review',
      () {
        final json = _authenticJson()
          ..['qwen']['assessment'] = 'AUTHENTIC, REVIEWED'
          ..['qwen']['reasoning'] = [
            'Clear "batch" markings',
            'No obvious defects',
          ];
        final item = ScanHistoryItem.fromPrediction(
          PredictionResponse.fromJson(json),
          sampleId: 'SMP,001',
          medicineName: 'Medicine "A"',
          notes: 'Line one\nLine two',
        );

        final csv = HistoryCsvExporter.encode([item]);

        expect(csv, contains('AI_Review_Status,AI_Assessment,AI_Confidence'));
        expect(csv, contains('COMPLETED,"AUTHENTIC, REVIEWED"'));
        expect(csv, contains('"SMP,001"'));
        expect(csv, contains('"Medicine ""A"""'));
        expect(csv, contains('"Line one\nLine two"'));
        expect(csv, contains('"Clear ""batch"" markings; No obvious defects"'));
      },
    );

    test(
      'history CSV distinguishes skipped AI review from unavailable review',
      () {
        final skipped = _authenticJson(qwenAvailable: false)
          ..['secondary_executed'] = false
          ..['secondary_reason'] =
              'Skipped because the image did not pass quality checks';
        final unavailable = _authenticJson(qwenAvailable: false)
          ..['secondary_executed'] = true
          ..['qwen']['error'] = 'AI service timeout';
        final rows = [
          ScanHistoryItem.fromPrediction(PredictionResponse.fromJson(skipped)),
          ScanHistoryItem.fromPrediction(
            PredictionResponse.fromJson(unavailable),
          ),
        ];

        final csv = HistoryCsvExporter.encode(rows);
        expect(csv, contains('NOT RUN'));
        expect(
          csv,
          contains('Skipped because the image did not pass quality checks'),
        );
        expect(csv, contains('UNAVAILABLE'));
        expect(csv, contains('AI service timeout'));
      },
    );

    test('deleteScanHistoryItem removes single record by id', () async {
      final storage = await StorageService.getInstance();
      final response = PredictionResponse.fromJson(_authenticJson());

      final item1 = ScanHistoryItem.fromPrediction(
        response,
        sampleId: 'SMP-001',
      );
      final item2 = ScanHistoryItem.fromPrediction(
        response,
        sampleId: 'SMP-002',
      );

      await storage.addScanHistoryItem(item1);
      await storage.addScanHistoryItem(item2);

      expect(storage.getScanHistory().length, 2);

      final bool deleted = await storage.deleteScanHistoryItem(item1.id);
      expect(deleted, isTrue);

      final remaining = storage.getScanHistory();
      expect(remaining.length, 1);
      expect(remaining.first.sampleId, 'SMP-002');
    });

    test('clearScanHistory removes all records', () async {
      final storage = await StorageService.getInstance();
      final response = PredictionResponse.fromJson(_authenticJson());
      await storage.addScanHistoryItem(
        ScanHistoryItem.fromPrediction(response),
      );
      expect(storage.getScanHistory().length, 1);

      await storage.clearScanHistory();
      expect(storage.getScanHistory(), isEmpty);
    });

    test('History enforces maximum capacity of 50 records', () async {
      final storage = await StorageService.getInstance();
      final response = PredictionResponse.fromJson(_authenticJson());

      for (int i = 0; i < 55; i++) {
        await storage.addScanHistoryItem(
          ScanHistoryItem.fromPrediction(response, sampleId: 'SMP-$i'),
        );
      }

      final history = storage.getScanHistory();
      expect(history.length, AppConstants.maxHistoryRecords);
      // Newest item should be at the front
      expect(history.first.sampleId, 'SMP-54');
    });

    test('Gracefully recovers from corrupted or malformed history records in storage', () async {
      final malformedList = [
        {'id': '1', 'sample_id': 'VALID-1', 'final_result': 'LIKELY AUTHENTIC'},
        'corrupted string entry instead of object',
        12345,
        {'id': '2', 'sample_id': 'VALID-2', 'confidence': 0.88},
      ];

      SharedPreferences.setMockInitialValues({
        AppConstants.keyScanHistory: jsonEncode(malformedList),
      });
      StorageService.resetForTesting();

      final storage = await StorageService.getInstance();
      final history = storage.getScanHistory();

      // Only the two valid map objects should be decoded
      expect(history.length, 2);
      expect(history.any((e) => e.sampleId == 'VALID-1'), isTrue);
      expect(history.any((e) => e.sampleId == 'VALID-2'), isTrue);
    });
  });

  // ── 3. Field Report Generation Service Tests ──────────────────────────────
  group('ReportService Tests', () {
    test('Generates structured plain-text inspection report with all required sections', () {
      final response = PredictionResponse.fromJson(_authenticJson());
      final report = ReportService.generateTextReport(
        result: response,
        sampleId: 'SMP-2026-990',
        medicineName: 'Paracetamol 500mg',
        notes: 'Inspection at distribution warehouse #3',
        fileName: 'sample_c3pi.jpg',
      );

      expect(report, contains('FIELD SCREENING REPORT'));
      expect(report, contains('SMP-2026-990'));
      expect(report, contains('Paracetamol 500mg'));
      expect(report, contains('Inspection at distribution warehouse #3'));
      expect(report, contains('LIKELY AUTHENTIC'));
      expect(report, contains('98.5%'));
      expect(report, contains('Laplacian sharpness score'));
      expect(report, contains('REGULATORY & MEDICAL DISCLAIMER'));
      expect(
        report,
        contains('Definitive authentication requires certified chemical'),
      );
    });

    test('Generates report from ScanHistoryItem correctly', () {
      final response = PredictionResponse.fromJson(_counterfeitJson());
      final item = ScanHistoryItem.fromPrediction(
        response,
        sampleId: 'SMP-ALERT-01',
        medicineName: 'Fake Drug X',
        notes: 'Suspect blister packaging',
      );

      final report = ReportService.generateReportFromHistory(item);
      expect(report, contains('SMP-ALERT-01'));
      expect(report, contains('Fake Drug X'));
      expect(report, contains('LIKELY COUNTERFEIT'));
    });

    test('quality rejection is reported as stopped screening, not zero-confidence inference', () {
      final json = _authenticJson(qwenAvailable: false)
        ..['prediction'] = 'UNKNOWN'
        ..['confidence'] = 0.0
        ..['final_result'] = 'SUSPICIOUS / NEEDS VERIFICATION'
        ..['needs_human_verification'] = true
        ..['secondary_executed'] = false
        ..['secondary_reason'] = 'Skipped: image quality check failed'
        ..['authentic_probability'] = 0.0
        ..['counterfeit_probability'] = 0.0
        ..['quality'] = {
          'is_valid': false,
          'reason': 'Poor image quality: excessive blur (score 28.4 < 50.0)',
          'blur_score': 28.4,
          'brightness_mean': 101.9,
          'contrast': 64.6,
          'dimensions': [4096, 3072],
        };

      final report = ReportService.generateTextReport(
        result: PredictionResponse.fromJson(json),
        sampleId: 'SMP-261018-1506',
      );

      expect(report, contains('INCONCLUSIVE - MANUAL REVIEW REQUIRED'));
      expect(report, contains('NOT COMPLETED'));
      expect(report, contains('Model confidence  : Not available'));
      expect(report, contains('Probability dist. : Not generated'));
      expect(report, contains('FAILED - INFERENCE NOT RUN'));
      expect(report, contains('Retake a clear, in-focus image'));
      expect(report, contains('AI Availability  : Not assessed for this scan'));
      expect(report, isNot(contains('Unavailable / Offline')));
    });

    test('blur warning includes only a provisional classifier output', () {
      final json = _authenticJson(qwenAvailable: false)
        ..['prediction'] = 'COUNTERFEIT'
        ..['confidence'] = 0.86
        ..['final_result'] = 'SUSPICIOUS / NEEDS VERIFICATION'
        ..['needs_human_verification'] = true
        ..['quality'] = {
          'is_valid': false,
          'reason': 'Poor image quality: excessive blur (score 18.3 < 50.0)',
          'blur_score': 18.3,
          'brightness_mean': 101.9,
          'dimensions': [4096, 3072],
        };

      final report = ReportService.generateTextReport(
        result: PredictionResponse.fromJson(json),
        sampleId: 'SMP-BLUR-01',
      );

      expect(report, contains('SUSPICIOUS / NEEDS VERIFICATION'));
      expect(report, contains('PRELIMINARY ONLY - COUNTERFEIT'));
      expect(report, contains('86.0%'));
      expect(report, contains('FAILED - MODEL OUTPUT PROVISIONAL'));
      expect(report, isNot(contains('NOT COMPLETED')));
    });
  });

  // ── 4. UI Widget & State Rendering Tests ──────────────────────────────────
  group('UI Widget Tests', () {
    testWidgets('StatusBadge renders authentic indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadge(statusText: 'LIKELY AUTHENTIC')),
        ),
      );

      expect(find.text('LIKELY AUTHENTIC'), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    });

    testWidgets('StatusBadge renders counterfeit indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadge(statusText: 'LIKELY COUNTERFEIT')),
        ),
      );

      expect(find.text('LIKELY COUNTERFEIT'), findsOneWidget);
      expect(find.byIcon(Icons.gpp_bad_outlined), findsOneWidget);
    });

    testWidgets('StatusBadge renders suspicious/review indicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(statusText: 'SUSPICIOUS / NEEDS VERIFICATION'),
          ),
        ),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('ConfidenceGauge renders percentage and dual probabilities', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConfidenceGauge(
              confidence: 0.884,
              authenticProb: 0.884,
              counterfeitProb: 0.116,
            ),
          ),
        ),
      );

      expect(find.text('88.4%'), findsNWidgets(2));
      expect(find.text('Model confidence'), findsOneWidget);
      expect(find.text('Authentic-like match'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('DisclaimerBanner displays mandatory medical screening text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DisclaimerBanner())),
      );

      expect(find.text('Preliminary Screening Advisory'), findsOneWidget);
      expect(find.byIcon(Icons.health_and_safety_outlined), findsOneWidget);
    });

    testWidgets(
      'ResultsScreen displays authentic outcome state and sample specifications',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final response = PredictionResponse.fromJson(_authenticJson());

        await tester.pumpWidget(
          MaterialApp(
            home: ResultsScreen(
              result: response,
              sampleId: 'SMP-TEST-001',
              medicineName: 'Amoxicillin',
              notes: 'Test blister inspection',
            ),
          ),
        );

        expect(find.text('Field Screening Report'), findsOneWidget);
        expect(find.text('SCREENING INDICATES AUTHENTIC'), findsOneWidget);
        expect(
          find.text('Main model prediction: likely authentic'),
          findsOneWidget,
        );
        expect(find.text('Review completed'), findsOneWidget);
        expect(find.text('SMP-TEST-001'), findsOneWidget);
        expect(find.text('Amoxicillin'), findsOneWidget);
        expect(find.text('Test blister inspection'), findsOneWidget);
        expect(find.text('SHARE / EXPORT INSPECTION REPORT'), findsOneWidget);
        expect(find.text('START NEW INSPECTION'), findsOneWidget);
      },
    );

    testWidgets('skipped optional review is not mislabeled as offline', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final response = PredictionResponse.fromJson(
        _authenticJson(qwenAvailable: false),
      );
      await tester.pumpWidget(
        MaterialApp(home: ResultsScreen(result: response)),
      );

      expect(find.text('Not run for this image'), findsOneWidget);
      expect(find.textContaining('offline'), findsNothing);
    });

    testWidgets(
      'rejected blur blocks a verdict and requests a retake',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final json = _authenticJson(qwenAvailable: false)
          ..['prediction'] = 'UNKNOWN'
          ..['primary_prediction'] = 'UNKNOWN'
          ..['confidence'] = 0.0
          ..['primary_confidence'] = 0.0
          ..['authentic_probability'] = 0.0
          ..['counterfeit_probability'] = 0.0
          ..['final_result'] = 'SUSPICIOUS / NEEDS VERIFICATION'
          ..['status'] = 'NEEDS MANUAL REVIEW'
          ..['needs_human_verification'] = true
          ..['quality'] = {
            'is_valid': false,
            'reason': 'Poor image quality: excessive blur (score 28.4 < 50.0)',
            'blur_score': 28.4,
            'brightness_mean': 101.9,
            'dimensions': [4096, 3072],
          };
        await tester.pumpWidget(
          MaterialApp(
            home: ResultsScreen(result: PredictionResponse.fromJson(json)),
          ),
        );

        expect(
          find.textContaining('did not pass the image-quality check'),
          findsOneWidget,
        );
        expect(find.text('88.4%'), findsNothing);
        expect(find.text('SCREENING INDICATES AUTHENTIC'), findsNothing);
        expect(find.text('SCREENING INDICATES COUNTERFEIT'), findsNothing);
        expect(find.text('RETAKE'), findsOneWidget);
      },
    );

    testWidgets(
      'ResultsScreen displays counterfeit outcome state with quarantine warning',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final response = PredictionResponse.fromJson(_counterfeitJson());

        await tester.pumpWidget(
          MaterialApp(
            home: ResultsScreen(
              result: response,
              sampleId: 'SMP-ALERT-999',
              medicineName: 'Counterfeit Sample',
            ),
          ),
        );

        expect(find.text('SCREENING INDICATES COUNTERFEIT'), findsOneWidget);
        expect(
          find.text('Ask a pharmacist to review this result'),
          findsOneWidget,
        );
        expect(
          find.text('Potential counterfeit identified; quarantine sample.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Report dialog opens and displays formatted inspection text', (
      tester,
    ) async {
      const sampleReport =
          'PHARMAASSIST - FIELD SCREENING REPORT\nInspection ID: SMP-123\nResult: AUTHENTIC';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ReportService.showReportDialog(
                      context: context,
                      reportText: sampleReport,
                      sampleId: 'SMP-123',
                    );
                  },
                  child: const Text('Open Report'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();

      expect(find.text('Field Inspection Report'), findsOneWidget);
      expect(find.textContaining('SMP-123'), findsOneWidget);
      expect(find.text('Copy to Clipboard'), findsOneWidget);
    });

    testWidgets(
      'HistoryScreen displays empty state when no inspections recorded',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        StorageService.resetForTesting();
        final storage = await StorageService.getInstance();

        await tester.pumpWidget(
          MaterialApp(home: HistoryScreen(storage: storage)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Inspection Records'), findsOneWidget);
        expect(find.text('No Inspection Records'), findsOneWidget);
        expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'HistoryScreen renders populated records and filters by query',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        StorageService.resetForTesting();
        final storage = await StorageService.getInstance();

        final resp1 = PredictionResponse.fromJson(_authenticJson());
        final resp2 = PredictionResponse.fromJson(_counterfeitJson());

        await storage.addScanHistoryItem(
          ScanHistoryItem.fromPrediction(
            resp1,
            sampleId: 'SMP-AUTH-10',
            medicineName: 'Genuine Pill',
          ),
        );
        await storage.addScanHistoryItem(
          ScanHistoryItem.fromPrediction(
            resp2,
            sampleId: 'SMP-FAKE-20',
            medicineName: 'Counterfeit Pill',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: HistoryScreen(storage: storage)),
        );
        await tester.pumpAndSettle();

        expect(find.text('SMP-AUTH-10'), findsOneWidget);
        expect(find.text('SMP-FAKE-20'), findsOneWidget);

        // Search for 'FAKE'
        await tester.enterText(find.byType(TextField), 'FAKE');
        await tester.pumpAndSettle();

        expect(find.text('SMP-FAKE-20'), findsOneWidget);
        expect(find.text('SMP-AUTH-10'), findsNothing);
      },
    );

    testWidgets(
      'HomeScreen dashboard renders identity, primary scan card, and status',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        StorageService.resetForTesting();
        final storage = await StorageService.getInstance();
        final apiService = ApiService(storage);

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(storage: storage, apiService: apiService),
          ),
        );
        await tester.pump();

        expect(find.text('PharmaAssist'), findsOneWidget);
        expect(
          find.text('Pharmaceutical screening, made clearer.'),
          findsOneWidget,
        );
        expect(find.text('Scan medicine'), findsOneWidget);
        expect(find.text('RECENT SCREENINGS'), findsOneWidget);
        expect(find.text('Preliminary Screening Advisory'), findsOneWidget);
      },
    );

    testWidgets('ScanScreen renders 5 sections and sample inputs', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      StorageService.resetForTesting();
      final storage = await StorageService.getInstance();
      final apiService = ApiService(storage);

      await tester.pumpWidget(
        MaterialApp(
          home: ScanScreen(storage: storage, apiService: apiService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scan Medicine'), findsOneWidget);
      expect(find.text('1. CHOOSE A PHOTO'), findsOneWidget);
      expect(find.text('2. CHECK THE PHOTO'), findsOneWidget);
      expect(find.text('Photo check'), findsOneWidget);
      expect(find.text('How to take a clear photo'), findsOneWidget);
      expect(find.textContaining('Hold the camera above it'), findsOneWidget);
      expect(find.text('3. OPTIONAL DETAILS'), findsOneWidget);
      expect(find.text('4. HOW SCREENING WORKS'), findsOneWidget);
      expect(find.text('RUN PHARMACEUTICAL SCREENING'), findsOneWidget);
      final pipelineParameters = find.text('One screening process');
      await tester.scrollUntilVisible(
        pipelineParameters,
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(pipelineParameters);
      await tester.pumpAndSettle();
      expect(find.text(AppConstants.visionModeAutoLabel), findsOneWidget);
    });

    testWidgets(
      'SettingsScreen renders themes, endpoints, and storage controls',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          AppConstants.keyThemeMode: 'system',
        });
        StorageService.resetForTesting();
        final storage = await StorageService.getInstance();
        final apiService = ApiService(storage);

        await tester.pumpWidget(
          MaterialApp(
            home: SettingsScreen(storage: storage, apiService: apiService),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Settings & Diagnostics'), findsOneWidget);
        expect(find.text('APPEARANCE & THEME'), findsOneWidget);
        expect(find.text('BACKEND COMMUNICATION ENDPOINT'), findsOneWidget);
        expect(find.text('DETECTION MODEL PARAMETERS'), findsOneWidget);
        expect(find.text('DARK'), findsOneWidget);
        expect(find.text('LIGHT'), findsOneWidget);
        expect(find.text('SYSTEM'), findsNothing);
        expect(storage.getThemeMode(), 'dark');
        final visionModeLabel = find.text(AppConstants.visionModeAutoLabel);
        await tester.scrollUntilVisible(
          visionModeLabel,
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        expect(visionModeLabel, findsOneWidget);

        final aboutCard = find.text('About PharmaAssist Instrument');
        await tester.scrollUntilVisible(
          aboutCard,
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        expect(aboutCard, findsOneWidget);

        final applyBtn = find.text('APPLY & SAVE SETTINGS');
        await tester.scrollUntilVisible(
          applyBtn,
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        expect(applyBtn, findsOneWidget);

        final modelLabCard = find.text('Model Laboratory');
        await tester.scrollUntilVisible(
          modelLabCard,
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        expect(modelLabCard, findsOneWidget);
      },
    );

    testWidgets('ModelLabScreen renders 3 tabs and header', (tester) async {
      SharedPreferences.setMockInitialValues({});
      StorageService.resetForTesting();
      final storage = await StorageService.getInstance();
      final apiService = ApiService(storage);

      await tester.pumpWidget(
        MaterialApp(
          home: ModelLabScreen(storage: storage, apiService: apiService),
        ),
      );

      expect(find.text('Model Laboratory'), findsOneWidget);
      expect(find.text('REGISTRY'), findsOneWidget);
      expect(find.text('QWEN AI'), findsOneWidget);
      expect(find.text('HISTORY'), findsOneWidget);
    });

    testWidgets(
      'ModelLabScreen QWEN AI tab switches and renders integration notice',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        StorageService.resetForTesting();
        final storage = await StorageService.getInstance();
        final apiService = ApiService(storage);

        await tester.pumpWidget(
          MaterialApp(
            home: ModelLabScreen(storage: storage, apiService: apiService),
          ),
        );

        await tester.tap(find.text('QWEN AI'));
        await tester.pumpAndSettle();

        // In offline widget test environment without mock HTTP, it displays the error state with Retry
        expect(find.byType(TabBarView), findsOneWidget);
        expect(find.text('Qwen status check failed'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      },
    );

    testWidgets(
      'ModelLabScreen HISTORY tab displays search bar and empty state',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        StorageService.resetForTesting();
        final storage = await StorageService.getInstance();
        final apiService = ApiService(storage);

        await tester.pumpWidget(
          MaterialApp(
            home: ModelLabScreen(storage: storage, apiService: apiService),
          ),
        );

        await tester.tap(find.text('HISTORY'));
        await tester.pumpAndSettle();

        expect(find.text('No inspection records'), findsOneWidget);
      },
    );
  });
}
