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
}
