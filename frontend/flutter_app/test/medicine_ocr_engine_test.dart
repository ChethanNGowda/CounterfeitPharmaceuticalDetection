import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/services/medicine_ocr_service.dart';
import 'package:pharma_assist/services/ocr_service.dart';

class _FixedOcrEngine implements BaseOcrEngine {
  final String text;

  const _FixedOcrEngine(this.text);

  @override
  Future<OcrTextBlock> extractText(File imageFile) async =>
      OcrTextBlock(text: text, lines: text.split('\n'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('medicine extraction uses the shared OCR engine contract', () async {
    final image = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}pharma-ocr-engine-test.jpg',
    );
    await image.writeAsBytes([1, 2, 3]);
    OcrService.setEngineForTesting(
      const _FixedOcrEngine(
        'Product Name: Cetirizine\nBatch No: CT-1204\nEXP: 08/2028',
      ),
    );
    try {
      final result = await MedicineOcrService.recognizeImage(image.path);
      expect(result.medicineName, 'Cetirizine');
      expect(result.batchNumber, 'CT-1204');
      expect(result.expiryDate, '08/2028');
    } finally {
      OcrService.resetEngine();
      if (await image.exists()) await image.delete();
    }
  });
}
