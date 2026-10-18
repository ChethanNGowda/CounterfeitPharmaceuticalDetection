import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pharma_assist/services/api_service.dart';
import 'package:pharma_assist/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTesting();
    storage = await StorageService.getInstance();
  });

  test('health response uses backend reported fields', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/health');
      return http.Response(
        jsonEncode({
          'status': 'ok',
          'version': '2.1.0',
          'device': 'cuda',
          'default_model': 'efficientnet_b0',
        }),
        200,
      );
    });

    final health = await ApiService(storage, client).checkHealth();
    expect(health.version, '2.1.0');
    expect(health.device, 'cuda');
    expect(health.defaultModel, 'efficientnet_b0');
    client.close();
  });

  test('model registry can target the URL entered in settings', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://screening.example/models');
      return http.Response(
        jsonEncode({
          'available_models': ['efficientnet_b0'],
          'models': [
            {'model_name': 'efficientnet_b0', 'finetuned_available': true},
          ],
        }),
        200,
      );
    });

    final response = await ApiService(
      storage,
      client,
    ).fetchModels(customBaseUrl: 'https://screening.example/');
    expect((response['models'] as List).single['finetuned_available'], isTrue);
    client.close();
  });

  test(
    'health check reports an API failure instead of marking it online',
    () async {
      final client = MockClient(
        (request) async => http.Response('unavailable', 503),
      );
      await expectLater(
        ApiService(storage, client).checkHealth(),
        throwsA(isA<ApiException>()),
      );
      client.close();
    },
  );
}
