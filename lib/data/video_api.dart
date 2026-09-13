import 'package:dio/dio.dart';
import 'app_sign.dart';
import 'api_endpoints.dart';
import 'bilibili_constants.dart';
import 'models.dart';
import '../core/logger.dart';
import 'api/api_base.dart';

class VideoApi extends ApiBase {
  VideoApi(super.client);

  Future<List<({int mid, String name, String face})>> getVideoStaff(String bvid) async {
    try {
      final data = await wbiGet(ApiEndpoints.view, {'bvid': bvid});
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

  Future<({String name, String face, int fans, String banner})?> getUpInfoByVideo(String bvid) async {
    try {
      final view = await wbiGet(ApiEndpoints.view, {'bvid': bvid});
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
      final data = await wbiGet(ApiEndpoints.spaceArcSearch, {'mid': mid, 'ps': 30, 'tid': tid, 'pn': pn, 'keyword': '', 'order': 'pubdate', 'platform': 'web'});
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
}
