/// A locally stored photograph and the OCR evidence extracted from that view.
/// OCR values are observations for user review, not verified product facts.
class MedicinePackageImage {
  final String id;
  final String path;
  final String label;
  final DateTime capturedAt;
  final String rawOcrText;
  final Map<String, String> extractedFields;

  const MedicinePackageImage({
    required this.id,
    required this.path,
    required this.label,
    required this.capturedAt,
    this.rawOcrText = '',
    this.extractedFields = const {},
  });

  MedicinePackageImage copyWith({
    String? id,
    String? path,
    String? label,
    DateTime? capturedAt,
    String? rawOcrText,
    Map<String, String>? extractedFields,
  }) => MedicinePackageImage(
    id: id ?? this.id,
    path: path ?? this.path,
    label: label ?? this.label,
    capturedAt: capturedAt ?? this.capturedAt,
    rawOcrText: rawOcrText ?? this.rawOcrText,
    extractedFields: extractedFields ?? this.extractedFields,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'label': label,
    'captured_at': capturedAt.toIso8601String(),
    'raw_ocr_text': rawOcrText,
    'extracted_fields': extractedFields,
  };

  factory MedicinePackageImage.fromJson(Map<String, dynamic> json) {
    final dynamic rawFields = json['extracted_fields'];
    return MedicinePackageImage(
      id: json['id'] as String? ?? '',
      path: json['path'] as String? ?? '',
      label: json['label'] as String? ?? 'Package photo',
      capturedAt:
          DateTime.tryParse(json['captured_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      rawOcrText: json['raw_ocr_text'] as String? ?? '',
      extractedFields: rawFields is Map
          ? rawFields.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
    );
  }
}

/// Field names are stable keys so saved OCR evidence survives UI wording changes.
abstract final class MedicineOcrField {
  static const medicineName = 'medicine_name';
  static const manufacturer = 'manufacturer';
  static const strength = 'strength';
  static const dosageForm = 'dosage_form';
  static const batchNumber = 'batch_number';
  static const manufacturingDate = 'manufacturing_date';
  static const expiryDate = 'expiry_date';
  static const mrp = 'mrp';

  static const labels = <String, String>{
    medicineName: 'Medicine name',
    manufacturer: 'Manufacturer',
    strength: 'Strength',
    dosageForm: 'Dosage form',
    batchNumber: 'Batch number',
    manufacturingDate: 'Manufacturing date',
    expiryDate: 'Expiry date',
    mrp: 'MRP',
  };
}
