import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/services/medicine_ocr_service.dart';

void main() {
  group('MedicineOcrService real-text extraction', () {
    test('extracts labelled pharmaceutical fields without fabricated values', () {
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
    });

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
  });
}
