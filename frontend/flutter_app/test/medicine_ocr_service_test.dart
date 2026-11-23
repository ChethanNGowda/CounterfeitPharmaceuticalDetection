import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/services/medicine_ocr_service.dart';

void main() {
  group('MedicineOcrService real-text extraction', () {
    test(
      'extracts labelled pharmaceutical fields without fabricated values',
      () {
        const packagingText = '''
Amoxicillin Trihydrate
Tablets 500 mg
Batch No: B-98421
Mfg Date: 01/2026
Exp Date: 12/2027
Mfd by: Global Healthcare Ltd.
''';

        final result = MedicineOcrService.parsePackagingText(packagingText);

        expect(result.medicineName, 'Amoxicillin Trihydrate');
        expect(result.strength, '500 mg');
        expect(result.dosageForm, 'Tablets');
        expect(result.batchNumber, 'B-98421');
        expect(result.manufacturingDate, '01/2026');
        expect(result.expiryDate, '12/2027');
        expect(result.manufacturer, 'Global Healthcare Ltd.');
        expect(result.rawText, contains('Amoxicillin Trihydrate'));
        expect(result.confidence, 'HIGH');
      },
    );

    test('leaves missing batch and expiry values blank', () {
      final result = MedicineOcrService.parsePackagingText(
        'Paracetamol\nTablets 500 mg\n',
      );

      expect(result.medicineName, 'Paracetamol');
      expect(result.strength, '500 mg');
      expect(result.batchNumber, isEmpty);
      expect(result.expiryDate, isEmpty);
      expect(result.manufacturingDate, isEmpty);
      expect(result.manufacturer, isEmpty);
      expect(result.confidence, 'MEDIUM');
    });

    test('empty OCR result does not create sample medicine details', () {
      final result = MedicineOcrService.parsePackagingText('  \n ');

      expect(result.medicineName, isEmpty);
      expect(result.manufacturer, isEmpty);
      expect(result.strength, isEmpty);
      expect(result.batchNumber, isEmpty);
      expect(result.expiryDate, isEmpty);
      expect(result.confidence, 'UNCERTAIN');
    });

    test('supports expiry and batch values printed on the next line', () {
      final result = MedicineOcrService.parsePackagingText(
        'Cetirizine\nBatch No\nCT-1204\nEXP Date\n08/2028',
      );

      expect(result.batchNumber, 'CT-1204');
      expect(result.expiryDate, '08/2028');
    });

    test('extracts explicitly labelled medicine names and dosage details', () {
      final result = MedicineOcrService.parsePackagingText('''
Product Name: Amoxicillin Trihydrate
Strength: 250 mg/5 mL
Dosage Form: Oral Suspension
Manufactured by: Example Labs Ltd.
Batch No: AB-22
EXP: 08/2028
''');

      expect(result.medicineName, 'Amoxicillin Trihydrate');
      expect(result.manufacturer, 'Example Labs Ltd.');
      expect(result.strength, '250 mg/5 mL');
      expect(result.dosageForm, 'Suspension');
      expect(result.batchNumber, 'AB-22');
      expect(result.expiryDate, '08/2028');
    });

    test('ignores impossible expiry dates and does not cross date labels', () {
      final malformed = MedicineOcrService.parsePackagingText(
        'Paracetamol\nEXP: 19/2028',
      );
      expect(malformed.expiryDate, isEmpty);

      final separateLabels = MedicineOcrService.parsePackagingText(
        'Cetirizine\nEXP Date\nMFG Date: 03/2026\nBatch: CT-4',
      );
      expect(separateLabels.expiryDate, isEmpty);
      expect(separateLabels.manufacturingDate, '03/2026');

      final malformedManufacturing = MedicineOcrService.parsePackagingText(
        'Cetirizine\nMFG Date: 29/13/2026',
      );
      expect(malformedManufacturing.manufacturingDate, isEmpty);
    });

    test('does not read the next labelled field as a batch number', () {
      final result = MedicineOcrService.parsePackagingText(
        'Paracetamol\nBatch No\nEXP: 08/2028',
      );

      expect(result.batchNumber, isEmpty);
      expect(result.expiryDate, '08/2028');
    });

    test('recognizes the full manufacturing-date label', () {
      final result = MedicineOcrService.parsePackagingText(
        'Product Name: Example Medicine\nManufacturing Date: 01/2026',
      );

      expect(result.manufacturingDate, '01/2026');
    });

    test('accepts legacy two digit month/year expiry labels', () {
      final result = MedicineOcrService.parsePackagingText(
        'Product Name: Example Medicine\nEXP: 11/27',
      );
      expect(result.expiryDate, '11/27');
    });

    test('toProfile leaves every unrecognized medicine value empty', () {
      final profile = MedicineOcrService.parsePackagingText(
        'Plain packaging text without a name or details',
      ).toProfile();

      expect(profile.medicineName, isEmpty);
      expect(profile.manufacturer, isEmpty);
      expect(profile.strength, isEmpty);
      expect(profile.dosageForm, isEmpty);
      expect(profile.batchNumber, isEmpty);
      expect(profile.manufacturingDate, isEmpty);
      expect(profile.expiryDate, isEmpty);
    });
  });
}
