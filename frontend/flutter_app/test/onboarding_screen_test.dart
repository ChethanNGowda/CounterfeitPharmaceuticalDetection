import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/screens/onboarding_screen.dart';

void main() {
  testWidgets('onboarding explains screening limits and completes', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onComplete: () => completed = true)),
    );

    expect(find.text('PharmaAssist'), findsOneWidget);
    expect(
      find.text('A careful first look at medicine packaging'),
      findsOneWidget,
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Works offline for record keeping'), findsOneWidget);
    expect(find.textContaining('not proof of authenticity'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    expect(completed, isTrue);
  });

  testWidgets('onboarding can be skipped', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onComplete: () => completed = true)),
    );
    await tester.tap(find.text('Skip'));
    expect(completed, isTrue);
  });
}
