import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'app_sign.dart';
import 'bilibili_client.dart';
import 'models.dart';
import '../core/logger.dart';

class VideoApi {
  final BilibiliClient client;
  final Dio dio;

  VideoApi(this.client) : dio = client.dio;

  Future<Map<String, dynamic>> _wbiGet(String path, Map<String, dynamic> params) => client.wbiGet(path, params);

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
    final resp = await dio.get('/x/web-interface/wbi/search/type',
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
      KzvLogger.debug('getUpVideosWeb failed: $e');
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
}