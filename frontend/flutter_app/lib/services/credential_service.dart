import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SyncCredentialStore {
  Future<String?> readToken();
  Future<void> saveToken(String token);
  Future<void> clearToken();
}

class CredentialService implements SyncCredentialStore {
  static const _tokenKey = 'pharma_sync_bearer_token';
  final FlutterSecureStorage _storage;

  CredentialService([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<void> saveToken(String token) async {
    if (token.trim().isEmpty) {
      throw ArgumentError.value(token, 'token', 'Token cannot be empty');
    }
    await _storage.write(key: _tokenKey, value: token.trim());
  }

  @override
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
