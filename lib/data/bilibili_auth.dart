import 'dart:convert';

class BilibiliAuth {
  Map<String, String>? _fullCookies;
  bool _loggedIn = false;
  bool _guestMode = false;
  String _loginName = '';
  int _loginAt = 0;
  int _sessExpires = 0;

  bool get isLoggedIn => _loggedIn && !_guestMode;
  bool get hasAccount => _loggedIn;
  bool get guestMode => _guestMode;
  String get loginName => _loginName;
  int get loginAt => _loginAt;
  int get sessExpires => _sessExpires;

  Map<String, String>? get fullCookies => _fullCookies;
  void setFullCookies(Map<String, String> cookies) => _fullCookies = cookies;
  String? get buvid3 => _fullCookies?['buvid3'];

  Future<void> setGuestMode(bool enabled) async {
    _guestMode = enabled;
  }

  void setLoginState(bool loggedIn, String name) {
    _loggedIn = loggedIn;
    _loginName = name;
  }

  void setLoginTimestamps(int loginAt, int sessExpires) {
    _loginAt = loginAt;
    _sessExpires = sessExpires;
  }

  void removeLoginCookies() {
    _fullCookies?.remove('SESSDATA');
    _fullCookies?.remove('bili_jct');
    _fullCookies?.remove('DedeUserID');
    _fullCookies?.remove('DedeUserID__ckMd5');
  }

  Map<String, String> _loginHeaders([Map<String, String>? cookies]) {
    final midStr = (cookies ?? _fullCookies)?['DedeUserID'] ?? '';
    final mid = int.tryParse(midStr) ?? 0;
    return {
      if (mid > 0) 'x-bili-mid': midStr,
      if (mid > 0) 'x-bili-aurora-eid': _genAuroraEid(mid),
    };
  }

  Map<String, String> effectiveCookies() {
    final all = _fullCookies ?? const <String, String>{};
    if (!_guestMode) return all;
    return Map.fromEntries(all.entries.where((e) => !const {'SESSDATA', 'bili_jct', 'DedeUserID', 'DedeUserID__ckMd5', 'sid'}.contains(e.key)));
  }

  Map<String, String> requestHeaders({Map<String, String> extra = const {}}) {
    final cookies = effectiveCookies();
    final headers = <String, String>{
      ..._loginHeaders(cookies),
      ...extra,
    };
    if (cookies.isNotEmpty) headers['Cookie'] = cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    return headers;
  }

  Map<String, String> fullLoginHeaders() => _loginHeaders();

  String _genAuroraEid(int uid) {
    final midByte = utf8.encode(uid.toString());
    const key = 'ad1va46a7lza';
    for (var i = 0; i < midByte.length; i++) {
      midByte[i] ^= key.codeUnitAt(i % key.length);
    }
    return base64.encode(midByte).replaceAll('=', '');
  }
}