import 'dart:convert';
import 'package:dio/dio.dart';
import 'bilibili_client.dart';
import 'credential_store.dart';
import 'local_store.dart';
import '../core/logger.dart';

class AuthRepository {
  final BilibiliClient client;
  final LocalStore store;
  final CredentialStore credentials;
  final Dio dio;

  AuthRepository(this.client, this.store)
      : credentials = CredentialStore(),
        dio = client.dio;

  int _parseSessExpires(String sessdata) {
    try {
      final decoded = utf8.decode(base64.decode(base64.normalize(sessdata)));
      final parts = decoded.split('.');
      if (parts.length >= 3) return int.tryParse(parts[2]) ?? 0;
    } catch (_) {}
    return 0;
  }

  Map<String, String> _parseCookie(String cookieHeader) {
    const skip = {'path', 'domain', 'expires', 'max-age', 'samesite', 'httponly', 'secure', 'priority', 'partitioned'};
    final map = <String, String>{};
    for (final part in cookieHeader.split(';')) {
      final i = part.indexOf('=');
      if (i > 0) {
        final k = part.substring(0, i).trim();
        if (skip.contains(k.toLowerCase())) continue;
        var v = part.substring(i + 1).trim();
        if (v.length >= 2 && (v.startsWith('"') && v.endsWith('"') || v.startsWith("'") && v.endsWith("'"))) {
          v = v.substring(1, v.length - 1);
        }
        if (k.isNotEmpty) map[k] = v;
      }
    }
    return map;
  }

  Future<({String key, String url})?> webQrGenerate() async {
    try {
      final resp = await dio.get('https://passport.bilibili.com/x/passport-login/web/qrcode/generate');
      final data = resp.data as Map<String, dynamic>;
      final d = data['data'] as Map<String, dynamic>?;
      final key = d?['qrcode_key'] as String?;
      final url = d?['url'] as String?;
      if (key == null || key.isEmpty) return null;
      return (key: key, url: url ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<bool> webQrPoll(String key) async {
    try {
      final resp = await dio.get('https://passport.bilibili.com/x/passport-login/web/qrcode/poll', queryParameters: {'qrcode_key': key});
      final data = resp.data as Map<String, dynamic>;
      final d = data['data'] as Map<String, dynamic>?;
      final code = d?['code'] as int?;
      final values = resp.headers.map['set-cookie'];
      KzvLogger.debug('qr poll code=$code setCookie=${values?.length}');
      if (code == 0) {
        final values = resp.headers.map['set-cookie'];
        if (values != null && values.isNotEmpty) {
          final cookieHeader = values.join('; ');
          if (cookieHeader.contains('SESSDATA')) {
            final ok = await loginWithCookie(cookieHeader);
            return ok;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Stream<bool> webQrLoginFlow(String key) async* {
    for (var i = 0; i < 90; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final ok = await webQrPoll(key);
      yield ok;
      if (ok) return;
    }
  }

  Future<bool> loginWithCookie(String cookieHeader) async {
    await client.device.ensureBuvid();
    final parsed = _parseCookie(cookieHeader);
    if (!parsed.containsKey('SESSDATA') || parsed['SESSDATA']!.isEmpty) {
      return false;
    }
    final before = Map<String, String>.from(client.auth.fullCookies ?? {});
    final merged = Map<String, String>.from(client.auth.fullCookies ?? {});
    merged.addAll(parsed);
    client.auth.setFullCookies(merged);
    final ok = await _validateLogin();
    if (ok) {
      final loginAt = DateTime.now().millisecondsSinceEpoch;
      final sess = parsed['SESSDATA'] ?? '';
      client.auth.setLoginTimestamps(loginAt, _parseSessExpires(sess));
      await credentials.writeLoginCookie(cookieHeader);
    } else {
      client.auth.setFullCookies(before);
    }
    return ok;
  }

  Future<bool> _validateLogin() async {
    try {
      final hasSessdata = client.auth.fullCookies?.containsKey('SESSDATA') == true;
      KzvLogger.debug('validate: hasSESSDATA=$hasSessdata');
      final cookieHeader = client.auth.fullCookies?.entries.map((e) => '${e.key}=${e.value}').join('; ');
      final resp = await dio.get('https://api.bilibili.com/x/web-interface/nav', options: Options(headers: {
        if (cookieHeader != null) 'Cookie': cookieHeader,
      }));
      final data = resp.data as Map<String, dynamic>;
      KzvLogger.debug('nav code=${data['code']} isLogin=${data['data']?['isLogin']} uname=${data['data']?['uname']}');
      final isLogin = data['data']?['isLogin'] == true;
      client.auth.setLoginState(isLogin, isLogin ? ((data['data']?['uname'] as String?) ?? '') : '');
      return isLogin;
    } catch (e) {
      KzvLogger.debug('validate error: $e');
      return false;
    }
  }

  Future<void> restoreLogin() async {
    final saved = await credentials.readLoginCookie();
    if (saved != null && saved.isNotEmpty) {
      await loginWithCookie(saved);
    }
    await client.auth.setGuestMode(store.guestMode);
  }

  Future<void> logout() async {
    await credentials.deleteLoginCookie();
    client.auth.setLoginState(false, '');
    client.auth.setLoginTimestamps(0, 0);
    client.auth.removeLoginCookies();
  }
}