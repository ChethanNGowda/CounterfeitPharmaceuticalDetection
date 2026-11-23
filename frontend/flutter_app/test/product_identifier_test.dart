import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/models/product_identifier.dart';

void main() {
  test(
    'manual code is trimmed and timestamped without claiming verification',
    () {
      final timestamp = DateTime.utc(2026, 11, 20);
      final identifier = ProductIdentifier.tryCreate(
        '  8901234567890  ',
        capturedAt: timestamp,
      );

      expect(identifier, isNotNull);
      expect(identifier!.value, '8901234567890');
      expect(identifier.format, 'manual');
      expect(identifier.capturedAt, timestamp);
      expect(identifier.toJson()['value'], '8901234567890');
    },
  );

  test('rejects empty, oversized, and control-character payloads', () {
    expect(ProductIdentifier.tryCreate(' \n '), isNull);
    expect(ProductIdentifier.tryCreate(List.filled(2049, 'x').join()), isNull);
    expect(ProductIdentifier.tryCreate('ABC\u0000DEF'), isNull);
  });

  test('URL payload remains plain data and is never opened by the model', () {
    final identifier = ProductIdentifier.tryCreate(
      'https://example.invalid/product?id=ABC',
      format: 'qrCode',
    );

    expect(identifier?.value, 'https://example.invalid/product?id=ABC');
    expect(identifier?.format, 'qrCode');
  });

  test('parses a GS1 parenthesized element string', () {
    final identifier = ProductIdentifier.tryCreate(
      '(01)09506000134352(17)271231(10)LOT-ABC(21)SER-01',
      format: 'dataMatrix',
    )!;

    expect(identifier.parsedFields['gtin'], '09506000134352');
    expect(identifier.parsedFields['expiry_date'], '2027-12-31');
    expect(identifier.parsedFields['batch_number'], 'LOT-ABC');
    expect(identifier.parsedFields['serial_number'], 'SER-01');
    expect(identifier.parsedFields['gtin_check_digit_valid'], 'true');
    expect(
      identifier.value,
      '(01)09506000134352(17)271231(10)LOT-ABC(21)SER-01',
    );
  });

  test('parses separator-delimited GS1 content and end-of-month expiry', () {
    final identifier = ProductIdentifier.tryCreate(
      ']d201095060001343521726110010LOT-X\u001d21SER-Y',
      format: 'dataMatrix',
    )!;

    expect(identifier.parsedFields['gtin'], '09506000134352');
    expect(identifier.parsedFields['expiry_date'], '2026-11-30');
    expect(identifier.parsedFields['batch_number'], 'LOT-X');
    expect(identifier.parsedFields['serial_number'], 'SER-Y');
    expect(identifier.value, ']d201095060001343521726110010LOT-X\u001d21SER-Y');
  });

  test('retains malformed and unsupported GS1 values without guessing', () {
    final malformed = ProductIdentifier.tryCreate(
      '(01)123(17)321399(10)LOT-1(99)UNSUPPORTED',
    )!;
    expect(malformed.parsedFields.containsKey('gtin'), isFalse);
    expect(malformed.parsedFields.containsKey('expiry_date'), isFalse);
    expect(malformed.value, '(01)123(17)321399(10)LOT-1(99)UNSUPPORTED');
    expect(malformed.unparsedData, contains('(99)UNSUPPORTED'));
  });

  test('round trips recognized fields and preserved unknown content', () {
    final original =
        ProductIdentifier.tryCreate(
          '(01)09506000134352(10)LOT-9(99)OTHER',
          format: 'qrCode',
        )!.copyWith(
          parsedFields: {
            'gtin': '09506000134352',
            'batch_number': 'LOT-9-REVIEWED',
          },
          correctedFields: const {'batch_number'},
        );
    final restored = ProductIdentifier.fromJson(original.toJson());
    expect(restored.value, original.value);
    expect(restored.parsedFields, original.parsedFields);
    expect(restored.unparsedData, contains('(99)OTHER'));
    expect(restored.correctedFields, contains('batch_number'));
  });

  test('scanned payload is retained exactly including GS separator', () {
    final raw = '010950600013435210LOT\u001d21SER';
    final identifier = ProductIdentifier.tryCreate(raw, format: 'code128')!;
    expect(identifier.value, raw);
  });
}
