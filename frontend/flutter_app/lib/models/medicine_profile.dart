import 'medicine_package_image.dart';
import 'medicine_verification_record.dart';

enum MedicineExpiryStatus { expired, expiringSoon, valid, unknown }

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
  final String mrp;
  final String rawOcrText;
  final String confidence; // 'HIGH', 'MEDIUM', 'UNCERTAIN'
  final bool isVerifiedByUser;
  final String? packagingImagePath;
  final List<MedicinePackageImage> packagingImages;
  final String productIdentifier;
  final String productIdentifierFormat;
  final DateTime? productIdentifierScannedAt;
  final List<MedicineVerificationRecord> verificationHistory;
  final String? notes;
  final DateTime createdAt;

  const MedicineProfile({
    required this.id,
    required this.medicineName,
    this.manufacturer = '',
    this.strength = '',
    this.dosageForm = '',
    this.batchNumber = '',
    this.manufacturingDate = '',
    this.expiryDate = '',
    this.mrp = '',
    this.rawOcrText = '',
    this.confidence = 'UNCERTAIN',
    this.isVerifiedByUser = false,
    this.packagingImagePath,
    this.packagingImages = const [],
    this.productIdentifier = '',
    this.productIdentifierFormat = '',
    this.productIdentifierScannedAt,
    this.verificationHistory = const [],
    this.notes,
    required this.createdAt,
  });

  /// Parses explicit dates strictly. A month/year expiry is valid through the
  /// final calendar day of that month; manufacturing dates use its first day.
  /// Ambiguous slash dates and impossible calendar dates stay unknown.
  static DateTime? parseDateValue(String value, {bool expiryDate = false}) {
    final clean = value.trim();
    if (clean.isEmpty) return null;

    final shortMonthYear = RegExp(r'^(\d{1,2})[./-](\d{2})$').firstMatch(clean);
    if (shortMonthYear != null) {
      final month = int.parse(shortMonthYear.group(1)!);
      final shortYear = int.parse(shortMonthYear.group(2)!);
      if (month < 1 || month > 12) return null;
      // Keep the legacy MM/YY format deterministic: 00-79 => 2000-2079,
      // 80-99 => 1980-1999.
      final year = shortYear < 80 ? 2000 + shortYear : 1900 + shortYear;
      return expiryDate
          ? DateTime(year, month + 1, 0)
          : DateTime(year, month, 1);
    }

    final monthYear = RegExp(r'^(\d{1,2})[./-](\d{4})$').firstMatch(clean);
    if (monthYear != null) {
      final month = int.parse(monthYear.group(1)!);
      final year = int.parse(monthYear.group(2)!);
      if (month < 1 || month > 12 || year < 1) return null;
      return expiryDate
          ? DateTime(year, month + 1, 0)
          : DateTime(year, month, 1);
    }

    final yearMonth = RegExp(r'^(\d{4})[./-](\d{1,2})$').firstMatch(clean);
    if (yearMonth != null) {
      final year = int.parse(yearMonth.group(1)!);
      final month = int.parse(yearMonth.group(2)!);
      if (month < 1 || month > 12 || year < 1) return null;
      return expiryDate
          ? DateTime(year, month + 1, 0)
          : DateTime(year, month, 1);
    }

    final numericDate = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$')
        .firstMatch(clean);
    if (numericDate != null) {
      final first = int.parse(numericDate.group(1)!);
      final second = int.parse(numericDate.group(2)!);
      final year = int.parse(numericDate.group(3)!);
      // Slash/dash dates are day-first unless the second field proves the
      // input is an unambiguous legacy month/day date.
      final day = second > 12 && first <= 12 ? second : first;
      final month = second > 12 && first <= 12 ? first : second;
      if ((first <= 12 && second <= 12) || year < 1) return null;
      final parsed = DateTime(year, month, day);
      if (parsed.year != year || parsed.month != month || parsed.day != day) {
        return null;
      }
      return parsed;
    }

    final isoDate = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$')
        .firstMatch(clean);
    if (isoDate != null) {
      return _calendarDate(
        int.parse(isoDate.group(1)!),
        int.parse(isoDate.group(2)!),
        int.parse(isoDate.group(3)!),
      );
    }

    final namedMonth = RegExp(r'^([A-Za-z]{3,9})\s+(\d{4})$').firstMatch(clean);
    if (namedMonth != null) {
      const months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final month = months[namedMonth.group(1)!.substring(0, 3).toLowerCase()];
      final year = int.parse(namedMonth.group(2)!);
      if (month == null) return null;
      return expiryDate
          ? DateTime(year, month + 1, 0)
          : DateTime(year, month, 1);
    }
    return null;
  }

  static DateTime? _calendarDate(int year, int month, int day) {
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }
    return value;
  }

  /// Returns the effective expiry date. Month-only dates expire at month end.
  DateTime? get parsedExpiryDate {
    return parseDateValue(expiryDate, expiryDate: true);
  }

  /// Includes older records that only stored `packaging_image_path`.
  List<MedicinePackageImage> get packageImageRecords {
    if (packagingImages.isNotEmpty) return packagingImages;
    final legacyPath = packagingImagePath;
    if (legacyPath == null || legacyPath.isEmpty) return const [];
    return [
      MedicinePackageImage(
        id: 'legacy-$id',
        path: legacyPath,
        label: 'Package photo',
        capturedAt: createdAt,
        rawOcrText: rawOcrText,
      ),
    ];
  }

  MedicineExpiryStatus expiryStatus({
    DateTime? referenceDate,
    int daysThreshold = 60,
  }) {
    final expiry = parsedExpiryDate;
    if (expiry == null) return MedicineExpiryStatus.unknown;
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (expiry.isBefore(today)) return MedicineExpiryStatus.expired;
    if (expiry.difference(today).inDays <= daysThreshold) {
      return MedicineExpiryStatus.expiringSoon;
    }
    return MedicineExpiryStatus.valid;
  }

  /// Whether the medicine is past its expiry date
  bool get isExpired {
    return expiryStatus() == MedicineExpiryStatus.expired;
  }

  /// Whether the medicine will expire within [daysThreshold] days (default 60 days)
  bool isNearExpiry([int daysThreshold = 60]) {
    return expiryStatus(daysThreshold: daysThreshold) ==
        MedicineExpiryStatus.expiringSoon;
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
    String? mrp,
    String? rawOcrText,
    String? confidence,
    bool? isVerifiedByUser,
    String? packagingImagePath,
    bool clearPackagingImagePath = false,
    List<MedicinePackageImage>? packagingImages,
    String? productIdentifier,
    String? productIdentifierFormat,
    DateTime? productIdentifierScannedAt,
    bool clearProductIdentifierScannedAt = false,
    List<MedicineVerificationRecord>? verificationHistory,
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
      mrp: mrp ?? this.mrp,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      confidence: confidence ?? this.confidence,
      isVerifiedByUser: isVerifiedByUser ?? this.isVerifiedByUser,
      packagingImagePath: clearPackagingImagePath
          ? null
          : packagingImagePath ?? this.packagingImagePath,
      packagingImages: packagingImages ?? this.packagingImages,
      productIdentifier: productIdentifier ?? this.productIdentifier,
      productIdentifierFormat:
          productIdentifierFormat ?? this.productIdentifierFormat,
      productIdentifierScannedAt: clearProductIdentifierScannedAt
          ? null
          : productIdentifierScannedAt ?? this.productIdentifierScannedAt,
      verificationHistory: verificationHistory ?? this.verificationHistory,
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
      'mrp': mrp,
      'raw_ocr_text': rawOcrText,
      'confidence': confidence,
      'is_verified_by_user': isVerifiedByUser,
      'packaging_image_path': packagingImagePath,
      'packaging_images': packagingImages
          .map((image) => image.toJson())
          .toList(),
      'product_identifier': productIdentifier,
      'product_identifier_format': productIdentifierFormat,
      'product_identifier_scanned_at': productIdentifierScannedAt
          ?.toIso8601String(),
      'verification_history': verificationHistory
          .map((record) => record.toJson())
          .toList(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MedicineProfile.fromJson(Map<String, dynamic> json) {
    return MedicineProfile(
      id:
          json['id'] as String? ??
          'MED-${DateTime.now().millisecondsSinceEpoch}',
      medicineName: json['medicine_name'] as String? ?? '',
      manufacturer: json['manufacturer'] as String? ?? '',
      strength: json['strength'] as String? ?? '',
      dosageForm: json['dosage_form'] as String? ?? '',
      batchNumber: json['batch_number'] as String? ?? '',
      manufacturingDate: json['manufacturing_date'] as String? ?? '',
      expiryDate: json['expiry_date'] as String? ?? '',
      mrp: json['mrp'] as String? ?? '',
      rawOcrText: json['raw_ocr_text'] as String? ?? '',
      confidence: json['confidence'] as String? ?? 'UNCERTAIN',
      isVerifiedByUser: json['is_verified_by_user'] as bool? ?? false,
      packagingImagePath: json['packaging_image_path'] as String?,
      packagingImages: _readPackageImages(json['packaging_images']),
      productIdentifier: json['product_identifier'] as String? ?? '',
      productIdentifierFormat:
          json['product_identifier_format'] as String? ?? '',
      productIdentifierScannedAt: DateTime.tryParse(
        json['product_identifier_scanned_at'] as String? ?? '',
      ),
      verificationHistory: _readVerificationHistory(
        json['verification_history'],
      ),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static List<MedicinePackageImage> _readPackageImages(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => MedicinePackageImage.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((image) => image.path.isNotEmpty)
        .toList(growable: false);
  }

  static List<MedicineVerificationRecord> _readVerificationHistory(
    dynamic value,
  ) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => MedicineVerificationRecord.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }
}
