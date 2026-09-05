import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialStore {
  static const _storage = FlutterSecureStorage();
  static const _loginCookieKey = 'login_cookie';

  Future<String?> readLoginCookie() => _storage.read(key: _loginCookieKey);
  Future<void> writeLoginCookie(String value) => _storage.write(key: _loginCookieKey, value: value);
  Future<void> deleteLoginCookie() => _storage.delete(key: _loginCookieKey);
}