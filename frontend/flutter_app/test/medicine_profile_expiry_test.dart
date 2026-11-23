import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/models/medicine_profile.dart';

void main() {
  group('MedicineProfile expiry dates', () {
    test('month and year expiry runs through the final day of that month', () {
      final profile = MedicineProfile(
        id: 'month-expiry',
        medicineName: 'Example',
        expiryDate: '02/2028',
        createdAt: DateTime(2026),
      );

      expect(profile.parsedExpiryDate, DateTime(2028, 2, 29));
      expect(
        profile.expiryStatus(referenceDate: DateTime(2028, 2, 29)),
        MedicineExpiryStatus.expiringSoon,
      );
      expect(
        profile.expiryStatus(referenceDate: DateTime(2028, 3, 1)),
        MedicineExpiryStatus.expired,
      );
    });

    test('classifies expired, expiring soon, valid, and unknown dates', () {
      MedicineProfile profile(String expiry) => MedicineProfile(
        id: expiry,
        medicineName: 'Example',
        expiryDate: expiry,
        createdAt: DateTime(2026),
      );
      final reference = DateTime(2026, 11, 22);

      expect(
        profile('11/2026').expiryStatus(referenceDate: reference),
        MedicineExpiryStatus.expiringSoon,
      );
      expect(
        profile('12/2026').expiryStatus(referenceDate: reference),
        MedicineExpiryStatus.expiringSoon,
      );
      expect(
        profile('03/2027').expiryStatus(referenceDate: reference),
        MedicineExpiryStatus.valid,
      );
      final missing = profile('');
      final malformed = profile('13/2027');
      expect(
        missing.expiryStatus(referenceDate: reference),
        MedicineExpiryStatus.unknown,
      );
      expect(
        malformed.expiryStatus(referenceDate: reference),
        MedicineExpiryStatus.unknown,
      );
      expect(missing.isExpired, isFalse);
      expect(missing.isNearExpiry(), isFalse);
      expect(malformed.isExpired, isFalse);
      expect(malformed.isNearExpiry(), isFalse);
      expect(malformed.daysUntilExpiry, isNull);
    });

    test('rejects malformed and ambiguous calendar dates', () {
      expect(
        MedicineProfile.parseDateValue('31/02/2027', expiryDate: true),
        isNull,
      );
      expect(
        MedicineProfile.parseDateValue('03/04/2027', expiryDate: true),
        isNull,
      );
      expect(
        MedicineProfile.parseDateValue('13/04/2027', expiryDate: true),
        DateTime(2027, 4, 13),
      );
      expect(
        MedicineProfile.parseDateValue('2028-02-29', expiryDate: true),
        DateTime(2028, 2, 29),
      );
      expect(
        MedicineProfile.parseDateValue('2027-02-29', expiryDate: true),
        isNull,
      );
    });

    test(
      'manufacturing month uses its first day and absent form stays blank',
      () {
        final profile = MedicineProfile(
          id: 'legacy-profile',
          medicineName: 'Example',
          createdAt: DateTime(2026),
        );

        expect(MedicineProfile.parseDateValue('02/2028'), DateTime(2028, 2, 1));
        expect(profile.dosageForm, isEmpty);
        expect(
          MedicineProfile.fromJson({
            'id': 'legacy-json',
            'medicine_name': 'Example',
            'created_at': '2026-01-01T00:00:00.000',
          }).dosageForm,
          isEmpty,
        );
      },
    );

    test('legacy two digit month/year dates use a fixed century pivot', () {
      expect(
        MedicineProfile.parseDateValue('02/79', expiryDate: true),
        DateTime(2079, 2, 28),
      );
      expect(
        MedicineProfile.parseDateValue('02/80', expiryDate: true),
        DateTime(1980, 2, 29),
      );
      expect(MedicineProfile.parseDateValue('13/25', expiryDate: true), isNull);
    });
  });
}
