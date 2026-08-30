import 'dart:convert';
import 'dart:math';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cookie_jar_sync.dart';
import 'models.dart';
import 'wbi_sign.dart';

class VideoRepository {
  static VideoRepository? _instance;
  static const int _cacheValidMs = 6 * 3600 * 1000;
  static VideoRepository instance() => _instance!;
  static void init(VideoRepository repo) => _instance = repo;

  final Dio dio;
  final SyncMemoryCookieJar cookieJar;

  VideoRepository._(this.dio, this.cookieJar);

  factory VideoRepository.create(String cookiePath) {
    final jar = SyncMemoryCookieJar();
    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.bilibili.com',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Referer': 'https://www.bilibili.com/',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    dio.interceptors.add(CookieManager(jar));
    dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false, requestHeader: false));
    return VideoRepository._(dio, jar);
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
    if (_buvidReady) return;
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
        final t = ((tick.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?)?['ticket'] as String?;
        if (t != null && t.isNotEmpty) cookies['bili_ticket'] = t;
      } catch (e) {
        // ignore: avoid_print
        print('[kzv] bili_ticket failed: $e');
      }
      _fullCookies = cookies;
      _buvidReady = true;
      // ignore: avoid_print
      print('[kzv] full cookies: ${cookies.keys.join(',')}');
    } catch (e) {
      // ignore: avoid_print
      print('[kzv] _ensureBuvid failed: $e');
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
    final rid = prefs.getInt('setting_rid') ?? 0;
    final today = _today();
    final key = 'daily_popular_$today';
    final tsKey = 'daily_ts_popular_$today';
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
    for (var attempt = 0; attempt < 3 && popular.isEmpty; attempt++) {
      for (var pn = 1; pn <= 8; pn++) {
        try {
          final data = await _wbiGet('/x/web-interface/popular', {'pn': pn, 'ps': 30});
          final lst = (data['data']?['list'] as List?) ?? [];
          popular.addAll(lst.where((e) => rid == 0 || (e['tid'] as int? ?? 0) == rid).map((e) => VideoInfo(
            bvid: e['bvid'] as String,
            title: e['title'] as String? ?? '',
            pic: (e['pic'] as String? ?? '').replaceFirst('http://', 'https://'),
            duration: e['duration'] as int? ?? 0,
            owner: (e['owner']?['name'] as String?) ?? '',
            view: (e['stat']?['view'] as int?) ?? 0,
            pubdate: (e['pubdate'] as int?) ?? 0,
            mid: (e['owner']?['mid'] as int?) ?? 0,
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
    final popularFiltered = popular.where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid) && !isSubVid(v.bvid)).toList()
      ..sort((a, b) => b.pubdate.compareTo(a.pubdate));
    final subFiltered = subVideos.where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid)).toList()
      ..sort((a, b) => b.pubdate.compareTo(a.pubdate));
    final pickedSub = subFiltered.take(4).toList();
    final pickedPopular = popularFiltered.take(40).toList()..shuffle(Random());
    final chosen = <VideoInfo>[...pickedSub];
    chosen.addAll(pickedPopular.where((v) => !chosen.any((c) => c.bvid == v.bvid)).take(10 - chosen.length));
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
      try {
        final playData = await _wbiGet('/x/player/wbi/playurl', {
          'bvid': bvid,
          'cid': cid,
          'qn': q,
          'fnval': 1,
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
    throw Exception('获取播放地址失败：$lastError');
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

  Future<bool> addSubscription(int mid, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('subscriptions') ?? [];
    if (list.any((e) => _subMidOfJson(e) == mid)) return true;
    if (list.length >= 10) return false;
    list.add(jsonEncode({'mid': mid, 'name': name}));
    await prefs.setStringList('subscriptions', list);
    return true;
  }

  Future<bool> isSubscribed(int mid) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('subscriptions') ?? [];
    return list.any((e) => _subMidOfJson(e) == mid);
  }

  Future<List<({int mid, String name})>> getSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('subscriptions') ?? [];
    return list.map((e) {
      try {
        final m = jsonDecode(e) as Map<String, dynamic>;
        return (mid: m['mid'] as int, name: m['name'] as String? ?? '');
      } catch (_) { return null; }
    }).whereType<({int mid, String name})>().toList();
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

  Future<List<VideoInfo>> getUpVideos(int mid) async {
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

  int _parseLength(String l) {
    final parts = l.split(':');
    var sec = 0;
    for (final p in parts) { sec = sec * 60 + (int.tryParse(p) ?? 0); }
    return sec;
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
