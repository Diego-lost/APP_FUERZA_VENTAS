import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro JWT y código de asesor (Criterio 4 / RF-04).
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _keyToken = 'auth_access_token';
  static const _keyCodigo = 'remembered_asesor_codigo';

  Future<void> saveToken(String token) =>
      _storage.write(key: _keyToken, value: token);

  Future<String?> readToken() => _storage.read(key: _keyToken);

  Future<void> clearToken() => _storage.delete(key: _keyToken);

  Future<void> saveRememberedCodigo(String codigo) =>
      _storage.write(key: _keyCodigo, value: codigo);

  Future<String?> readRememberedCodigo() => _storage.read(key: _keyCodigo);

  Future<void> clearAll() => _storage.deleteAll();
}
