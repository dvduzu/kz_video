import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_sign.dart';
import 'models.dart';
import 'wbi_sign.dart';

class VideoRepository {
  static VideoRepository? _instance;
  static const int _cacheValidMs = 6 * 3600 * 1000;
  static VideoRepository instance() => _instance!;
  static void init(VideoRepository repo) => _instance = repo;

  final Dio dio;

  VideoRepository._(this.dio);

  factory VideoRepository.create(String cookiePath) {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.bilibili.com',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Referer': 'https://www.bilibili.com/',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false, requestHeader: false));
    return VideoRepository._(dio);
  }

  String? _mixinKey;
  int _mixinFetchedAt = 0;

  Future<String> _getMixinKey() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_mixinKey == null || now - _mixinFetchedAt > 12 * 3600 * 1000) {
      await _ensureBuvid();
      final resp = await dio.get('/x/web-interface/nav');
      final wbiImg = resp.data['data']?['wbi_img'];
      final imgUrl = wbiImg?['img_url'] as String? ?? '';
      final subUrl = wbiImg?['sub_url'] as String? ?? '';
      final imgKey = imgUrl.split('/').last.split('.').first;
      final subKey = subUrl.split('/').last.split('.').first;
      if (imgKey.isEmpty || subKey.isEmpty) throw Exception('WBI key empty');
      _mixinKey = WbiSign.getMixinKey(imgKey + subKey);
      _mixinFetchedAt = now;
    }
    return _mixinKey!;
  }

  bool _buvidReady = false;
  int _biliTicketExpires = 0;
  Map<String, String>? _fullCookies;

  String _hmacSha256(String key, String message) => Hmac(sha256, utf8.encode(key)).convert(utf8.encode(message)).toString();

  String _hex(int len) {
    final r = Random();
    final b = List<int>.generate(len, (_) => r.nextInt(256));
    return b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  String _genUuid() {
    const map = ['1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','10'];
    final r = Random();
    final sb = StringBuffer();
    final idx = [9,13,17,21];
    for (var i = 0; i < 32; i++) {
      if (idx.contains(i)) sb.write('-');
      sb.write(map[r.nextInt(16)]);
    }
    sb.write('${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}infoc');
    return sb.toString();
  }

  Future<void> _ensureBuvid() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (_buvidReady && (_biliTicketExpires == 0 || now < _biliTicketExpires)) return;
    _buvidReady = false;
    final savedLogin = <String, String>{};
    if (_fullCookies != null) {
      for (final k in ['SESSDATA', 'bili_jct', 'DedeUserID', 'DedeUserID__ckMd5']) {
        final v = _fullCookies![k];
        if (v != null) savedLogin[k] = v;
      }
    }
    try {
      final spi = await dio.get('https://api.bilibili.com/x/frontend/finger/spi');
      final data = (spi.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      final b3 = data['b_3'] as String? ?? '';
      final b4 = data['b_4'] as String? ?? '';
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final cookies = <String, String>{
        'buvid3': b3,
        'buvid4': b4,
        'b_nut': '$ts',
        'b_lsid': '${_hex(32).toUpperCase()}_${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}',
        '_uuid': _genUuid(),
        'buvid_fp': _hex(16),
      };
      final hexSign = _hmacSha256('XgwSnGZ1p', 'ts$ts');
      try {
        final tick = await dio.post(
          'https://api.bilibili.com/bapis/bilibili.api.ticket.v1.Ticket/GenWebTicket',
          queryParameters: {'key_id': 'ec02', 'hexsign': hexSign, 'context[ts]': '$ts', 'csrf': ''},
        );
        final td = (tick.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
        final t = td?['ticket'] as String?;
        if (t != null && t.isNotEmpty) {
          cookies['bili_ticket'] = t;
          final created = (td?['created_at'] as int?) ?? ts;
          final ttl = (td?['ttl'] as int?) ?? 1800;
          _biliTicketExpires = created + ttl;
        }
      } catch (e) {
        // ignore: avoid_print
        print('[kzv] bili_ticket failed: $e');
      }
      cookies.addAll(savedLogin);
      _fullCookies = cookies;
      _buvidReady = true;
      // ignore: avoid_print
      print('[kzv] full cookies: ${cookies.keys.join(',')}');
    } catch (e) {
      // ignore: avoid_print
      print('[kzv] _ensureBuvid failed: $e');
    }
  }

  bool _loggedIn = false;
  String _loginName = '';

  bool get isLoggedIn => _loggedIn;
  String get loginName => _loginName;

  Map<String, String> _parseCookie(String cookieHeader) {
    final map = <String, String>{};
    for (final part in cookieHeader.split(';')) {
      final i = part.indexOf('=');
      if (i > 0) {
        final k = part.substring(0, i).trim();
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
      // ignore: avoid_print
      print('[kzv] qr poll code=$code setCookie=${values?.length}');
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

  Future<bool> loginWithCookie(String cookieHeader) async {
    await _ensureBuvid();
    final parsed = _parseCookie(cookieHeader);
    if (!parsed.containsKey('SESSDATA') || parsed['SESSDATA']!.isEmpty) {
      return false;
    }
    final before = Map<String, String>.from(_fullCookies ?? {});
    final merged = Map<String, String>.from(_fullCookies ?? {});
    merged.addAll(parsed);
    _fullCookies = merged;
    final ok = await _validateLogin();
    if (ok) {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'login_cookie', value: cookieHeader);
    } else {
      _fullCookies = before;
    }
    return ok;
  }

  Future<bool> _validateLogin() async {
    try {
      final hasSessdata = _fullCookies?.containsKey('SESSDATA') == true;
      // ignore: avoid_print
      print('[kzv] validate: hasSESSDATA=$hasSessdata keys=${_fullCookies?.keys.join(',')}');
      final cookieHeader = _fullCookies?.entries.map((e) => '${e.key}=${e.value}').join('; ');
      final resp = await dio.get('https://api.bilibili.com/x/web-interface/nav', options: Options(headers: {
        if (cookieHeader != null) 'Cookie': cookieHeader,
      }));
      final data = resp.data as Map<String, dynamic>;
      // ignore: avoid_print
      print('[kzv] nav code=${data['code']} isLogin=${data['data']?['isLogin']} uname=${data['data']?['uname']}');
      final isLogin = data['data']?['isLogin'] == true;
      if (isLogin) {
        _loggedIn = true;
        _loginName = (data['data']?['uname'] as String?) ?? '';
      } else {
        _loggedIn = false;
        _loginName = '';
      }
      return isLogin;
    } catch (e) {
      // ignore: avoid_print
      print('[kzv] validate error: $e');
      return false;
    }
  }

  Future<void> restoreLogin() async {
    const storage = FlutterSecureStorage();
    final saved = await storage.read(key: 'login_cookie');
    if (saved != null && saved.isNotEmpty) {
      await loginWithCookie(saved);
    }
  }

  Future<void> logout() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'login_cookie');
    _loggedIn = false;
    _loginName = '';
    if (_fullCookies != null) {
      _fullCookies!.remove('SESSDATA');
      _fullCookies!.remove('bili_jct');
      _fullCookies!.remove('DedeUserID');
      _fullCookies!.remove('DedeUserID__ckMd5');
    }
  }

  Future<Map<String, dynamic>> _wbiGet(String path, Map<String, dynamic> params) async {
    await _ensureBuvid();
    final mixinKey = await _getMixinKey();
    final signed = Map<String, dynamic>.from(params);
    WbiSign.sign(signed, mixinKey);
    final cookieHeader = _fullCookies?.entries.map((e) => '${e.key}=${e.value}').join('; ');
    final resp = await dio.get(path, queryParameters: signed, options: Options(headers: {
      if (cookieHeader != null) 'Cookie': cookieHeader,
    }));
    return resp.data as Map<String, dynamic>;
  }

  Future<List<VideoInfo>> getDailyVideos({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final minDuration = prefs.getInt('setting_min_duration') ?? 600;
    final ridKey = prefs.getString('setting_rid') ?? '';
    final ridMain = _ridMain(ridKey);
    final today = _today();
    final key = 'daily_${ridMain}_$today';
    final tsKey = 'daily_ts_${ridMain}_$today';
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force) {
      final cachedTs = prefs.getInt(tsKey);
      final cached = prefs.getString(key);
      if (cached != null && cachedTs != null && (now - cachedTs) < _cacheValidMs) {
        try {
          final list = (jsonDecode(cached) as List).map((e) => VideoInfo.fromJson(e as Map<String, dynamic>)).toList();
          if (list.isNotEmpty) return list;
        } catch (_) {}
      }
    }
    final blacklist = await _getBlacklistSet();
    final List<VideoInfo> popular = [];
    List<Map<String, dynamic>> rawVideos(List<dynamic> list) => list.map((e) => e as Map<String, dynamic>).toList();
    for (var attempt = 0; attempt < 3 && popular.isEmpty; attempt++) {
      if (ridMain == 0) {
        for (var pn = 1; pn <= 8; pn++) {
          try {
            final data = await _wbiGet('/x/web-interface/popular', {'pn': pn, 'ps': 30});
            final lst = (data['data']?['list'] as List?) ?? [];
            popular.addAll(rawVideos(lst).map((e) => VideoInfo(
              bvid: e['bvid'] as String,
              title: e['title'] as String? ?? '',
              pic: (e['pic'] as String? ?? '').replaceFirst('http://', 'https://'),
              duration: e['duration'] as int? ?? 0,
              owner: (e['owner']?['name'] as String?) ?? '',
              view: (e['stat']?['view'] as int?) ?? 0,
              pubdate: (e['pubdate'] as int?) ?? 0,
              mid: (e['owner']?['mid'] as int?) ?? 0,
              tid: (e['tid'] as int?) ?? 0,
            )));
          } catch (_) {}
        }
      } else {
        try {
          final data = await _wbiGet('/x/web-interface/ranking/v2', {'rid': ridMain, 'type': 'all'});
          final lst = (data['data']?['list'] as List?) ?? [];
          popular.addAll(rawVideos(lst).map((e) => VideoInfo(
            bvid: e['bvid'] as String,
            title: e['title'] as String? ?? '',
            pic: (e['pic'] as String? ?? '').replaceFirst('http://', 'https://'),
            duration: e['duration'] as int? ?? 0,
            owner: (e['owner']?['name'] as String?) ?? '',
            view: (e['stat']?['view'] as int?) ?? 0,
            pubdate: (e['pubdate'] as int?) ?? 0,
            mid: (e['owner']?['mid'] as int?) ?? 0,
            tid: (e['tid'] as int?) ?? 0,
          )));
        } catch (_) {}
      }
      if (popular.isEmpty) await Future<void>.delayed(Duration(milliseconds: 600 * (attempt + 1)));
    }
    final subs = await getSubscriptions();
    final List<VideoInfo> subVideos = [];
    for (final sub in subs) {
      subVideos.addAll(await getUpVideos(sub.mid));
    }
    bool isSubVid(String bvid) => subVideos.any((v) => v.bvid == bvid);
    final modeEnabled = prefs.getBool('setting_source_mode_enabled') ?? false;
    final mode = modeEnabled ? (prefs.getString('setting_source_mode') ?? 'mixed') : 'mixed';
    final popularFiltered = popular.where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid) && !isSubVid(v.bvid)).toList()
      ..sort((a, b) => b.pubdate.compareTo(a.pubdate));
    final pool = popularFiltered;
    final subFiltered = subVideos.where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid)).toList()
      ..sort((a, b) => b.pubdate.compareTo(a.pubdate));
    final List<VideoInfo> chosen;
    if (mode == 'sub') {
      final picked = subFiltered.take(20).toList()..shuffle(Random());
      chosen = picked.take(10).toList();
    } else if (mode == 'popular') {
      final picked = pool.take(40).toList()..shuffle(Random());
      chosen = picked.take(10).toList();
    } else {
      final pickedSub = subFiltered.take(4).toList();
      final pickedPopular = pool.take(40).toList()..shuffle(Random());
      chosen = <VideoInfo>[...pickedSub];
      chosen.addAll(pickedPopular.where((v) => !chosen.any((c) => c.bvid == v.bvid)).take(10 - chosen.length));
    }
    // ignore: avoid_print
    print('[kzv] daily min=$minDuration sub=${subFiltered.length} popular=${popularFiltered.length} chosen=${chosen.length}');
    if (chosen.isNotEmpty) {
      await prefs.setString(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
      await prefs.setInt(tsKey, now);
    }
    return chosen;
  }

  Future<String> getPlayUrl(String bvid, {int? qn}) async {
    final viewData = await _wbiGet('/x/web-interface/view', {'bvid': bvid});
    final cid = viewData['data']?['cid'];
    if (cid == null) throw Exception('获取视频信息失败');
    final requested = qn != null ? [qn] : [80, 64, 32];
    String? lastError;
    for (final q in requested) {
      for (final fnval in [1, 0]) {
        try {
          final playData = await _wbiGet('/x/player/wbi/playurl', {
            'bvid': bvid,
            'cid': cid,
            'qn': q,
            'fnval': fnval,
            'fnver': 0,
            'fourk': 1,
            'try_look': 1,
            'web_location': 1315873,
            ..._dmImgParams(),
          });
          final data = playData['data'] as Map<String, dynamic>?;
          final durl = data?['durl'] as List?;
          if (durl != null && durl.isNotEmpty) {
            return durl.first['url'] as String;
          }
        } catch (e) {
          lastError = e.toString();
        }
      }
    }
    throw Exception('获取播放地址失败（无可用 durl）：$lastError');
  }

  Map<String, dynamic> _dmImgParams() {
    const vendors = ['AMD', 'Intel', 'NVIDIA'];
    const gpus = ['AMD Radeon RX 6700 XT', 'AMD Radeon RX 6600', 'Intel(R) UHD Graphics 630', 'Intel(R) Iris(R) Xe Graphics', 'NVIDIA GeForce RTX 3060', 'NVIDIA GeForce RTX 4060 Laptop GPU', 'NVIDIA GeForce GTX 1650 Ti'];
    final r = Random();
    final vendor = vendors[r.nextInt(vendors.length)];
    final gpu = gpus[r.nextInt(gpus.length)];
    final webgl = 'WebGL 1.0 (OpenGL ES 2.0 Chromium)';
    final angle = 'ANGLE ($vendor, $gpu Direct3D11 vs_5_0 ps_5_0, D3D11)Google Inc. ($vendor)';
    final w = 1920 - 60 - r.nextInt(60);
    final h = 1080 - 90 - r.nextInt(60);
    final rnd = r.nextInt(114);
    final o1 = 3 * r.nextInt(514);
    final o2 = 4 * r.nextInt(514);
    String b64(String s) => base64Encode(utf8.encode(s)).replaceAll('=', '');
    return {
      'dm_img_list': '[]',
      'dm_img_str': b64(webgl),
      'dm_cover_img_str': b64(angle),
      'dm_img_inter': '{"ds":[],"wh":[$w,$h,$rnd],"of":[$o1,$o2,$rnd]}',
    };
  }

  String? get buvid3 {
    return _fullCookies?['buvid3'];
  }

  Future<void> addBlacklist(VideoInfo v) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('blacklist') ?? [];
    list.removeWhere((e) => _bvidOfJson(e) == v.bvid);
    list.add(jsonEncode(v.toJson()));
    await prefs.setStringList('blacklist', list);
  }

  Future<List<VideoInfo>> getBlacklistItems() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('blacklist') ?? [];
    return list.map((e) {
      try { return VideoInfo.fromJson(jsonDecode(e) as Map<String, dynamic>); } catch (_) { return null; }
    }).whereType<VideoInfo>().toList();
  }

  Future<void> removeBlacklist(String bvid) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('blacklist') ?? [];
    list.removeWhere((e) => _bvidOfJson(e) == bvid);
    await prefs.setStringList('blacklist', list);
  }

  Future<void> saveProgress(String bvid, int positionMs, int durationMs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('progress_$bvid', '$positionMs|$durationMs');
  }

  Future<({int positionMs, int durationMs})?> getProgress(String bvid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('progress_$bvid');
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 2) return null;
    final pos = int.tryParse(parts[0]);
    final dur = int.tryParse(parts[1]);
    if (pos == null || dur == null) return null;
    return (positionMs: pos, durationMs: dur);
  }

  Future<bool> isHistoryEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('setting_history') ?? true;
  }

  Future<bool> isWatchLaterEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('setting_watch_later') ?? true;
  }

  Future<void> addHistory(VideoInfo v) async {
    if (!await isHistoryEnabled()) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('history') ?? [];
    list.removeWhere((e) => _bvidOfJson(e) == v.bvid);
    list.insert(0, jsonEncode(v.toJson()));
    if (list.length > 50) list.removeRange(50, list.length);
    await prefs.setStringList('history', list);
  }

  Future<List<VideoInfo>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('history') ?? [];
    return list.map((e) {
      try { return VideoInfo.fromJson(jsonDecode(e) as Map<String, dynamic>); } catch (_) { return null; }
    }).whereType<VideoInfo>().toList();
  }

  Future<void> addWatchLater(VideoInfo v) async {
    if (!await isWatchLaterEnabled()) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('watch_later') ?? [];
    if (!list.any((e) => _bvidOfJson(e) == v.bvid)) {
      list.add(jsonEncode(v.toJson()));
      if (list.length > 5) list.removeRange(5, list.length);
      await prefs.setStringList('watch_later', list);
    }
  }

  Future<List<VideoInfo>> getWatchLater() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('watch_later') ?? [];
    return list.map((e) {
      try { return VideoInfo.fromJson(jsonDecode(e) as Map<String, dynamic>); } catch (_) { return null; }
    }).whereType<VideoInfo>().toList();
  }

  Future<void> removeWatchLater(String bvid) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('watch_later') ?? [];
    list.removeWhere((e) => _bvidOfJson(e) == bvid);
    await prefs.setStringList('watch_later', list);
  }

  String? _bvidOfJson(String s) {
    try { return (jsonDecode(s) as Map<String, dynamic>)['bvid'] as String?; } catch (_) { return null; }
  }

  Future<bool> addSubscription(int mid, String name, {String face = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('subscriptions') ?? [];
    if (list.any((e) => _subMidOfJson(e) == mid)) return true;
    if (list.length >= 50) return false;
    list.add(jsonEncode({'mid': mid, 'name': name, 'face': face}));
    await prefs.setStringList('subscriptions', list);
    return true;
  }

  Future<bool> isSubscribed(int mid) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('subscriptions') ?? [];
    return list.any((e) => _subMidOfJson(e) == mid);
  }

  Future<List<({int mid, String name, String face})>> getSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('subscriptions') ?? [];
    return list.map((e) {
      try {
        final m = jsonDecode(e) as Map<String, dynamic>;
        return (mid: m['mid'] as int, name: m['name'] as String? ?? '', face: (m['face'] as String?) ?? '');
      } catch (_) { return null; }
    }).whereType<({int mid, String name, String face})>().toList();
  }

  Future<void> removeSubscription(int mid) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('subscriptions') ?? [];
    list.removeWhere((e) => _subMidOfJson(e) == mid);
    await prefs.setStringList('subscriptions', list);
  }

  int? _subMidOfJson(String s) {
    try { return (jsonDecode(s) as Map<String, dynamic>)['mid'] as int?; } catch (_) { return null; }
  }

  Future<List<SearchUser>> searchUsers(String keyword) async {
    try {
      final data = await _wbiGet('/x/web-interface/wbi/search/type', {
        'search_type': 'bili_user',
        'keyword': keyword,
        'page': 1,
        'page_size': 20,
      });
      final result = data['data']?['result'] as List? ?? [];
      return result.map((e) {
        final m = e as Map<String, dynamic>;
        return SearchUser(
          mid: m['mid'] as int? ?? 0,
          uname: m['uname'] as String? ?? '',
          sign: m['usign'] as String? ?? '',
          fans: m['fans'] as int? ?? 0,
          face: ((m['upic'] as String?) ?? '').replaceFirst('http://', 'https://'),
        );
      }).where((u) => u.mid > 0).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<VideoInfo>> getUpVideos(int mid) async {
    final web = await _getUpVideosWeb(mid);
    if (web.isNotEmpty) return web;
    return _getUpVideosApp(mid);
  }

  Future<List<VideoInfo>> _getUpVideosWeb(int mid) async {
    try {
      final data = await _wbiGet('/x/space/wbi/arc/search', {'mid': mid, 'ps': 30, 'tid': 0, 'pn': 1, 'keyword': '', 'order': 'pubdate', 'platform': 'web'});
      final vlist = (data['data']?['list']?['vlist'] as List?) ?? [];
      return vlist.map((e) => VideoInfo(
        bvid: e['bvid'] as String? ?? '',
        title: e['title'] as String? ?? '',
        pic: (e['pic'] as String? ?? '').replaceFirst('http://', 'https://'),
        duration: _parseLength(e['length'] as String? ?? '0'),
        owner: e['author'] as String? ?? '',
        view: e['play'] as int? ?? 0,
        pubdate: e['created'] as int? ?? 0,
        mid: mid,
      )).where((v) => v.bvid.isNotEmpty).toList();
    } catch (_) { return []; }
  }

  Future<List<VideoInfo>> _getUpVideosApp(int mid) async {
    try {
      final params = <String, dynamic>{'vmid': mid, 'order': 'pubdate', 'mobi_app': 'android'};
      AppSign.appSign(params);
      final resp = await dio.get('https://app.bilibili.com/x/v2/space/archive/cursor', queryParameters: params, options: Options(headers: {
        'User-Agent': 'Mozilla/5.0 BiliDroid/8.43.0 (bbcallen@gmail.com) os/android model/android mobi_app/android build/8430300 channel/master innerVer/8430300 osVer/15 network/2',
        'Referer': 'https://www.bilibili.com/',
      }));
      final items = (resp.data?['data']?['item'] as List?) ?? [];
      return items.map((e) {
        final lenVal = e['length'];
        final durVal = e['duration'];
        return VideoInfo(
          bvid: e['bvid'] as String? ?? '',
          title: (e['title'] as String?) ?? '',
          pic: ((e['cover'] as String?) ?? '').replaceFirst('http://', 'https://'),
          duration: durVal is int ? durVal : (lenVal is String ? _parseLength(lenVal) : 0),
          owner: (e['author'] as String?) ?? '',
          view: (e['play'] as int?) ?? 0,
          pubdate: (e['ctime'] as int?) ?? 0,
          mid: mid,
        );
      }).where((v) => v.bvid.isNotEmpty).toList();
    } catch (_) { return []; }
  }

  int _parseLength(String l) {
    final parts = l.split(':');
    var sec = 0;
    for (final p in parts) { sec = sec * 60 + (int.tryParse(p) ?? 0); }
    return sec;
  }

  int _ridMain(String key) {
    return switch (key) {
      'tech' => 1012,
      'edu' => 1010,
      'life' => 1020,
      'game' => 1008,
      'ent' => 1002,
      'music' => 1003,
      _ => 0,
    };
  }

  Future<bool> canRefreshToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final count = prefs.getInt('refresh_count_$today') ?? 0;
    return count < 5;
  }

  Future<void> recordRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final count = prefs.getInt('refresh_count_$today') ?? 0;
    await prefs.setInt('refresh_count_$today', count + 1);
  }

  Future<List<SubtitleCue>?> getSubtitles(String bvid) async {
    try {
      final viewData = await _wbiGet('/x/web-interface/view', {'bvid': bvid});
      final cid = viewData['data']?['cid'];
      if (cid == null) return null;
      final playData = await _wbiGet('/x/player/wbi/v2', {'bvid': bvid, 'cid': cid, 'fnval': 16});
      final subtitle = playData['data']?['subtitle'] as Map<String, dynamic>?;
      final list = subtitle?['subtitles'] as List? ?? [];
      Map<String, dynamic>? zh;
      for (final s in list.cast<Map<String, dynamic>>()) {
        final lan = (s['lan'] as String?) ?? '';
        if (lan.contains('zh')) { zh = s; break; }
      }
      zh ??= list.isNotEmpty ? list.first as Map<String, dynamic> : null;
      if (zh == null) return null;
      final url = (zh['subtitle_url'] as String?) ?? '';
      if (url.isEmpty) return null;
      final resp = await dio.get('https:$url');
      final body = (resp.data as Map<String, dynamic>?)?['body'] as List? ?? [];
      return body.map((e) {
        final m = e as Map<String, dynamic>;
        return SubtitleCue(
          from: (m['from'] as num).toDouble(),
          to: (m['to'] as num).toDouble(),
          content: (m['content'] as String).trim(),
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  Future<Set<String>> _getBlacklistSet() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('blacklist') ?? [];
    return list.map((e) => _bvidOfJson(e)).whereType<String>().toSet();
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
