import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';

class SyncMemoryCookieJar implements CookieJar {
  final Map<String, List<Cookie>> _map = {};
  @override
  bool get ignoreExpires => false;
  @override
  Future<void> delete(Uri uri, [bool withDomainSharedCookie = false]) async {
    _map.remove(uri.host);
  }
  @override
  Future<void> deleteAll() async => _map.clear();
  @override
  Future<List<Cookie>> loadForRequest(Uri uri) async => _map[uri.host] ?? [];
  @override
  Future<void> saveFromResponse(Uri uri, List<Cookie> cookies) async {
    final host = uri.host;
    final list = _map.putIfAbsent(host, () => []);
    for (final c in cookies) {
      list.removeWhere((e) => e.name == c.name);
      list.add(c);
    }
  }
  List<Cookie> loadSync(Uri uri) => _map[uri.host] ?? [];
}
