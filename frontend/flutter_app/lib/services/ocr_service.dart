import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Raw recognized text block with geometric and confidence details
class OcrTextBlock {
  final String text;
  final List<String> lines;

  const OcrTextBlock({required this.text, required this.lines});
}

/// Abstract contract for OCR engines
abstract class BaseOcrEngine {
  Future<OcrTextBlock> extractText(File imageFile);
}

/// Production on-device OCR engine using Google ML Kit Text Recognition
class MlKitOcrEngine implements BaseOcrEngine {
  @override
  Future<OcrTextBlock> extractText(File imageFile) async {
    final recognizedTexts = <String>[];
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      try {
        final recognizedText = await textRecognizer.processImage(inputImage);
        if (recognizedText.text.trim().isNotEmpty) {
          recognizedTexts.add(recognizedText.text.trim());
        }
      } finally {
        await textRecognizer.close();
      }

      if (Platform.isAndroid) {
        final devanagariRecognizer = TextRecognizer(
          script: TextRecognitionScript.devanagiri,
        );
        try {
          final recognizedText = await devanagariRecognizer.processImage(
            inputImage,
          );
          final text = recognizedText.text.trim();
          if (text.isNotEmpty &&
              !recognizedTexts.any(
                (existing) => existing.toLowerCase() == text.toLowerCase(),
              )) {
            recognizedTexts.add(text);
          }
        } on Exception {
          // The optional Devanagari model may be unavailable on this device.
        } finally {
          await devanagariRecognizer.close();
        }
      }

      final text = recognizedTexts.join('\n');
      final lines = text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      return OcrTextBlock(text: text, lines: lines);
    } catch (e) {
      debugPrint('MlKitOcrEngine error: $e');
      // Return empty block on engine error
      return const OcrTextBlock(text: '', lines: []);
    }
  }
}

/// Primary Optical Character Recognition Service providing on-device image text extraction
class OcrService {
  static BaseOcrEngine _engine = MlKitOcrEngine();

  /// Visible for testing: inject mock OCR engine
  @visibleForTesting
  static void setEngineForTesting(BaseOcrEngine engine) {
    _engine = engine;
  }

  /// Reset to standard production ML Kit engine
  @visibleForTesting
  static void resetEngine() {
    _engine = MlKitOcrEngine();
  }

  /// Extracts textual content directly from a packaging image file
  static Future<OcrTextBlock> extractTextFromImage(File imageFile) async {
    if (!imageFile.existsSync()) {
      return const OcrTextBlock(text: '', lines: []);
    }
    return await _engine.extractText(imageFile);
  }
}
