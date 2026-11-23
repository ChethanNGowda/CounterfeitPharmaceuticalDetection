import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/models/packaging_checklist.dart';
import 'package:pharma_assist/models/medicine_profile.dart';
import 'package:pharma_assist/screens/medicine_screen.dart';
import 'package:pharma_assist/screens/packaging_checklist_screen.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<StorageService> createStorage() async {
  SharedPreferences.setMockInitialValues({});
  StorageService.resetForTesting();
  return StorageService.getInstance();
}

Future<void> scrollToListItem(WidgetTester tester, Finder target) async {
  final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
  final list = find.byType(ListView).first;
  for (var attempt = 0; attempt < 16; attempt++) {
    if (target.evaluate().isNotEmpty) {
      final rect = tester.getRect(target.first);
      if (rect.top >= 0 && rect.bottom <= viewport.height) return;
    }
    await tester.drag(list, const Offset(0, -320));
    await tester.pumpAndSettle();
  }
  fail('Could not scroll target into view: $target');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'medicine editor rejects malformed dates and saves reviewed data',
    (tester) async {
      final storage = await createStorage();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: MedicineScreen(storage: storage)),
      );
      await tester.tap(find.byTooltip('Add Medicine Manually'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('medicine-expiry-date-field')),
        '19/2028',
      );
      final save = find.text('Save Confirmed Profile');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(storage.getMedicineProfiles(), isEmpty);
      expect(
        find.textContaining('Enter a valid date such as MM/YYYY'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('medicine-name-field')),
        'Reviewed Medicine',
      );
      await tester.enterText(
        find.byKey(const ValueKey('medicine-strength-field')),
        '250 mg',
      );
      await tester.enterText(
        find.byKey(const ValueKey('medicine-dosage-form-field')),
        'Capsule',
      );
      await tester.enterText(
        find.byKey(const ValueKey('medicine-manufacturer-field')),
        'Example Labs',
      );
      await tester.enterText(
        find.byKey(const ValueKey('medicine-batch-field')),
        'LOT-27',
      );
      await tester.enterText(
        find.byKey(const ValueKey('medicine-manufacturing-date-field')),
        '01/2028',
      );
      await tester.enterText(
        find.byKey(const ValueKey('medicine-expiry-date-field')),
        '02/2028',
      );
      await tester.enterText(
        find.byKey(const ValueKey('medicine-mrp-field')),
        '25.50',
      );
      await tester.enterText(
        find.byKey(const ValueKey('medicine-identifier-field')),
        '8901234567890',
      );
      final additionalDetails = find.text('More printed package details');
      await tester.ensureVisible(additionalDetails);
      await tester.tap(additionalDetails);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('medicine-generic-name-field')),
        'Reviewed generic name',
      );
      await tester.enterText(
        find.byKey(const ValueKey('medicine-composition-field')),
        'As printed: 250 mg',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final saved = storage.getMedicineProfiles().single;
      expect(saved.medicineName, 'Reviewed Medicine');
      expect(saved.strength, '250 mg');
      expect(saved.dosageForm, 'Capsule');
      expect(saved.manufacturer, 'Example Labs');
      expect(saved.batchNumber, 'LOT-27');
      expect(saved.manufacturingDate, '01/2028');
      expect(saved.expiryDate, '02/2028');
      expect(saved.mrp, '25.50');
      expect(saved.productIdentifier, '8901234567890');
      expect(saved.productIdentifierFormat, 'manual');
      expect(saved.genericName, 'Reviewed generic name');
      expect(saved.composition, 'As printed: 250 mg');
      expect(saved.auditHistory, isNotEmpty);
      expect(saved.isVerifiedByUser, isFalse);
    },
  );

  testWidgets('medicine profile keeps separate batch expiry records', (
    tester,
  ) async {
    final storage = await createStorage();
    final now = DateTime.now();
    await storage.saveMedicineProfile(
      MedicineProfile(
        id: 'batch-profile',
        medicineName: 'Batch Medicine',
        batchNumber: 'LOT-OLD',
        expiryDate: '04/2028',
        createdAt: now,
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: MedicineScreen(storage: storage)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batch Medicine').first);
    await tester.pumpAndSettle();

    final addBatch = find.text('Add another batch');
    await tester.ensureVisible(addBatch);
    await tester.tap(addBatch);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('medicine-batch-field')),
      'LOT-NEW',
    );
    await tester.enterText(
      find.byKey(const ValueKey('medicine-expiry-date-field')),
      '08/2029',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final save = find.text('Update Profile');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final saved = storage.getMedicineProfiles().single;
    expect(saved.batches, hasLength(2));
    expect(saved.batches.map((batch) => batch.batchNumber), [
      'LOT-OLD',
      'LOT-NEW',
    ]);
    expect(saved.batchNumber, 'LOT-NEW');
    expect(saved.expiryDate, '08/2029');
  });

  testWidgets(
    'checklist saves user observations and keeps AI result separate',
    (tester) async {
      final storage = await createStorage();
      await tester.pumpWidget(
        MaterialApp(home: PackagingChecklistScreen(storage: storage)),
      );

      expect(
        find.textContaining('stores your visual observations only'),
        findsOneWidget,
      );
      final firstStatus = find.text('Normal').first;
      await scrollToListItem(tester, firstStatus);
      await tester.tap(firstStatus);
      final noteField = find.byType(TextFormField).first;
      await scrollToListItem(tester, noteField);
      await tester.enterText(
        noteField,
        'Foil seal appears intact on visual inspection.',
      );
      final save = find.text('Save Inspection Summary');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await scrollToListItem(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Incomplete Inspection Items'), findsOneWidget);
      await tester.tap(find.text('Save Anyway'));
      await tester.pumpAndSettle();

      final saved = storage.getChecklistSummaries().single;
      expect(saved.isComplete, isFalse);
      expect(saved.items.first.status, 'PASS');
      expect(
        saved.items.first.notes,
        'Foil seal appears intact on visual inspection.',
      );
      expect(saved.medicineName, isEmpty);
      expect(find.text('Saved user observations'), findsOneWidget);
      expect(find.textContaining('Foil seal appears intact'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete saved inspection'));
      await tester.pumpAndSettle();
      expect(find.text('Delete saved inspection?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(storage.getChecklistSummaries(), isEmpty);
    },
  );

  testWidgets('checklist cannot save a blank sample identifier', (
    tester,
  ) async {
    final storage = await createStorage();
    await tester.pumpWidget(
      MaterialApp(home: PackagingChecklistScreen(storage: storage)),
    );
    await tester.enterText(
      find.byKey(const ValueKey('checklist-sample-id-field')),
      '   ',
    );
    final firstStatus = find.text('Normal').first;
    tester.testTextInput.hide();
    await scrollToListItem(tester, firstStatus);
    await tester.tap(firstStatus);
    final save = find.text('Save Inspection Summary');
    await scrollToListItem(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(storage.getChecklistSummaries(), isEmpty);
    expect(find.text('Enter a sample ID before saving.'), findsOneWidget);
  });

  testWidgets('checklist requires at least one recorded observation', (
    tester,
  ) async {
    final storage = await createStorage();
    await tester.pumpWidget(
      MaterialApp(home: PackagingChecklistScreen(storage: storage)),
    );
    final save = find.text('Save Inspection Summary');
    await scrollToListItem(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(storage.getChecklistSummaries(), isEmpty);
    expect(
      find.text('Record at least one packaging observation before saving.'),
      findsOneWidget,
    );
  });

  test('legacy checklist statuses normalize safely without losing notes', () {
    final summary = PackagingChecklistSummary.fromJson({
      'id': 'old-summary',
      'sample_id': 'old-sample',
      'items': [
        {
          'id': 'seal',
          'title': 'Seal',
          'description': 'Visual check',
          'criteria': 'Inspect it',
          'status': 'pass',
          'notes': 'Observed by user',
        },
        {
          'id': 'batch',
          'title': 'Batch',
          'description': 'Visual check',
          'criteria': 'Inspect it',
          'status': 'unexpected',
        },
        null,
      ],
      'inspected_at': '2026-11-22T00:00:00.000',
    });

    expect(summary.items[0].status, 'PASS');
    expect(summary.items[0].notes, 'Observed by user');
    expect(summary.items[1].status, 'UNCHECKED');
    expect(summary.items, hasLength(2));
    expect(summary.medicineName, isEmpty);
  });
}
