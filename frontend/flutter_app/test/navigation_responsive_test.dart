import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/core/theme.dart';
import 'package:pharma_assist/main.dart';
import 'package:pharma_assist/services/api_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('navigation adapts to phone, tablet, and enlarged text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyOnboardingComplete: true,
    });
    StorageService.resetForTesting();
    final storage = await StorageService.getInstance();
    final api = ApiService(
      storage,
      MockClient((_) async => http.Response('{}', 503)),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 720);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: MainNavigationScaffold(storage: storage, apiService: api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    final phoneException = tester.takeException();
    expect(phoneException, isNull);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('reports can be opened from the More destination', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyOnboardingComplete: true,
    });
    StorageService.resetForTesting();
    final storage = await StorageService.getInstance();
    final api = ApiService(
      storage,
      MockClient((_) async => http.Response('{}', 503)),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: MainNavigationScaffold(storage: storage, apiService: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Screening reports'));
    await tester.pumpAndSettle();

    expect(find.text('Inspection Reports'), findsOneWidget);
  });
}
