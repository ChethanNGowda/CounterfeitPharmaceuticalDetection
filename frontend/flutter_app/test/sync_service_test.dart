import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pharma_assist/core/constants.dart';
import 'package:pharma_assist/models/scan_history_item.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:pharma_assist/services/credential_service.dart';
import 'package:pharma_assist/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCredentials implements SyncCredentialStore {
  String? token;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> saveToken(String value) async => token = value;

  @override
  Future<void> clearToken() async => token = null;
}

ScanHistoryItem testItem() => ScanHistoryItem(
  id: 'record-1',
  sampleId: 'SMP-1',
  timestamp: DateTime.utc(2026, 11, 5),
  finalResult: 'SUSPICIOUS / NEEDS VERIFICATION',
  prediction: 'UNKNOWN',
  confidence: 0.4,
  primaryModel: 'efficientnet_b0',
  needsHumanVerification: true,
  operatingMode: AppConstants.operatingModeBackend,
  provider: AppConstants.providerBackend,
);

void main() {
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTesting();
    storage = await StorageService.getInstance();
  });

  test('consent is disabled by default and does not enqueue history', () async {
    expect(storage.getSyncConsent(), isFalse);
    await storage.addScanHistoryItem(testItem());
    expect(storage.getSyncQueue(), isEmpty);
  });

  test('payload maps the versioned backend contract without image consent', () {
    final service = SyncService(storage, credentials: FakeCredentials());
    final payload = service.buildPayload(testItem());

    expect(payload['api_version'], 'v1');
    expect(payload['client_record_id'], 'record-1');
    expect(payload['screening_metadata'], isA<Map<String, dynamic>>());
    expect(payload['image_upload_consent'], isFalse);
    expect(payload.containsKey('image_base64'), isFalse);
  });

  test('HTTPS is required except for local development hosts', () {
    expect(SyncService.isSecureEndpoint('https://api.example.test'), isTrue);
    expect(SyncService.isSecureEndpoint('http://127.0.0.1:8000'), isTrue);
    expect(SyncService.isSecureEndpoint('http://10.0.2.2:8000'), isTrue);
    expect(SyncService.isSecureEndpoint('http://192.168.1.10:8000'), isFalse);
  });

  test('authenticated sync maps successful and duplicate responses', () async {
    final credentials = FakeCredentials()..token = 'pa1.device.secret';
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer pa1.device.secret');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['api_version'], 'v1');
      expect(request.url.path, '/sync/records');
      return http.Response(
        jsonEncode({
          'api_version': 'v1',
          'server_record_id': 'server-1',
          'client_record_id': 'record-1',
          'synchronized_at': '2026-11-05T00:00:00Z',
          'duplicate': true,
          'image_stored': false,
          'screening_verified': false,
          'message': 'Record synchronized as unverified client metadata.',
        }),
        201,
      );
    });
    await storage.setBackendUrl('http://127.0.0.1:8000');
    final result = await SyncService(
      storage,
      credentials: credentials,
      client: client,
    ).synchronize(testItem());
    expect(result.duplicate, isTrue);
    expect(result.serverRecordId, 'server-1');
  });

  test('missing credentials and conflicts are not successful', () async {
    await storage.setBackendUrl('http://127.0.0.1:8000');
    final service = SyncService(storage, credentials: FakeCredentials());
    expect(
      () => service.synchronize(testItem()),
      throwsA(isA<SyncException>()),
    );

    final credentials = FakeCredentials()..token = 'token';
    final conflictClient = MockClient(
      (_) async => http.Response('{"detail":"conflict"}', 409),
    );
    expect(
      () => SyncService(
        storage,
        credentials: credentials,
        client: conflictClient,
      ).synchronize(testItem()),
      throwsA(predicate<SyncException>((error) => error.statusCode == 409)),
    );
  });
}
