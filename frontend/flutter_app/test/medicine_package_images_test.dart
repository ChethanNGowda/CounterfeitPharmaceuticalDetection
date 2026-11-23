import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/models/medicine_package_image.dart';
import 'package:pharma_assist/models/medicine_profile.dart';
import 'package:pharma_assist/models/medicine_verification_record.dart';
import 'package:pharma_assist/services/medicine_ocr_service.dart';

void main() {
  test('legacy single image remains readable as one package view', () {
    final profile = MedicineProfile.fromJson({
      'id': 'legacy-medicine',
      'medicine_name': 'Example',
      'packaging_image_path': '/old/cache/front.jpg',
      'raw_ocr_text': 'Batch: LOT42',
      'created_at': '2026-11-20T10:00:00.000',
    });

    expect(profile.packagingImages, isEmpty);
    expect(profile.packageImageRecords, hasLength(1));
    expect(profile.packageImageRecords.single.path, '/old/cache/front.jpg');
    expect(profile.packageImageRecords.single.rawOcrText, 'Batch: LOT42');
    expect(profile.toJson()['packaging_image_path'], '/old/cache/front.jpg');
  });

  test('package views and per-view OCR survive profile serialization', () {
    final capturedAt = DateTime.utc(2026, 11, 20, 10);
    final images = [
      MedicinePackageImage(
        id: 'front-1',
        path: '/medicine/front.jpg',
        label: 'Front of package',
        capturedAt: capturedAt,
        rawOcrText: 'Example 250 mg',
        extractedFields: const {
          MedicineOcrField.medicineName: 'Example',
          MedicineOcrField.strength: '250 mg',
        },
      ),
      MedicinePackageImage(
        id: 'back-1',
        path: '/medicine/back.jpg',
        label: 'Back of package',
        capturedAt: capturedAt.add(const Duration(minutes: 1)),
        rawOcrText: 'Batch: B-27',
        extractedFields: const {MedicineOcrField.batchNumber: 'B-27'},
      ),
    ];
    final profile = MedicineProfile(
      id: 'multi-view',
      medicineName: 'Example',
      packagingImagePath: images.first.path,
      packagingImages: images,
      createdAt: capturedAt,
    );

    final restored = MedicineProfile.fromJson(profile.toJson());
    expect(restored.packageImageRecords.map((image) => image.label), [
      'Front of package',
      'Back of package',
    ]);
    expect(restored.packageImageRecords.last.rawOcrText, 'Batch: B-27');
    expect(
      restored.packageImageRecords.last.extractedFields[MedicineOcrField
          .batchNumber],
      'B-27',
    );
    expect(restored.packageImageRecords.first.capturedAt, capturedAt);
  });

  test('malformed package image entries are ignored safely', () {
    final profile = MedicineProfile.fromJson({
      'id': 'bad-images',
      'medicine_name': 'Example',
      'packaging_images': [
        null,
        42,
        {'id': 'empty-path'},
        {'path': '/ok/a.jpg'},
      ],
      'created_at': '2026-11-20T10:00:00.000',
    });

    expect(profile.packagingImages, hasLength(1));
    expect(profile.packagingImages.single.label, 'Package photo');
  });

  test(
    'multi-image OCR conflicts report source labels without choosing a value',
    () {
      final front = MedicineOcrService.parsePackagingText(
        'Medicine Name: SampleDrug\nBatch No: BATCH-01\nExpiry: 11/2027',
      ).toPackageImage(path: '/photos/front.jpg', label: 'Front of package')!;
      final back = MedicineOcrService.parsePackagingText(
        'Medicine Name: SampleDrug\nBatch No: BATCH-02\nExpiry: 12/2027',
      ).toPackageImage(path: '/photos/back.jpg', label: 'Back of package')!;

      final conflicts = MedicineOcrService.findConflictingFields([front, back]);
      expect(conflicts[MedicineOcrField.batchNumber], hasLength(2));
      expect(
        conflicts[MedicineOcrField.batchNumber]!.map(
          (observation) => observation.imageLabel,
        ),
        ['Front of package', 'Back of package'],
      );
      expect(conflicts[MedicineOcrField.expiryDate], hasLength(2));
      expect(conflicts[MedicineOcrField.medicineName], isNull);
    },
  );

  test(
    'product identifier fields persist without changing old record fields',
    () {
      final profile = MedicineProfile.fromJson({
        'id': 'barcode-medicine',
        'medicine_name': 'SampleDrug',
        'product_identifier': '8901234567890',
        'product_identifier_format': 'ean13',
        'product_identifier_scanned_at': '2026-11-20T10:00:00.000Z',
        'created_at': '2026-11-20T10:00:00.000',
      });

      final restored = MedicineProfile.fromJson(profile.toJson());
      expect(restored.productIdentifier, '8901234567890');
      expect(restored.productIdentifierFormat, 'ean13');
      expect(
        restored.productIdentifierScannedAt,
        DateTime.utc(2026, 11, 20, 10),
      );
      expect(restored.medicineName, 'SampleDrug');
    },
  );

  test('verification history survives profile persistence', () {
    final checkedAt = DateTime.utc(2026, 11, 20, 10);
    final profile = MedicineProfile(
      id: 'history-profile',
      medicineName: 'SampleDrug',
      batchNumber: 'AB123',
      verificationHistory: [
        MedicineVerificationRecord(
          status: 'potential_concern',
          statusLabel: 'Potential concern',
          checkedAt: checkedAt,
          sources: [
            MedicineVerificationSource(
              title: 'CDSCO alert',
              url: 'https://www.cdsco.gov.in/opencms/alert.pdf',
              publishedAt: '2026-Jun-15',
              retrievedAt: checkedAt,
              excerpt: 'SampleDrug AB123',
            ),
          ],
          evidenceMatches: const ['medicine_name', 'batch_number'],
          warning: 'Requires human review.',
          disclaimer: 'Not an authenticity test.',
        ),
      ],
      createdAt: checkedAt,
    );

    final restored = MedicineProfile.fromJson(profile.toJson());
    expect(restored.verificationHistory, hasLength(1));
    expect(restored.verificationHistory.single.status, 'potential_concern');
    expect(
      restored.verificationHistory.single.sources.single.url,
      'https://www.cdsco.gov.in/opencms/alert.pdf',
    );
    expect(restored.verificationHistory.single.checkedAt, checkedAt);
  });
}
