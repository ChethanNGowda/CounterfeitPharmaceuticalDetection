import 'package:pharma_assist/models/medicine_profile.dart';

/// Structured result of pharmaceutical packaging OCR parsing
class OcrExtractionResult {
  final String medicineName;
  final String manufacturer;
  final String strength;
  final String dosageForm;
  final String batchNumber;
  final String manufacturingDate;
  final String expiryDate;
  final String rawText;
  final String confidence; // 'HIGH', 'MEDIUM', 'UNCERTAIN'
  final Map<String, bool>
  fieldConfidence; // true if field matched strong pattern

  const OcrExtractionResult({
    required this.medicineName,
    required this.manufacturer,
    required this.strength,
    required this.dosageForm,
    required this.batchNumber,
    required this.manufacturingDate,
    required this.expiryDate,
    required this.rawText,
    required this.confidence,
    required this.fieldConfidence,
  });

  MedicineProfile toProfile({String? id, String? imagePath, String? notes}) {
    return MedicineProfile(
      id: id ?? 'MED-${DateTime.now().millisecondsSinceEpoch}',
      medicineName: medicineName.isNotEmpty ? medicineName : 'Unlabeled Sample',
      manufacturer: manufacturer,
      strength: strength,
      dosageForm: dosageForm,
      batchNumber: batchNumber,
      manufacturingDate: manufacturingDate,
      expiryDate: expiryDate,
      rawOcrText: rawText,
      confidence: confidence,
      isVerifiedByUser: false,
      packagingImagePath: imagePath,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }
}

/// Specialized Optical Character & Pattern Recognition Service for Medicine Packaging
class MedicineOcrService {
  // Regex patterns for pharmaceutical packaging entities
  static final RegExp _strengthRegex = RegExp(
    r'\b(\d+(?:\.\d+)?\s*(?:mg|g|mcg|ml|iu|%|w\/v|w\/w))\b',
    caseSensitive: false,
  );

  static final RegExp _batchRegex = RegExp(
    r'(?:B\.?\s*No\.?|Batch(?:\s*No\.?)?|Lot(?:\s*No\.?)?|LOT|BATCH|B\/N)[\s:]*([A-Za-z0-9\-]+)',
    caseSensitive: false,
  );

  static final RegExp _expiryRegex = RegExp(
    r'(?:Exp\.?\s*Date|EXPIRY|EXP|Expiry(?:\s*Date)?|Best\s*Before|Use\s*Before|BB)[\s:]*([0-9]{1,2}[\/\-\.][0-9]{2,4}|[A-Za-z]{3,9}[\s\.\-\/]*[0-9]{2,4}|[0-9]{4}[\/\-\.][0-9]{1,2})',
    caseSensitive: false,
  );

  static final RegExp _mfgRegex = RegExp(
    r'(?:Mfg\.?\s*Date|MFD|MFG|Manufactured(?:\s*Date)?|Mfd)[\s:]*([0-9]{1,2}[\/\-\.][0-9]{2,4}|[A-Za-z]{3,9}[\s\.\-\/]*[0-9]{2,4}|[0-9]{4}[\/\-\.][0-9]{1,2})',
    caseSensitive: false,
  );

  static final RegExp _dosageFormRegex = RegExp(
    r'\b(Tablets?|Capsules?|Syrup|Injection|Suspension|Ointment|Cream|Gel|Solution|Drops?|Inhaler|Caplets?|Oral\s*Solution)\b',
    caseSensitive: false,
  );

  static final RegExp _mfgNameRegex = RegExp(
    r'(?:Mfd\.?\s*by|Manufactured\s*by|Marketed\s*by|Mfg\s*by|Pharma|Laboratories|Lab|Ltd\.?|Pvt\.?|Inc\.?)[\s:]*([A-Za-z0-9\s,\.\&]+)',
    caseSensitive: false,
  );

  /// Parse text extracted from packaging image into structured fields
  static OcrExtractionResult parsePackagingText(String text) {
    if (text.trim().isEmpty) {
      return const OcrExtractionResult(
        medicineName: '',
        manufacturer: '',
        strength: '',
        dosageForm: 'Tablet',
        batchNumber: '',
        manufacturingDate: '',
        expiryDate: '',
        rawText: '',
        confidence: 'UNCERTAIN',
        fieldConfidence: {},
      );
    }

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String detectedStrength = '';
    String detectedBatch = '';
    String detectedExpiry = '';
    String detectedMfgDate = '';
    String detectedDosage = 'Tablet';
    String detectedManufacturer = '';
    String detectedName = '';

    final Map<String, bool> fieldConfidence = {
      'name': false,
      'strength': false,
      'dosage': false,
      'batch': false,
      'expiry': false,
      'mfgDate': false,
      'manufacturer': false,
    };

    // 1. Search batch number
    final batchMatch = _batchRegex.firstMatch(text);
    if (batchMatch != null && batchMatch.groupCount >= 1) {
      detectedBatch = batchMatch.group(1)?.trim() ?? '';
      fieldConfidence['batch'] = detectedBatch.isNotEmpty;
    }

    // 2. Search expiry date
    final expiryMatch = _expiryRegex.firstMatch(text);
    if (expiryMatch != null && expiryMatch.groupCount >= 1) {
      detectedExpiry = expiryMatch.group(1)?.trim() ?? '';
      fieldConfidence['expiry'] = detectedExpiry.isNotEmpty;
    }

    // 3. Search manufacturing date
    final mfgMatch = _mfgRegex.firstMatch(text);
    if (mfgMatch != null && mfgMatch.groupCount >= 1) {
      detectedMfgDate = mfgMatch.group(1)?.trim() ?? '';
      fieldConfidence['mfgDate'] = detectedMfgDate.isNotEmpty;
    }

    // 4. Search strength
    final strengthMatch = _strengthRegex.firstMatch(text);
    if (strengthMatch != null && strengthMatch.groupCount >= 1) {
      detectedStrength = strengthMatch.group(1)?.trim() ?? '';
      fieldConfidence['strength'] = detectedStrength.isNotEmpty;
    }

    // 5. Search dosage form
    final dosageMatch = _dosageFormRegex.firstMatch(text);
    if (dosageMatch != null && dosageMatch.groupCount >= 1) {
      detectedDosage = dosageMatch.group(1)?.trim() ?? 'Tablet';
      fieldConfidence['dosage'] = true;
    }

    // 6. Search manufacturer
    final mfgNameMatch = _mfgNameRegex.firstMatch(text);
    if (mfgNameMatch != null && mfgNameMatch.groupCount >= 1) {
      final rawMfg = mfgNameMatch.group(1)?.trim() ?? '';
      detectedManufacturer = rawMfg.split(RegExp(r'[\r\n,]')).first.trim();
      fieldConfidence['manufacturer'] = detectedManufacturer.isNotEmpty;
    }

    // 7. Heuristic for Medicine Name:
    // Generally the largest/first prominent line that doesn't match batch/expiry/mfg keywords
    for (final line in lines) {
      if (line.length < 3) continue;
      final lower = line.toLowerCase();
      final isKeyword =
          lower.contains('batch') ||
          lower.contains('exp') ||
          lower.contains('mfg') ||
          lower.contains('mfd') ||
          lower.contains('tablets') ||
          lower.contains('capsules') ||
          lower.contains('manufactured') ||
          lower.contains('keep out of reach') ||
          lower.contains('store in');
      if (!isKeyword && detectedName.isEmpty) {
        // Strip trailing punctuation
        detectedName = line.replaceAll(
          RegExp(r'^[^\w]+|[^\w\s\-\.\(\)]+$'),
          '',
        );
        fieldConfidence['name'] = detectedName.isNotEmpty;
        break;
      }
    }

    // Calculate overall extraction confidence
    final confidentCount = fieldConfidence.values.where((v) => v).length;
    String overallConfidence = 'UNCERTAIN';
    if (confidentCount >= 4) {
      overallConfidence = 'HIGH';
    } else if (confidentCount >= 2) {
      overallConfidence = 'MEDIUM';
    }

    return OcrExtractionResult(
      medicineName: detectedName,
      manufacturer: detectedManufacturer,
      strength: detectedStrength,
      dosageForm: detectedDosage,
      batchNumber: detectedBatch,
      manufacturingDate: detectedMfgDate,
      expiryDate: detectedExpiry,
      rawText: text,
      confidence: overallConfidence,
      fieldConfidence: fieldConfidence,
    );
  }
}
