/// Batch-specific printed details for a medicine profile.
class MedicineBatchRecord {
  final String id;
  final String batchNumber;
  final String manufacturingDate;
  final String expiryDate;
  final String mrp;
  final DateTime recordedAt;
  final String sourceType;

  const MedicineBatchRecord({
    required this.id,
    required this.batchNumber,
    this.manufacturingDate = '',
    this.expiryDate = '',
    this.mrp = '',
    required this.recordedAt,
    this.sourceType = 'manual',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'batch_number': batchNumber,
    'manufacturing_date': manufacturingDate,
    'expiry_date': expiryDate,
    'mrp': mrp,
    'recorded_at': recordedAt.toIso8601String(),
    'source_type': sourceType,
  };

  factory MedicineBatchRecord.fromJson(Map<String, dynamic> json) =>
      MedicineBatchRecord(
        id: json['id']?.toString() ?? '',
        batchNumber: json['batch_number']?.toString() ?? '',
        manufacturingDate: json['manufacturing_date']?.toString() ?? '',
        expiryDate: json['expiry_date']?.toString() ?? '',
        mrp: json['mrp']?.toString() ?? '',
        recordedAt:
            DateTime.tryParse(json['recorded_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        sourceType: json['source_type']?.toString() ?? 'manual',
      );
}

/// Local audit entry explaining where a saved field value came from.
/// Confidence is nullable and remains absent when the OCR engine supplies none.
class MedicineFieldAuditEntry {
  final String id;
  final String fieldKey;
  final String originalValue;
  final String savedValue;
  final String? previousValue;
  final String sourceType;
  final String? sourceId;
  final double? confidence;
  final bool userCorrected;
  final bool userReviewed;
  final DateTime changedAt;
  final String? correctionReason;

  const MedicineFieldAuditEntry({
    required this.id,
    required this.fieldKey,
    required this.originalValue,
    required this.savedValue,
    this.previousValue,
    required this.sourceType,
    this.sourceId,
    this.confidence,
    required this.userCorrected,
    required this.userReviewed,
    required this.changedAt,
    this.correctionReason,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'field_key': fieldKey,
    'original_value': originalValue,
    'saved_value': savedValue,
    'previous_value': previousValue,
    'source_type': sourceType,
    'source_id': sourceId,
    'confidence': confidence,
    'user_corrected': userCorrected,
    'user_reviewed': userReviewed,
    'changed_at': changedAt.toIso8601String(),
    'correction_reason': correctionReason,
  };

  factory MedicineFieldAuditEntry.fromJson(Map<String, dynamic> json) =>
      MedicineFieldAuditEntry(
        id: json['id']?.toString() ?? '',
        fieldKey: json['field_key']?.toString() ?? '',
        originalValue: json['original_value']?.toString() ?? '',
        savedValue: json['saved_value']?.toString() ?? '',
        previousValue: json['previous_value']?.toString(),
        sourceType: json['source_type']?.toString() ?? 'unknown',
        sourceId: json['source_id']?.toString(),
        confidence: (json['confidence'] as num?)?.toDouble(),
        userCorrected: json['user_corrected'] == true,
        userReviewed: json['user_reviewed'] == true,
        changedAt:
            DateTime.tryParse(json['changed_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        correctionReason: json['correction_reason']?.toString(),
      );
}
