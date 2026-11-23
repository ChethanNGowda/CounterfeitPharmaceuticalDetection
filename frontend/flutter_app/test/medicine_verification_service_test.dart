import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pharma_assist/models/medicine_profile.dart';
import 'package:pharma_assist/services/medicine_verification_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<StorageService> createStorage() async {
  SharedPreferences.setMockInitialValues({});
  StorageService.resetForTesting();
  return StorageService.getInstance();
}

MedicineProfile sampleProfile({String batch = 'AB123'}) => MedicineProfile(
  id: 'profile-1',
  medicineName: 'SampleDrug',
  manufacturer: 'Example Labs',
  strength: '250 mg',
  batchNumber: batch,
  expiryDate: '12/2027',
  packagingImagePath: 'private-photo.jpg',
  productIdentifier: '8901234567890',
  createdAt: DateTime(2026, 11, 20),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sends reviewed metadata only to the configured verification route',
    () async {
      final storage = await createStorage();
      await storage.setBackendUrl('http://127.0.0.1:8000');
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'status': 'potential_concern',
            'status_label': 'Potential concern',
            'explanation': 'An official alert contains a matching batch entry.',
            'evidence_matches': ['batch_number', 'medicine_name'],
            'sources': [
              {
                'title': 'CDSCO spurious alert',
                'url': 'https://www.cdsco.gov.in/opencms/alerts/file.pdf',
                'published_at': '2026-Jun-15',
                'retrieved_at': '2026-11-20T10:00:00Z',
                'excerpt': 'SampleDrug batch AB123',
              },
            ],
            'ollama_available': true,
            'warning': 'Potential concern requiring professional review.',
            'disclaimer': 'This does not prove medicine authenticity.',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final report = await MedicineVerificationService(
        storage,
        client,
      ).checkOfficialAlerts(sampleProfile());

      expect(captured?.url.path, '/verification/official-alerts');
      final payload = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(payload['batch_number'], 'AB123');
      expect(payload['product_identifier'], '8901234567890');
      expect(payload.containsKey('image_base64'), isFalse);
      expect(payload.containsKey('packaging_image_path'), isFalse);
      expect(report.status, 'potential_concern');
      expect(report.sources.single.url, contains('cdsco.gov.in'));
      expect(report.ollamaAvailable, isTrue);
    },
  );

  test('refuses public cleartext backend URLs', () async {
    final storage = await createStorage();
    await storage.setBackendUrl('http://example.com');

    await expectLater(
      MedicineVerificationService(
        storage,
        MockClient((_) async => throw StateError('must not call')),
      ).checkOfficialAlerts(sampleProfile()),
      throwsA(isA<FormatException>()),
    );
  });

  test('requires a batch number before making a request', () async {
    final storage = await createStorage();
    await storage.setBackendUrl('http://127.0.0.1:8000');

    await expectLater(
      MedicineVerificationService(
        storage,
        MockClient((_) async => throw StateError('must not call')),
      ).checkOfficialAlerts(sampleProfile(batch: '')),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects unrecognized response outcomes', () async {
    final storage = await createStorage();
    await storage.setBackendUrl('http://127.0.0.1:8000');
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'status': 'genuine', 'status_label': 'Genuine'}),
        200,
      ),
    );

    await expectLater(
      MedicineVerificationService(
        storage,
        client,
      ).checkOfficialAlerts(sampleProfile()),
      throwsA(isA<FormatException>()),
    );
  });
}
