import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/models/prediction_response.dart';
import 'package:pharma_assist/screens/about_screen.dart';
import 'package:pharma_assist/screens/history_screen.dart';
import 'package:pharma_assist/screens/home_screen.dart';
import 'package:pharma_assist/screens/medicine_screen.dart';
import 'package:pharma_assist/screens/model_lab_screen.dart';
import 'package:pharma_assist/screens/more_hub_screen.dart';
import 'package:pharma_assist/screens/onboarding_screen.dart';
import 'package:pharma_assist/screens/packaging_checklist_screen.dart';
import 'package:pharma_assist/screens/packaging_guide_screen.dart';
import 'package:pharma_assist/screens/pharma_license_screen.dart';
import 'package:pharma_assist/screens/photo_comparison_screen.dart';
import 'package:pharma_assist/screens/records_screen.dart';
import 'package:pharma_assist/screens/reports_screen.dart';
import 'package:pharma_assist/screens/results_screen.dart';
import 'package:pharma_assist/screens/scan_screen.dart';
import 'package:pharma_assist/screens/screening_insights_screen.dart';
import 'package:pharma_assist/screens/settings_screen.dart';
import 'package:pharma_assist/services/api_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('primary screens fit narrow and wide layouts at enlarged text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTesting();
    final storage = await StorageService.getInstance();
    final api = ApiService(
      storage,
      MockClient((_) async => http.Response('{}', 503)),
    );
    final result = PredictionResponse.fromJson({
      'prediction': 'AUTHENTIC',
      'confidence': 0.84,
      'final_result': 'LIKELY AUTHENTIC',
      'quality': {
        'is_valid': true,
        'blur_score': 72.0,
        'brightness_mean': 128.0,
        'dimensions': [640, 640],
      },
    });

    final screens = <String, Widget Function()>{
      'home': () => HomeScreen(storage: storage, apiService: api),
      'scanner': () => ScanScreen(storage: storage, apiService: api),
      'results': () => ResultsScreen(result: result, sampleId: 'PA-TEST'),
      'history comparison': () => HistoryScreen(storage: storage),
      'records': () => RecordsScreen(storage: storage),
      'reports': () => ReportsScreen(storage: storage),
      'medicine': () => MedicineScreen(storage: storage),
      'more hub': () => MoreHubScreen(storage: storage, apiService: api),
      'model lab': () => ModelLabScreen(storage: storage, apiService: api),
      'packaging checklist': () => PackagingChecklistScreen(storage: storage),
      'packaging guide': () => const PackagingGuideScreen(),
      'photo comparison': () => PhotoComparisonScreen(storage: storage),
      'screening insights': () => ScreeningInsightsScreen(storage: storage),
      'about': () => const AboutScreen(),
      'settings': () => SettingsScreen(storage: storage, apiService: api),
      'license': () => const PharmaLicenseScreen(),
      'onboarding': () => OnboardingScreen(onComplete: () {}),
    };

    final layoutErrors = <String>[];
    for (final viewport in [const Size(360, 720), const Size(1280, 900)]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport;
      for (final entry in screens.entries) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: Builder(builder: (_) => entry.value()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final error = tester.takeException();
        if (error != null) {
          layoutErrors.add('${entry.key} at $viewport: $error');
        }
      }
    }

    expect(layoutErrors, isEmpty, reason: layoutErrors.join('\n'));

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
