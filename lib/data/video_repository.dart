import 'dart:convert';
import 'dart:math';
import 'package:cookie_jar/cookie_jar.dart';
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
  Future<void> _ensureBuvid() async {
    if (_buvidReady) return;
    try {
      await dio.get('https://www.bilibili.com/');
      _buvidReady = true;
    } catch (e) {
      // 拿不到 buvid3 时后续播放可能因防盗链 403，记录以便定位
      // ignore: avoid_print
      print('[kzv] _ensureBuvid failed: $e');
    }
  }

  Future<Map<String, dynamic>> _wbiGet(String path, Map<String, dynamic> params) async {
    final mixinKey = await _getMixinKey();
    final signed = Map<String, dynamic>.from(params);
    WbiSign.sign(signed, mixinKey);
    final resp = await dio.get(path, queryParameters: signed);
    return resp.data as Map<String, dynamic>;
  }

  Future<List<VideoInfo>> getDailyVideos({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final key = 'daily_$today';
    final tsKey = 'daily_ts_$today';
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
    final rid = prefs.getInt('setting_rid') ?? 188;
    final minDuration = prefs.getInt('setting_min_duration') ?? 600;
    final data = await _wbiGet('/x/web-interface/ranking/v2', {'rid': rid});
    final blacklist = await _getBlacklistSet();
    final list = (data['data']?['list'] as List?) ?? [];
    final videos = list.where((e) => (e['duration'] as int? ?? 0) >= minDuration && !blacklist.contains(e['bvid'])).map((e) => VideoInfo(
      bvid: e['bvid'] as String,
      title: e['title'] as String? ?? '',
      pic: (e['pic'] as String? ?? '').replaceFirst('http://', 'https://'),
      duration: e['duration'] as int? ?? 0,
      owner: (e['owner']?['name'] as String?) ?? '',
      view: (e['stat']?['view'] as int?) ?? 0,
    )).toList()..shuffle(Random());
    final picked = videos.take(10).toList();
    if (picked.isNotEmpty) {
      await prefs.setString(key, jsonEncode(picked.map((e) => e.toJson()).toList()));
      await prefs.setInt(tsKey, now);
    }
    return picked;
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
    return {
      'dm_img_list': '[]',
      'dm_img_str': 'V2ViR0wgdmVyc2lvbg==',
      'dm_cover_img_str': 'V2ViR0wgcmVuZGVyZXI=',
      'dm_img_inter': '{"ds":[],"wh":[0,0,0],"of":[0,0,0]}',
    };
  }

  String? get buvid3 {
    for (final c in cookieJar.loadSync(Uri.parse('https://www.bilibili.com/'))) { if (c.name == 'buvid3') return c.value; }
    return null;
  }

  Future<void> addBlacklist(String bvid) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('blacklist') ?? [];
    if (!list.contains(bvid)) {
      list.add(bvid);
      await prefs.setStringList('blacklist', list);
    }
  }

  Future<bool> isBlacklisted(String bvid) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('blacklist') ?? []).contains(bvid);
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

  Future<void> addHistory(VideoInfo v) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('history') ?? [];
    list.removeWhere((e) => e.startsWith('${v.bvid}|'));
    list.insert(0, '${v.bvid}|${v.title}|${DateTime.now().millisecondsSinceEpoch}');
    if (list.length > 50) list.removeRange(50, list.length);
    await prefs.setStringList('history', list);
  }

  Future<List<VideoInfo>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('history') ?? [];
    return list.map((e) {
      final p = e.split('|');
      return VideoInfo(bvid: p[0], title: p.length > 1 ? p[1] : '', pic: '', duration: 0, owner: '', view: 0);
    }).toList();
  }

  Future<void> addWatchLater(VideoInfo v) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('watch_later') ?? [];
    if (!list.any((e) => e.startsWith('${v.bvid}|'))) {
      list.add('${v.bvid}|${v.title}');
      await prefs.setStringList('watch_later', list);
    }
  }

  Future<List<VideoInfo>> getWatchLater() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('watch_later') ?? [];
    return list.map((e) {
      final p = e.split('|');
      return VideoInfo(bvid: p[0], title: p.length > 1 ? p[1] : '', pic: '', duration: 0, owner: '', view: 0);
    }).toList();
  }

  Future<void> removeWatchLater(String bvid) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('watch_later') ?? [];
    list.removeWhere((e) => e.startsWith('$bvid|'));
    await prefs.setStringList('watch_later', list);
  }

  Future<Set<String>> _getBlacklistSet() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('blacklist') ?? []).toSet();
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
