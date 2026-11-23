import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_assist/services/credential_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sync token is saved, read, and cleared through secure storage',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final credentials = CredentialService();

      await credentials.saveToken('pa1.device.one-time-secret');
      expect(await credentials.readToken(), 'pa1.device.one-time-secret');

      await credentials.clearToken();
      expect(await credentials.readToken(), isNull);
    },
  );

  test('empty credential errors do not include submitted values', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final credentials = CredentialService();

    try {
      await credentials.saveToken('   ');
      fail('Expected empty credentials to be rejected.');
    } on ArgumentError catch (error) {
      expect(error.toString(), isNot(contains('   ')));
      expect(error.toString(), contains('Token cannot be empty'));
    }
  });
}
