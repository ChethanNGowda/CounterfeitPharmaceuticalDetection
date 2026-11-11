import 'package:intl/intl.dart';

/// Local Medicine Profile representing an inspected or registered pharmaceutical product.
class MedicineProfile {
  final String id;
  final String medicineName;
  final String manufacturer;
  final String strength;
  final String dosageForm;
  final String batchNumber;
  final String manufacturingDate;
  final String expiryDate;
  final String rawOcrText;
  final String confidence; // 'HIGH', 'MEDIUM', 'UNCERTAIN'
  final bool isVerifiedByUser;
  final String? packagingImagePath;
  final String? notes;
  final DateTime createdAt;

  const MedicineProfile({
    required this.id,
    required this.medicineName,
    this.manufacturer = '',
    this.strength = '',
    this.dosageForm = 'Tablet',
    this.batchNumber = '',
    this.manufacturingDate = '',
    this.expiryDate = '',
    this.rawOcrText = '',
    this.confidence = 'UNCERTAIN',
    this.isVerifiedByUser = false,
    this.packagingImagePath,
    this.notes,
    required this.createdAt,
  });

  /// Parse expiry date safely
  DateTime? get parsedExpiryDate {
    if (expiryDate.trim().isEmpty) return null;
    final clean = expiryDate.trim();
    // Try standard formats: yyyy-MM-dd, MM/yyyy, dd/MM/yyyy, MM/yy
    final formats = [
      'yyyy-MM-dd',
      'dd-MM-yyyy',
      'MM/yyyy',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'MMM yyyy',
      'MM-yyyy',
      'yyyy/MM',
    ];
    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parseLoose(clean);
      } catch (_) {}
    }
    return null;
  }

  /// Whether the medicine is past its expiry date
  bool get isExpired {
    final exp = parsedExpiryDate;
    if (exp == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return exp.isBefore(today);
  }

  /// Whether the medicine will expire within [daysThreshold] days (default 60 days)
  bool isNearExpiry([int daysThreshold = 60]) {
    final exp = parsedExpiryDate;
    if (exp == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (exp.isBefore(today)) return false; // already expired
    final diff = exp.difference(today).inDays;
    return diff <= daysThreshold;
  }

  /// Days until expiry (negative if expired, null if unknown)
  int? get daysUntilExpiry {
    final exp = parsedExpiryDate;
    if (exp == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return exp.difference(today).inDays;
  }

  MedicineProfile copyWith({
    String? id,
    String? medicineName,
    String? manufacturer,
    String? strength,
    String? dosageForm,
    String? batchNumber,
    String? manufacturingDate,
    String? expiryDate,
    String? rawOcrText,
    String? confidence,
    bool? isVerifiedByUser,
    String? packagingImagePath,
    String? notes,
    DateTime? createdAt,
  }) {
    return MedicineProfile(
      id: id ?? this.id,
      medicineName: medicineName ?? this.medicineName,
      manufacturer: manufacturer ?? this.manufacturer,
      strength: strength ?? this.strength,
      dosageForm: dosageForm ?? this.dosageForm,
      batchNumber: batchNumber ?? this.batchNumber,
      manufacturingDate: manufacturingDate ?? this.manufacturingDate,
      expiryDate: expiryDate ?? this.expiryDate,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      confidence: confidence ?? this.confidence,
      isVerifiedByUser: isVerifiedByUser ?? this.isVerifiedByUser,
      packagingImagePath: packagingImagePath ?? this.packagingImagePath,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicine_name': medicineName,
      'manufacturer': manufacturer,
      'strength': strength,
      'dosage_form': dosageForm,
      'batch_number': batchNumber,
      'manufacturing_date': manufacturingDate,
      'expiry_date': expiryDate,
      'raw_ocr_text': rawOcrText,
      'confidence': confidence,
      'is_verified_by_user': isVerifiedByUser,
      'packaging_image_path': packagingImagePath,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MedicineProfile.fromJson(Map<String, dynamic> json) {
    return MedicineProfile(
      id:
          json['id'] as String? ??
          'MED-${DateTime.now().millisecondsSinceEpoch}',
      medicineName: json['medicine_name'] as String? ?? 'Unknown Medicine',
      manufacturer: json['manufacturer'] as String? ?? '',
      strength: json['strength'] as String? ?? '',
      dosageForm: json['dosage_form'] as String? ?? 'Tablet',
      batchNumber: json['batch_number'] as String? ?? '',
      manufacturingDate: json['manufacturing_date'] as String? ?? '',
      expiryDate: json['expiry_date'] as String? ?? '',
      rawOcrText: json['raw_ocr_text'] as String? ?? '',
      confidence: json['confidence'] as String? ?? 'UNCERTAIN',
      isVerifiedByUser: json['is_verified_by_user'] as bool? ?? false,
      packagingImagePath: json['packaging_image_path'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
