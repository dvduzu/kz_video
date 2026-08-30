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
    } catch (_) {}
    _buvidReady = true;
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
    if (!force) {
      final cached = prefs.getString(key);
      if (cached != null) {
        try {
          final list = (jsonDecode(cached) as List).map((e) => VideoInfo.fromJson(e as Map<String, dynamic>)).toList();
          if (list.isNotEmpty) return list;
        } catch (_) {}
      }
    }
    final data = await _wbiGet('/x/web-interface/ranking/v2', {'rid': 188});
    final list = (data['data']?['list'] as List?) ?? [];
    final videos = list.where((e) => (e['duration'] as int? ?? 0) >= 600).map((e) => VideoInfo(
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
    }
    return picked;
  }

  Future<String> getPlayUrl(String bvid) async {
    final viewData = await _wbiGet('/x/web-interface/view', {'bvid': bvid});
    final cid = viewData['data']?['cid'];
    if (cid == null) throw Exception('获取视频信息失败');
    final playData = await _wbiGet('/x/player/wbi/playurl', {
      'bvid': bvid,
      'cid': cid,
      'qn': 80,
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
    final dash = data?['dash'] as Map<String, dynamic>?;
    if (dash != null) {
      final videos = dash['video'] as List?;
      if (videos != null && videos.isNotEmpty) {
        videos.sort((a, b) => (b['bandwidth'] as int).compareTo(a['bandwidth'] as int));
        return (videos.first['baseUrl'] ?? videos.first['base_url']) as String;
      }
    }
    throw Exception('获取播放地址失败');
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

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
