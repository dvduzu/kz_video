import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'app_sign.dart';
import 'bilibili_client.dart';
import 'bilibili_constants.dart';
import 'api_endpoints.dart';
import 'models.dart';
import 'danmaku_parser.dart';
import '../core/logger.dart';

class VideoApi {
  final BilibiliClient client;
  final Dio dio;

  VideoApi(this.client) : dio = client.dio;

  Future<Map<String, dynamic>> _wbiGet(String path, Map<String, dynamic> params) => client.wbiGet(path, params);

  Future<({String videoUrl, String? audioUrl})> getPlayUrl(String bvid, {int? qn}) async {
    final viewData = await _wbiGet(ApiEndpoints.view, {'bvid': bvid});
    final cid = viewData['data']?['cid'];
    if (cid == null) throw const BilibiliApiException('获取视频信息失败', path: ApiEndpoints.view);
    final target = qn ?? 80;
    final errors = <String>[];
    for (final fnval in [4048, 16]) {
      try {
        final playData = await _wbiGet(ApiEndpoints.playUrl, {
          'bvid': bvid,
          'cid': cid,
          'qn': target,
          'fnval': fnval,
          'fnver': 0,
          'fourk': 1,
          'try_look': 1,
          'web_location': 1315873,
          ..._dmImgParams(),
        });
        final data = playData['data'] as Map<String, dynamic>?;
        final dash = data?['dash'] as Map<String, dynamic>?;
        if (dash != null) {
          final videos = (dash['video'] as List?) ?? [];
          final audios = (dash['audio'] as List?) ?? [];
          if (videos.isNotEmpty) {
            Map<String, dynamic>? chosen;
            for (final v in videos.cast<Map<String, dynamic>>()) {
              if (v['id'] == target) { chosen = v; break; }
            }
            chosen ??= videos.first as Map<String, dynamic>;
            final vUrl = (chosen['baseUrl'] ?? chosen['base_url']) as String?;
            final aUrl = audios.isNotEmpty
                ? (audios.first as Map<String, dynamic>)['baseUrl'] as String? ?? (audios.first as Map<String, dynamic>)['base_url'] as String?
                : null;
            if (vUrl != null && vUrl.isNotEmpty) {
              return (videoUrl: vUrl, audioUrl: aUrl);
            }
          }
        }
        final durl = data?['durl'] as List?;
        if (durl != null && durl.isNotEmpty) {
          final u = (durl.first as Map<String, dynamic>)['url'] as String?;
          if (u != null && u.isNotEmpty) return (videoUrl: u, audioUrl: null);
        }
      } catch (e) {
        errors.add('fnval=$fnval: $e');
      }
    }
    throw BilibiliApiException('获取播放地址失败：${errors.join(' | ')}', path: ApiEndpoints.playUrl);
  }

  Map<String, dynamic> _dmImgParams() {
    const vendors = ['AMD', 'Intel', 'NVIDIA'];
    const gpus = ['AMD Radeon RX 6700 XT', 'AMD Radeon RX 6600', 'Intel(R) UHD Graphics 630', 'Intel(R) Iris(R) Xe Graphics', 'NVIDIA GeForce RTX 3060', 'NVIDIA GeForce RTX 4060 Laptop GPU', 'NVIDIA GeForce GTX 1650 Ti'];
    final r = Random();
    final vendor = vendors[r.nextInt(vendors.length)];
    final gpu = gpus[r.nextInt(gpus.length)];
    final webgl = 'WebGL 1.0 (OpenGL ES 2.0 Chromium)';
    final angle = 'ANGLE ($vendor, $gpu Direct3D11 vs_5_0 ps_5_0, D3D11)Google Inc. ($vendor)';
    // 模拟常见浏览器窗口分辨率抖动范围（1920±60 宽、1080±90 高），
    // 以及随机渲染偏移量 of/o 与整体随机种子 rnd，用于通过 B 站播放接口的 dm_img 风控校验
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

  Future<List<SearchUser>> searchUsers(String keyword) async {
    if (keyword.trim().isEmpty) return [];
    await client.device.ensureBuvid();
    final params = <String, dynamic>{
      'search_type': 'bili_user',
      'keyword': keyword,
      'page': 1,
      'page_size': 20,
      'platform': 'pc',
      'web_location': 1430654,
    };
    final signed = await client.wbi.sign(params);
    final enc = Uri.encodeComponent(keyword);
    final resp = await dio.get(ApiEndpoints.searchType,
      queryParameters: signed,
      options: Options(headers: client.auth.requestHeaders(extra: {
        'origin': 'https://search.bilibili.com',
        'referer': 'https://search.bilibili.com/bili_user?keyword=$enc',
      })));
    final body = resp.data as Map<String, dynamic>;
    final voucher = (body['data'] as Map<String, dynamic>?)?['v_voucher'] as String?;
    if (voucher != null && voucher.isNotEmpty) {
      throw const RiskControlException('搜索触发风控，请登录后重试');
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
  }

  Future<List<DanmakuItem>> getDanmaku(String bvid, {int durationSec = 0}) async {
    try {
      final view = await _wbiGet(ApiEndpoints.view, {'bvid': bvid});
      final cid = view['data']?['cid'];
      if (cid == null) return [];
      final segCount = durationSec > 0 ? ((durationSec / 360).ceil() + 1).clamp(1, 30) : 20;
      final results = await Future.wait(
        List.generate(segCount, (i) => _fetchDanmakuSeg(cid as int, i + 1, bvid)),
      );
      final all = results.expand((e) => e).toList();
      all.sort((a, b) => a.time.compareTo(b.time));
      KzvLogger.debug('danmaku cid=$cid segs=$segCount count=${all.length}');
      return all;
    } catch (e) {
      KzvLogger.debug('getDanmaku failed: $e');
      return [];
    }
  }

  Future<List<DanmakuItem>> _fetchDanmakuSeg(int cid, int seg, String bvid) async {
    try {
      final resp = await dio.get(
        ApiEndpoints.danmakuSeg,
        queryParameters: {'type': 1, 'oid': cid, 'segment_index': seg},
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (s) => s != null && s < 400,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://www.bilibili.com/video/$bvid',
            'Cache-Control': 'no-cache',
          },
        ),
      );
      final bytes = (resp.data as List).cast<int>();
      if (bytes.isEmpty) return [];
      return DanmakuParser.parse(bytes);
    } catch (e) {
      KzvLogger.debug('danmaku segment fetch failed: $e');
      return [];
    }
  }

  Future<List<({int mid, String name, String face})>> getVideoStaff(String bvid) async {
    try {
      final data = await _wbiGet(ApiEndpoints.view, {'bvid': bvid});
      final staff = (data['data']?['staff'] as List?) ?? [];
      return staff
          .whereType<Map<String, dynamic>>()
          .map((e) => (
                mid: e['mid'] as int? ?? 0,
                name: e['name'] as String? ?? '',
                face: ((e['face'] as String?) ?? '').replaceFirst('http://', 'https://'),
              ))
          .where((e) => e.mid > 0)
          .toList();
    } catch (e) {
      KzvLogger.debug('getVideoStaff failed: $e');
      return [];
    }
  }

  Future<List<VideoInfo>> getUpVideos(int mid, {int tid = 0, int pn = 1, int cursor = 0}) async {
    final web = await _getUpVideosWeb(mid, tid, pn);
    if (web.isNotEmpty) return web;
    return _getUpVideosApp(mid, tid, cursor: cursor);
  }

  Future<({String name, String face, int fans, String banner})?> getUserInfo(int mid) async {
    final cardF = _getUserCard(mid);
    final wbiF = _getUserInfoWeb(mid);
    final card = await cardF;
    final wbi = await wbiF;
    if (wbi == null && card == null) return null;
    final name = (wbi != null && wbi.name.isNotEmpty) ? wbi.name : (card?.name ?? '');
    final face = (wbi != null && wbi.face.isNotEmpty) ? wbi.face : (card?.face ?? '');
    final fans = (wbi != null && wbi.fans > 0) ? wbi.fans : (card?.fans ?? 0);
    return (name: name, face: face, fans: fans, banner: wbi?.banner ?? card?.banner ?? '');
  }

  Future<({String name, String face, int fans, String banner})?> _getUserCard(int mid) async {
    try {
      await client.device.ensureBuvid();
      final resp = await dio.get(ApiEndpoints.card, queryParameters: {'mid': mid, 'photo': true}, options: Options(headers: client.auth.requestHeaders()));
      final body = resp.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final card = data?['card'] as Map<String, dynamic>?;
      if (card == null) return null;
      final space = card['space'] as Map<String, dynamic>?;
      return (
        name: card['name'] as String? ?? '',
        face: ((card['face'] as String?) ?? '').replaceFirst('http://', 'https://'),
        fans: (card['fans'] as int?) ?? (data?['follower'] as int?) ?? 0,
        banner: ((space?['l_img'] as String?) ?? '').replaceFirst('http://', 'https://'),
      );
    } catch (e) {
      KzvLogger.debug('getUserCard failed: $e');
      return null;
    }
  }

  Future<({String name, String face, int fans, String banner})?> _getUserInfoWeb(int mid) async {
    try {
      final data = await _wbiGet(ApiEndpoints.spaceAccInfo, {
        'mid': mid,
        'token': '',
        'platform': 'web',
        'web_location': '1550101',
        ..._dmImgParams(),
      });
      final card = data['data'] as Map<String, dynamic>?;
      if (card == null) return null;
      return (
        name: card['name'] as String? ?? '',
        face: ((card['face'] as String?) ?? '').replaceFirst('http://', 'https://'),
        fans: card['fans'] as int? ?? 0,
        banner: ((card['top_photo'] as String?) ?? '').replaceFirst('http://', 'https://'),
      );
    } catch (e) {
      KzvLogger.debug('getUserInfoWeb failed: $e');
      return null;
    }
  }

  Future<({String name, String face, int fans, String banner})?> getUpInfoByVideo(String bvid) async {
    try {
      final view = await _wbiGet(ApiEndpoints.view, {'bvid': bvid});
      final owner = view['data']?['owner'] as Map<String, dynamic>?;
      if (owner == null) return null;
      return (
        name: owner['name'] as String? ?? '',
        face: ((owner['face'] as String?) ?? '').replaceFirst('http://', 'https://'),
        fans: 0,
        banner: '',
      );
    } catch (e) {
      KzvLogger.debug('getUpInfoByVideo failed: $e');
      return null;
    }
  }

  Future<List<VideoInfo>> _getUpVideosWeb(int mid, int tid, int pn) async {
    try {
      final data = await _wbiGet(ApiEndpoints.spaceArcSearch, {'mid': mid, 'ps': 30, 'tid': tid, 'pn': pn, 'keyword': '', 'order': 'pubdate', 'platform': 'web'});
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
        aid: (e['aid'] as int?) ?? 0,
      )).where((v) => v.bvid.isNotEmpty).toList();
    } catch (e) {
      KzvLogger.debug('getUpVideosWeb failed: $e');
      return [];
    }
  }

  Future<List<VideoInfo>> _getUpVideosApp(int mid, int tid, {int cursor = 0}) async {
    try {
      final params = <String, dynamic>{
        'vmid': mid,
        'order': 'pubdate',
        'tid': tid,
        'mobi_app': 'android',
        'platform': 'android',
        'ps': 30,
        if (cursor > 0) 'aid': cursor,
      };
      AppSign.appSign(params);
      final resp = await dio.get(ApiEndpoints.spaceArchiveCursor, queryParameters: params, options: Options(headers: {
        'User-Agent': BiliConstants.appUserAgent,
        'Referer': 'https://www.bilibili.com/',
      }));
      final items = (resp.data?['data']?['item'] as List?) ?? [];
      return items.map((e) {
        final lenVal = e['length'];
        final durVal = e['duration'];
        final stat = e['stat'];
        final param = e['param'];
        return VideoInfo(
          bvid: e['bvid'] as String? ?? '',
          title: (e['title'] as String?) ?? '',
          pic: ((e['cover'] as String?) ?? '').replaceFirst('http://', 'https://'),
          duration: durVal is int && durVal > 0 ? durVal : (lenVal is String ? _parseLength(lenVal) : 0),
          owner: (e['author'] as String?) ?? '',
          view: stat is Map<String, dynamic> ? (stat['play'] as int? ?? 0) : ((e['play'] as int?) ?? 0),
          pubdate: (e['ctime'] as int?) ?? (e['pubdate'] as int?) ?? 0,
          mid: mid,
          tid: (e['tid'] as int?) ?? 0,
          aid: param is int ? param : (param is String ? int.tryParse(param) ?? 0 : 0),
        );
      }).where((v) => v.bvid.isNotEmpty).toList();
    } catch (e) {
      KzvLogger.debug('getUpVideosApp failed: $e');
      return [];
    }
  }

  int _parseLength(String l) {
    final parts = l.split(':');
    var sec = 0;
    for (final p in parts) { sec = sec * 60 + (int.tryParse(p) ?? 0); }
    return sec;
  }

  Future<List<SubtitleCue>?> getSubtitles(String bvid) async {
    try {
      final viewData = await _wbiGet(ApiEndpoints.view, {'bvid': bvid});
      final cid = viewData['data']?['cid'];
      if (cid == null) return null;
      final playData = await _wbiGet(ApiEndpoints.playV2, {'bvid': bvid, 'cid': cid, 'fnval': 16});
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
    } catch (e) {
      KzvLogger.debug('getSubtitles failed: $e');
      return null;
    }
  }
}