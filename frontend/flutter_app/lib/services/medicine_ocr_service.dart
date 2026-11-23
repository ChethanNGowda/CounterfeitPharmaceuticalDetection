import 'dart:io';

import 'package:pharma_assist/models/medicine_profile.dart';
import 'package:pharma_assist/models/medicine_package_image.dart';
import 'package:pharma_assist/services/ocr_service.dart';

/// Structured result of real text recognition and packaging-field extraction.
/// Confidence describes extraction completeness, not authenticity or a
/// calibrated OCR probability.
class OcrExtractionResult {
  final String medicineName;
  final String manufacturer;
  final String strength;
  final String dosageForm;
  final String batchNumber;
  final String manufacturingDate;
  final String expiryDate;
  final String mrp;
  final String rawText;
  final String confidence;
  final Map<String, bool> fieldConfidence;

  Map<String, String> get extractedFields => {
    MedicineOcrField.medicineName: medicineName,
    MedicineOcrField.manufacturer: manufacturer,
    MedicineOcrField.strength: strength,
    MedicineOcrField.dosageForm: dosageForm,
    MedicineOcrField.batchNumber: batchNumber,
    MedicineOcrField.manufacturingDate: manufacturingDate,
    MedicineOcrField.expiryDate: expiryDate,
    MedicineOcrField.mrp: mrp,
  }..removeWhere((_, value) => value.trim().isEmpty);

  MedicinePackageImage? toPackageImage({
    required String path,
    String label = 'Front of package',
    DateTime? capturedAt,
    String? id,
  }) {
    if (path.trim().isEmpty) return null;
    final now = capturedAt ?? DateTime.now();
    return MedicinePackageImage(
      id: id ?? 'IMG-${now.microsecondsSinceEpoch}',
      path: path,
      label: label,
      capturedAt: now,
      rawOcrText: rawText,
      extractedFields: extractedFields,
    );
  }

  const OcrExtractionResult({
    required this.medicineName,
    required this.manufacturer,
    required this.strength,
    required this.dosageForm,
    required this.batchNumber,
    required this.manufacturingDate,
    required this.expiryDate,
    required this.mrp,
    required this.rawText,
    required this.confidence,
    required this.fieldConfidence,
  });

  MedicineProfile toProfile({String? id, String? imagePath, String? notes}) {
    final packageImage = imagePath == null
        ? null
        : toPackageImage(path: imagePath);
    return MedicineProfile(
      id: id ?? 'MED-${DateTime.now().millisecondsSinceEpoch}',
      medicineName: medicineName.trim(),
      manufacturer: manufacturer,
      strength: strength,
      dosageForm: dosageForm.trim(),
      batchNumber: batchNumber,
      manufacturingDate: manufacturingDate,
      expiryDate: expiryDate,
      mrp: mrp,
      rawOcrText: rawText,
      confidence: confidence,
      isVerifiedByUser: false,
      packagingImagePath: imagePath,
      packagingImages: packageImage == null ? const [] : [packageImage],
      notes: notes,
      createdAt: DateTime.now(),
    );
  }
}

class MedicineOcrFieldObservation {
  final String value;
  final String imageLabel;

  const MedicineOcrFieldObservation({
    required this.value,
    required this.imageLabel,
  });
}

/// Converts text recognized by the shared on-device OCR engine into fields.
class MedicineOcrService {
  static final RegExp _dateRegex = RegExp(
    r'\b(?:\d{1,2}[/. -]\d{1,2}[/. -]\d{4}|\d{4}[/. -]\d{1,2}(?:[/. -]\d{1,2})?|\d{1,2}[./-]\d{2,4}|[A-Za-z]{3,9}\s+\d{4})\b',
  );
  static final RegExp _strengthRegex = RegExp(
    r'\b\d+(?:\.\d+)?\s*(?:mcg|μg|µg|ug|mg|kg|g|ml|mL|IU|units?|mmol|%)(?:\s*/\s*\d+(?:\.\d+)?\s*(?:ml|mL|g|mg))?\b',
    caseSensitive: false,
  );
  static final RegExp _dosageFormRegex = RegExp(
    r'\b(?:tablets?|capsules?|syrups?|injections?|suspensions?|ointments?|creams?|gels?|solutions?|drops?|inhalers?|caplets?|granules?|powders?|sachets?|sprays?|lozenges?|suppositories?)\b',
    caseSensitive: false,
  );

  /// Returns only fields where at least two package views produced different
  /// non-empty OCR strings. The function never chooses or overwrites a value.
  static Map<String, List<MedicineOcrFieldObservation>> findConflictingFields(
    Iterable<MedicinePackageImage> images,
  ) {
    final valuesByField = <String, Map<String, MedicineOcrFieldObservation>>{};
    for (final image in images) {
      for (final entry in image.extractedFields.entries) {
        final value = entry.value.trim();
        if (value.isEmpty) continue;
        valuesByField
            .putIfAbsent(entry.key, () => {})
            .putIfAbsent(
              value.toLowerCase(),
              () => MedicineOcrFieldObservation(
                value: value,
                imageLabel: image.label,
              ),
            );
      }
    }
    return {
      for (final entry in valuesByField.entries)
        if (entry.value.length > 1)
          entry.key: entry.value.values.toList(growable: false),
    };
  }

  static final RegExp _otherPackagingFieldLabel = RegExp(
    r'^\s*(?:exp(?:iry)?|use\s*before|best\s*before|valid\s*(?:upto|up\s*to)|mfg|mfd|manufacturing(?:\s*date)?|manufactured\s*by|marketed\s*by|mrp|strength|dosage\s*form|manufacturer)\b(?:\s*(?:date|dt|no|number))?\s*(?:[:#=\-]|$)',
    caseSensitive: false,
  );

  /// Reads the selected image itself. No values are generated from filenames.
  static Future<OcrExtractionResult> recognizeImage(String imagePath) async {
    final block = await OcrService.extractTextFromImage(File(imagePath));
    return parsePackagingText(block.text);
  }

  /// Parses OCR text into editable fields. Missing values remain blank;
  /// batch numbers, dates, and strengths are never fabricated.
  static OcrExtractionResult parsePackagingText(String text) {
    final normalizedText = text.replaceAll('\r', '\n').trim();
    final lines = normalizedText
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    const emptyFields = {
      'name': false,
      'strength': false,
      'dosage': false,
      'batch': false,
      'expiry': false,
      'mfgDate': false,
      'manufacturer': false,
      'mrp': false,
    };
    if (lines.isEmpty) {
      return const OcrExtractionResult(
        medicineName: '',
        manufacturer: '',
        strength: '',
        dosageForm: '',
        batchNumber: '',
        manufacturingDate: '',
        expiryDate: '',
        mrp: '',
        rawText: '',
        confidence: 'UNCERTAIN',
        fieldConfidence: emptyFields,
      );
    }

    final expiry = _extractLabelledDate(
      lines,
      RegExp(
        r'\b(?:exp(?:iry)?\.?\s*(?:date|dt)?|use\s*before|best\s*before|valid\s*(?:upto|up\s*to))\b',
        caseSensitive: false,
      ),
    );
    final manufacturing = _extractLabelledDate(
      lines,
      RegExp(
        r'\b(?:mfg\.?\s*(?:date|dt)?|mfd\.?\s*(?:date|dt)?|manufacturing\s*(?:date)?|manufactured\s*(?:date)?)\b',
        caseSensitive: false,
      ),
    );
    final batch = _extractLabelledValue(
      lines,
      RegExp(
        r'\b(?:batch(?:\s*(?:no|number))?|b\.?\s*no\.?|lot(?:\s*(?:no|number))?|b/n)\b',
        caseSensitive: false,
      ),
      RegExp(r'([A-Z0-9][A-Z0-9./_-]{1,})', caseSensitive: false),
      requireDigit: true,
    );

    final mrp = _extractLabelledValue(
      lines,
      RegExp(
        r'\b(?:m\.?\s*r\.?\s*p\.?|maximum\s*retail\s*price)\b',
        caseSensitive: false,
      ),
      RegExp(r'([0-9]+(?:[.,][0-9]{1,2})?)'),
    );

    String strength = '';
    for (final line in lines) {
      final match = _strengthRegex.firstMatch(line);
      if (match != null) {
        strength = match.group(0)?.trim() ?? '';
        if (strength.isNotEmpty) break;
      }
    }

    String dosage = '';
    for (final line in lines) {
      final match = _dosageFormRegex.firstMatch(line);
      if (match != null) {
        dosage = match.group(0) ?? '';
        if (dosage.isNotEmpty) break;
      }
    }

    final manufacturer = _extractManufacturer(lines);
    final medicineName = _extractMedicineName(
      lines,
      strength: strength,
      dosage: dosage,
      manufacturer: manufacturer,
    );

    final fields = <String, bool>{
      'name': medicineName.isNotEmpty,
      'strength': strength.isNotEmpty,
      'dosage': dosage.isNotEmpty,
      'batch': batch.isNotEmpty,
      'expiry': expiry.isNotEmpty,
      'mfgDate': manufacturing.isNotEmpty,
      'manufacturer': manufacturer.isNotEmpty,
      'mrp': mrp.isNotEmpty,
    };
    final matched = fields.values.where((value) => value).length;
    final confidence = matched >= 5
        ? 'HIGH'
        : matched >= 3
        ? 'MEDIUM'
        : 'UNCERTAIN';

    return OcrExtractionResult(
      medicineName: medicineName,
      manufacturer: manufacturer,
      strength: strength,
      dosageForm: dosage,
      batchNumber: batch,
      manufacturingDate: manufacturing,
      expiryDate: expiry,
      mrp: mrp,
      rawText: normalizedText,
      confidence: confidence,
      fieldConfidence: fields,
    );
  }

  static String _extractLabelledDate(List<String> lines, RegExp label) {
    final anotherDateLabel = RegExp(
      r'\b(?:exp(?:iry)?\.?|use\s*before|best\s*before|valid\s*(?:upto|up\s*to)|mfg\.?|mfd\.?|manufacturing|manufactured)\b',
      caseSensitive: false,
    );
    final expiryDate =
        label.pattern.toLowerCase().contains('exp') ||
        label.pattern.toLowerCase().contains('before') ||
        label.pattern.toLowerCase().contains('valid');
    for (var index = 0; index < lines.length; index++) {
      final match = label.firstMatch(lines[index]);
      if (match == null) continue;
      final remainder = lines[index]
          .substring(match.end)
          .replaceFirst(RegExp(r'^\s*[:#=\-]?\s*'), '');
      final inlineDate = _dateRegex.firstMatch(remainder);
      if (inlineDate != null) {
        return _validatedDate(inlineDate.group(0)!.trim(), expiryDate);
      }
      if (index + 1 < lines.length &&
          !anotherDateLabel.hasMatch(lines[index + 1])) {
        final nextDate = _dateRegex.firstMatch(lines[index + 1]);
        if (nextDate != null) {
          return _validatedDate(nextDate.group(0)!.trim(), expiryDate);
        }
      }
    }
    return '';
  }

  static String _validatedDate(String value, bool expiryDate) {
    return MedicineProfile.parseDateValue(value, expiryDate: expiryDate) == null
        ? ''
        : value;
  }

  static String _extractLabelledValue(
    List<String> lines,
    RegExp label,
    RegExp valuePattern, {
    bool requireDigit = false,
  }) {
    String validatedValue(RegExpMatch match) {
      final value = match.group(1)!.trim();
      return requireDigit && !RegExp(r'\d').hasMatch(value) ? '' : value;
    }

    for (var index = 0; index < lines.length; index++) {
      final match = label.firstMatch(lines[index]);
      if (match == null) continue;
      final remainder = lines[index]
          .substring(match.end)
          .replaceFirst(RegExp(r'^\s*[:#=\-]?\s*'), '');
      if (_otherPackagingFieldLabel.hasMatch(remainder)) return '';
      final inlineValue = valuePattern.firstMatch(remainder);
      if (inlineValue != null) return validatedValue(inlineValue);
      if (index + 1 < lines.length &&
          !_otherPackagingFieldLabel.hasMatch(lines[index + 1])) {
        final nextValue = valuePattern.firstMatch(lines[index + 1]);
        if (nextValue != null) return validatedValue(nextValue);
      }
    }
    return '';
  }

  static String _extractManufacturer(List<String> lines) {
    final labelled = RegExp(
      r'\b(?:mfd\.?\s*by|manufactured\s*by|marketed\s*by|manufacturers?\s*[:\-])\s*[:\-]?\s*(.+)',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = labelled.firstMatch(line);
      if (match != null) {
        return match.group(1)!.trim().replaceAll(RegExp(r'[;,]+$'), '');
      }
    }
    final companyLine = RegExp(
      r'\b(?:pharma(?:ceuticals?)?|laborator(?:y|ies)|healthcare|biotech|pvt\.?\s*ltd|limited|ltd\.?|inc\.?)\b',
      caseSensitive: false,
    );
    for (final line in lines) {
      if (companyLine.hasMatch(line) && line.length <= 90) return line;
    }
    return '';
  }

  static String _extractMedicineName(
    List<String> lines, {
    required String strength,
    required String dosage,
    required String manufacturer,
  }) {
    final explicitName = RegExp(
      r'^\s*(?:(?:medicine|product|brand|trade)\s+)?name\s*[:#=\-]\s*(.+)$',
      caseSensitive: false,
    );
    final labelledCandidates = <String>[];
    for (final line in lines) {
      final match = explicitName.firstMatch(line);
      if (match != null) labelledCandidates.add(match.group(1)!.trim());
    }
    final excluded = RegExp(
      r'\b(?:rx|medicine|pharmaceutical|batch|lot|exp(?:iry)?|mfg|mfd|manufactur|marketed|store|storage|keep out|prescription|composition|warning|caution|schedule|mrp|price|tablet|capsule|syrup|injection|suspension|ointment|cream|gel|solution|drops|inhaler|dosage|each film coated|with|without|and|or|is|are|this|that|text|detail|information|contains)\b',
      caseSensitive: false,
    );
    for (final original in [...labelledCandidates, ...lines.take(10)]) {
      var candidate = original.replaceFirst(
        RegExp(r'^\s*rx\b[\s:.-]*', caseSensitive: false),
        '',
      );
      if (strength.isNotEmpty) {
        candidate = candidate.replaceAll(
          RegExp(RegExp.escape(strength), caseSensitive: false),
          '',
        );
      }
      if (dosage.isNotEmpty) {
        candidate = candidate.replaceAll(
          RegExp(RegExp.escape(dosage), caseSensitive: false),
          '',
        );
      }
      candidate = candidate
          .replaceAll(RegExp(r'^[\s:|\-\u2022]+|[\s:|\-\u2022]+$'), '')
          .trim();
      if (candidate.length < 3 ||
          candidate.length > 60 ||
          excluded.hasMatch(candidate) ||
          candidate.toLowerCase() == manufacturer.toLowerCase() ||
          !RegExp(r'[A-Za-z\u0900-\u097F]{3}').hasMatch(candidate)) {
        continue;
      }
      final letters = RegExp(r'[A-Za-z\u0900-\u097F]')
          .allMatches(candidate)
          .length;
      final digits = RegExp(r'\d').allMatches(candidate).length;
      if (letters < 3 || digits > letters) continue;
      return candidate;
    }
    return '';
  }
}
