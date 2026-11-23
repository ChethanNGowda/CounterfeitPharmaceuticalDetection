import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/core/theme.dart';

void main() {
  group('PharmaAssist Material 3 themes', () {
    for (final entry in <(String, ThemeData, Brightness)>[
      ('light', AppTheme.lightTheme, Brightness.light),
      ('dark', AppTheme.darkTheme, Brightness.dark),
    ]) {
      test('${entry.$1} theme styles shared Material controls', () {
        final theme = entry.$2;

        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, entry.$3);
        expect(theme.colorScheme.brightness, entry.$3);
        expect(theme.cardTheme.shape, isNotNull);
        expect(theme.dialogTheme.backgroundColor, isNotNull);
        expect(theme.bottomSheetTheme.showDragHandle, isTrue);
        expect(theme.inputDecorationTheme.filled, isTrue);
        expect(theme.navigationBarTheme.backgroundColor, isNotNull);
        expect(theme.navigationRailTheme.backgroundColor, isNotNull);
        expect(theme.progressIndicatorTheme.color, theme.colorScheme.primary);
        expect(theme.elevatedButtonTheme.style, isNotNull);
        expect(theme.filledButtonTheme.style, isNotNull);
        expect(theme.textButtonTheme.style, isNotNull);
        expect(theme.iconButtonTheme.style, isNotNull);
      });
    }

    testWidgets('theme mode applies palette to app bar, fields, and surfaces', (
      tester,
    ) async {
      for (final mode in ThemeMode.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            home: Scaffold(
              appBar: AppBar(title: const Text('Theme check')),
              body: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(labelText: 'Medicine'),
                    ),
                    Card(child: ListTile(title: Text('Saved record'))),
                    FilledButton(onPressed: null, child: Text('Continue')),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final theme = Theme.of(tester.element(find.text('Theme check')));
        expect(theme.useMaterial3, isTrue);
        if (mode == ThemeMode.light) {
          expect(theme.brightness, Brightness.light);
        } else if (mode == ThemeMode.dark) {
          expect(theme.brightness, Brightness.dark);
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('bottom navigation fits 360px with enlarged labels', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 720);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              bottomNavigationBar: NavigationBar(
                selectedIndex: 2,
                onDestinationSelected: (_) {},
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                  NavigationDestination(
                    icon: Icon(Icons.camera),
                    label: 'Scan',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.medication),
                    label: 'Medicine',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.folder),
                    label: 'Records',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz),
                    label: 'More',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });
  });
}
