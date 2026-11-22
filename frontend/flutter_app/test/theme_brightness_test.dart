import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/main.dart';
import 'package:pharma_assist/services/api_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('System appearance follows device brightness changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyThemeMode: 'system',
      AppConstants.keyOnboardingComplete: true,
    });
    StorageService.resetForTesting();
    final storage = await StorageService.getInstance();
    final api = ApiService(storage);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpWidget(PharmaAssistApp(storage: storage, apiService: api));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );
    expect(AppTheme.background, const Color(0xFFF4F8FB));

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    tester.binding.handlePlatformBrightnessChanged();
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    expect(AppTheme.background, const Color(0xFF102A43));
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
}
