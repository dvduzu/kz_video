import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_sign.dart';
import 'api_exception.dart';
import 'bilibili_client.dart';
import 'local_store.dart';
import 'models.dart';
import 'wbi_sign.dart';

class VideoRepository {
  static VideoRepository? _instance;
  static const int _cacheValidMs = 6 * 3600 * 1000;
  static VideoRepository instance() => _instance!;
  static void init(VideoRepository repo) => _instance = repo;

  bool get isLoggedIn => client.isLoggedIn;
  bool get hasAccount => client.hasAccount;
  bool get guestMode => client.guestMode;
  String get loginName => client.loginName;
  int get loginAt => client.loginAt;
  int get sessExpires => client.sessExpires;
  Future<void> setGuestMode(bool enabled) async {
    await client.setGuestMode(enabled);
    await store.setGuestMode(enabled);
  }

  final BilibiliClient client;
  final LocalStore store;
  final Dio dio;

  VideoRepository._(this.client, this.store) : dio = client.dio;

  static Future<VideoRepository> create() async {
    final client = BilibiliClient(BilibiliClient.createDio());
    final store = await LocalStore.create();
    return VideoRepository._(client, store);
  }

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
    await client.ensureBuvid();
    final parsed = _parseCookie(cookieHeader);
    if (!parsed.containsKey('SESSDATA') || parsed['SESSDATA']!.isEmpty) {
      return false;
    }
    final before = Map<String, String>.from(client.fullCookies ?? {});
    final merged = Map<String, String>.from(client.fullCookies ?? {});
    merged.addAll(parsed);
    client.setFullCookies(merged);
    final ok = await _validateLogin();
    if (ok) {
      final loginAt = DateTime.now().millisecondsSinceEpoch;
      final sess = parsed['SESSDATA'] ?? '';
      client.setLoginTimestamps(loginAt, _parseSessExpires(sess));
      const storage = FlutterSecureStorage();
      await storage.write(key: 'login_cookie', value: cookieHeader);
    } else {
      client.setFullCookies(before);
    }
    return ok;
  }

  Future<bool> _validateLogin() async {
    try {
      final hasSessdata = client.fullCookies?.containsKey('SESSDATA') == true;
      // ignore: avoid_print
      print('[kzv] validate: hasSESSDATA=$hasSessdata keys=${client.fullCookies?.keys.join(',')}');
      final cookieHeader = client.fullCookies?.entries.map((e) => '${e.key}=${e.value}').join('; ');
      final resp = await dio.get('https://api.bilibili.com/x/web-interface/nav', options: Options(headers: {
        if (cookieHeader != null) 'Cookie': cookieHeader,
      }));
      final data = resp.data as Map<String, dynamic>;
      // ignore: avoid_print
      print('[kzv] nav code=${data['code']} isLogin=${data['data']?['isLogin']} uname=${data['data']?['uname']}');
      final isLogin = data['data']?['isLogin'] == true;
      client.setLoginState(isLogin, isLogin ? ((data['data']?['uname'] as String?) ?? '') : '');
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
    await client.setGuestMode(store.guestMode);
  }

  Future<void> logout() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'login_cookie');
    client.setLoginState(false, '');
    client.setLoginTimestamps(0, 0);
    client.removeLoginCookies();
  }

  Future<Map<String, dynamic>> _wbiGet(String path, Map<String, dynamic> params) async {
    return client.wbiGet(path, params);
  }

  Future<List<VideoInfo>> _getRcmdVideos({int batch = 5}) async {
    try {
      await client.ensureBuvid();
      final all = <VideoInfo>[];
      for (var b = 0; b < batch && all.length < 60; b++) {
        final resp = await dio.get('/x/web-interface/index/top/rcmd', queryParameters: {'fresh_type': 3, 'fresh_idx': b}, options: Options(headers: client.requestHeaders()));
        final body = resp.data as Map<String, dynamic>;
        final code = body['code'];
        if (code is int && code != 0) {
          // ignore: avoid_print
          print('[kzv] rcmd error code=$code msg=${body['message']}');
          return all;
        }
        final items = (body['data']?['item'] as List?) ?? [];
        for (final e in items.whereType<Map<String, dynamic>>()) {
          if (e['goto'] != 'av' || e['owner'] == null) continue;
          final bvid = (e['bvid'] as String?) ?? '';
          if (bvid.isEmpty || all.any((v) => v.bvid == bvid)) continue;
          all.add(VideoInfo(
            bvid: bvid,
            title: (e['title'] as String?) ?? '',
            pic: ((e['pic'] as String?) ?? '').replaceFirst('http://', 'https://'),
            duration: (e['duration'] as int?) ?? 0,
            owner: ((e['owner'] as Map<String, dynamic>?)?['name'] as String?) ?? '',
            view: ((e['stat'] as Map<String, dynamic>?)?['view'] as int?) ?? 0,
            pubdate: (e['pubdate'] as int?) ?? 0,
            mid: ((e['owner'] as Map<String, dynamic>?)?['mid'] as int?) ?? 0,
            tid: (e['tid'] as int?) ?? 0,
          ));
        }
        if (items.isEmpty) break;
      }
      // ignore: avoid_print
      print('[kzv] rcmd total=${all.length}');
      return all;
    } catch (e) {
      // ignore: avoid_print
      print('[kzv] rcmd failed: $e');
      return [];
    }
  }

  Future<List<VideoInfo>> getDailyVideos({bool force = false}) async {
    final minDuration = store.minDuration;
    final ridKey = store.rid;
    final ridMain = _ridMain(ridKey);
    final today = _today();
    final key = 'daily_${ridKey}_$today';
    final tsKey = 'daily_ts_${ridKey}_$today';
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force) {
      final cachedTs = store.getDailyTs(tsKey);
      final cached = store.getDailyCache(key);
      if (cached != null && cachedTs != null && (now - cachedTs) < _cacheValidMs) {
        try {
          final list = (jsonDecode(cached) as List).map((e) => VideoInfo.fromJson(e as Map<String, dynamic>)).toList();
          if (list.isNotEmpty) return list;
        } catch (_) {}
      }
    }
    final blacklist = await _getBlacklistSet();
    if (ridKey != 'sub') {
      final rcmdOn = store.rcmdEnabled;
      final rcmdRids = store.rcmdRids.toSet();
      if (rcmdOn && rcmdRids.contains(ridKey)) {
        final batch = store.rcmdBatch;
        final rcmdVideos = await _getRcmdVideos(batch: batch);
        final rcmdFiltered = rcmdVideos.where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid)).toList();
        // ignore: avoid_print
        print('[kzv] rcmd raw=${rcmdVideos.length} filtered=$minDuration→${rcmdFiltered.length}');
        if (rcmdFiltered.isNotEmpty) {
          final picked = rcmdFiltered.take(20).toList()..shuffle(Random());
          final chosen = picked.take(10).toList();
          // ignore: avoid_print
          print('[kzv] daily(rcmd) min=$minDuration items=${rcmdFiltered.length} chosen=${chosen.length}');
          if (chosen.isNotEmpty) {
            await store.setDailyCache(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
            await store.setDailyTs(tsKey, now);
          }
          return chosen;
        }
      }
    }
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
      subVideos.addAll(await getUpVideos(sub.mid, tid: ridMain));
    }
    if (ridKey == 'sub') {
      final subFiltered = subVideos.where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid)).toList()
        ..sort((a, b) => b.pubdate.compareTo(a.pubdate));
      final picked = subFiltered.take(40).toList()..shuffle(Random());
      final chosen = picked.take(10).toList();
      // ignore: avoid_print
      print('[kzv] daily(sub) min=$minDuration sub=${subFiltered.length} chosen=${chosen.length}');
      if (chosen.isNotEmpty) {
        await store.setDailyCache(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
        await store.setDailyTs(tsKey, now);
      }
      return chosen;
    }
    final popularFiltered = popular.where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid)).toList()
      ..sort((a, b) => b.pubdate.compareTo(a.pubdate));
    final picked = popularFiltered.take(40).toList()..shuffle(Random());
    final chosen = picked.take(10).toList();
    // ignore: avoid_print
    print('[kzv] daily min=$minDuration popular=${popularFiltered.length} chosen=${chosen.length}');
    if (chosen.isNotEmpty) {
      await store.setDailyCache(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
      await store.setDailyTs(tsKey, now);
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

  String? get buvid3 => client.buvid3;

  Future<void> addBlacklist(VideoInfo v) async {
    final list = store.blacklist;
    list.removeWhere((e) => e['bvid'] == v.bvid);
    list.add(v.toJson());
    await store.setBlacklist(list);
  }

  Future<List<VideoInfo>> getBlacklistItems() async {
    return store.blacklist.map((e) {
      try { return VideoInfo.fromJson(e); } catch (_) { return null; }
    }).whereType<VideoInfo>().toList();
  }

  Future<void> removeBlacklist(String bvid) async {
    final list = store.blacklist;
    list.removeWhere((e) => e['bvid'] == bvid);
    await store.setBlacklist(list);
  }

  Future<void> saveProgress(String bvid, int positionMs, int durationMs) async {
    await store.setProgress(bvid, '$positionMs|$durationMs');
  }

  Future<({int positionMs, int durationMs})?> getProgress(String bvid) async {
    final raw = store.getProgress(bvid);
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 2) return null;
    final pos = int.tryParse(parts[0]);
    final dur = int.tryParse(parts[1]);
    if (pos == null || dur == null) return null;
    return (positionMs: pos, durationMs: dur);
  }

  Future<bool> isHistoryEnabled() async => store.isHistoryEnabled;

  Future<bool> isWatchLaterEnabled() async => store.isWatchLaterEnabled;

  Future<void> addHistory(VideoInfo v) async {
    if (!await isHistoryEnabled()) return;
    final list = store.history;
    list.removeWhere((e) => e['bvid'] == v.bvid);
    list.insert(0, v.toJson());
    if (list.length > 50) list.removeRange(50, list.length);
    await store.setHistory(list);
  }

  Future<List<VideoInfo>> getHistory() async {
    return store.history.map((e) {
      try { return VideoInfo.fromJson(e); } catch (_) { return null; }
    }).whereType<VideoInfo>().toList();
  }

  Future<void> addWatchLater(VideoInfo v) async {
    if (!await isWatchLaterEnabled()) return;
    final list = store.watchLater;
    if (!list.any((e) => e['bvid'] == v.bvid)) {
      list.add(v.toJson());
      if (list.length > 5) list.removeRange(5, list.length);
      await store.setWatchLater(list);
    }
  }

  Future<List<VideoInfo>> getWatchLater() async {
    return store.watchLater.map((e) {
      try { return VideoInfo.fromJson(e); } catch (_) { return null; }
    }).whereType<VideoInfo>().toList();
  }

  Future<void> removeWatchLater(String bvid) async {
    final list = store.watchLater;
    list.removeWhere((e) => e['bvid'] == bvid);
    await store.setWatchLater(list);
  }

  Future<bool> addSubscription(int mid, String name, {String face = ''}) async {
    final list = store.subscriptions;
    if (list.any((e) => e['mid'] == mid)) return true;
    if (list.length >= 50) return false;
    list.add({'mid': mid, 'name': name, 'face': face});
    await store.setSubscriptions(list);
    return true;
  }

  Future<bool> isSubscribed(int mid) async => store.subscriptions.any((e) => e['mid'] == mid);

  Future<List<({int mid, String name, String face})>> getSubscriptions() async {
    return store.subscriptions.map((m) {
      try {
        return (mid: m['mid'] as int, name: m['name'] as String? ?? '', face: (m['face'] as String?) ?? '');
      } catch (_) { return null; }
    }).whereType<({int mid, String name, String face})>().toList();
  }

  Future<void> removeSubscription(int mid) async {
    final list = store.subscriptions;
    list.removeWhere((e) => e['mid'] == mid);
    await store.setSubscriptions(list);
  }

  Future<List<SearchUser>> searchUsers(String keyword) async {
    if (keyword.trim().isEmpty) return [];
    try {
      await client.ensureBuvid();
      final mixinKey = await client.getMixinKey();
      final params = <String, dynamic>{
        'search_type': 'bili_user',
        'keyword': keyword,
        'page': 1,
        'page_size': 20,
        'platform': 'pc',
        'web_location': 1430654,
      };
      WbiSign.sign(params, mixinKey);
      final enc = Uri.encodeComponent(keyword);
      final resp = await dio.get('/x/web-interface/wbi/search/type',
        queryParameters: params,
        options: Options(headers: client.requestHeaders(extra: {
          'origin': 'https://search.bilibili.com',
          'referer': 'https://search.bilibili.com/bili_user?keyword=$enc',
        })));
      final body = resp.data as Map<String, dynamic>;
      final voucher = (body['data'] as Map<String, dynamic>?)?['v_voucher'] as String?;
      if (voucher != null && voucher.isNotEmpty) {
        throw const BilibiliApiException('搜索触发风控，请登录后重试');
      }
      if (body['code'] is int && body['code'] != 0) {
        throw BilibiliApiException('${body['message'] ?? body['code']}', code: body['code'] as int?);
      }
      final result = body['data']?['result'] as List? ?? [];
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
    } catch (e) {
      rethrow;
    }
  }

  Future<List<VideoInfo>> getUpVideos(int mid, {int tid = 0}) async {
    final web = await _getUpVideosWeb(mid, tid);
    if (web.isNotEmpty) return web;
    return _getUpVideosApp(mid, tid);
  }

  Future<List<VideoInfo>> _getUpVideosWeb(int mid, int tid) async {
    try {
      final data = await _wbiGet('/x/space/wbi/arc/search', {'mid': mid, 'ps': 30, 'tid': tid, 'pn': 1, 'keyword': '', 'order': 'pubdate', 'platform': 'web'});
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
        tid: (e['tid'] as int?) ?? 0,
      )).where((v) => v.bvid.isNotEmpty).toList();
    } catch (e) {
      // ignore: avoid_print
      print('[kzv] getUpVideosWeb failed: $e');
      return [];
    }
  }

  Future<List<VideoInfo>> _getUpVideosApp(int mid, int tid) async {
    try {
      final params = <String, dynamic>{'vmid': mid, 'order': 'pubdate', 'tid': tid, 'mobi_app': 'android'};
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
          tid: (e['tid'] as int?) ?? 0,
        );
      }).where((v) => v.bvid.isNotEmpty).toList();
    } catch (e) {
      // ignore: avoid_print
      print('[kzv] getUpVideosApp failed: $e');
      return [];
    }
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
    return store.getRefreshCount(_today()) < 5;
  }

  Future<void> recordRefresh() async {
    final today = _today();
    await store.setRefreshCount(today, store.getRefreshCount(today) + 1);
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
    return store.blacklist.map((e) => e['bvid'] as String? ?? '').where((s) => s.isNotEmpty).toSet();
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
