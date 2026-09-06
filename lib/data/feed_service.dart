import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'bilibili_client.dart';
import 'local_store.dart';
import 'models.dart';
import 'video_api.dart';
import '../core/logger.dart';

class FeedService {
  final BilibiliClient client;
  final LocalStore store;
  final VideoApi videoApi;
  final Dio dio;

  static const int cacheValidMs = 6 * 3600 * 1000;
  static const int dailyChosenCount = 10;
  static const int rcmdPickLimit = 20;
  static const int popularPickLimit = 40;
  static const int rcmdMaxItems = 60;

  FeedService(this.client, this.store, this.videoApi) : dio = client.dio;

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

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<Set<String>> _getBlacklistSet() async {
    return store.blacklist.map((e) => e['bvid'] as String? ?? '').where((s) => s.isNotEmpty).toSet();
  }

  List<VideoInfo> _parseVideoList(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map((e) => VideoInfo(
      bvid: (e['bvid'] as String?) ?? '',
      title: (e['title'] as String?) ?? '',
      pic: ((e['pic'] as String?) ?? '').replaceFirst('http://', 'https://'),
      duration: (e['duration'] as int?) ?? 0,
      owner: ((e['owner'] as Map<String, dynamic>?)?['name'] as String?) ?? '',
      view: ((e['stat'] as Map<String, dynamic>?)?['view'] as int?) ?? 0,
      pubdate: (e['pubdate'] as int?) ?? 0,
      mid: ((e['owner'] as Map<String, dynamic>?)?['mid'] as int?) ?? 0,
      tid: (e['tid'] as int?) ?? 0,
    )).where((v) => v.bvid.isNotEmpty).toList();
  }

  Future<List<VideoInfo>> _getRcmdVideos({int batch = 5}) async {
    try {
      await client.device.ensureBuvid();
      final all = <VideoInfo>[];
      for (var b = 0; b < batch && all.length < rcmdMaxItems; b++) {
        final resp = await dio.get('/x/web-interface/index/top/rcmd', queryParameters: {'fresh_type': 3, 'fresh_idx': b}, options: Options(headers: client.auth.requestHeaders()));
        final body = resp.data as Map<String, dynamic>;
        final code = body['code'];
        if (code is int && code != 0) {
          KzvLogger.warning('rcmd error code=$code msg=${body['message']}');
          return all;
        }
        final items = (body['data']?['item'] as List?) ?? [];
        final avItems = items.where((e) => e is Map<String, dynamic> && e['goto'] == 'av' && e['owner'] != null).toList();
        for (final v in _parseVideoList(avItems)) {
          if (all.any((x) => x.bvid == v.bvid)) continue;
          all.add(v);
        }
        if (items.isEmpty) break;
      }
      KzvLogger.debug('rcmd total=${all.length}');
      return all;
    } catch (e) {
      KzvLogger.debug('rcmd failed: $e');
      return [];
    }
  }

  Future<List<VideoInfo>> _fetchPopular() async {
    final all = <VideoInfo>[];
    for (var pn = 1; pn <= 8; pn++) {
      try {
        final data = await client.wbiGet('/x/web-interface/popular', {'pn': pn, 'ps': 30});
        all.addAll(_parseVideoList(data['data']?['list'] as List? ?? []));
      } catch (e) {
        KzvLogger.debug('popular pn=$pn failed: $e');
      }
    }
    return all;
  }

  Future<List<VideoInfo>> _fetchRanking(int ridMain) async {
    try {
      final data = await client.wbiGet('/x/web-interface/ranking/v2', {'rid': ridMain, 'type': 'all'});
      return _parseVideoList(data['data']?['list'] as List? ?? []);
    } catch (e) {
      KzvLogger.debug('ranking rid=$ridMain failed: $e');
      return [];
    }
  }

  Future<List<VideoInfo>> _fetchSubVideos(int ridMain, {int perUp = 5}) async {
    final subs = await store.subscriptions;
    final all = <VideoInfo>[];
    for (final sub in subs) {
      final mid = sub['mid'];
      if (mid is int) {
        final upVideos = await videoApi.getUpVideos(mid, tid: ridMain);
        all.addAll(upVideos.take(perUp));
      }
    }
    return all;
  }

  Future<List<VideoInfo>> getDailyVideos({bool force = false}) async {
    final ridKey = store.rid;
    final minDuration = store.minDurationOf(ridKey);
    final ridMain = _ridMain(ridKey);
    final today = _today();
    final key = 'daily_${ridKey}_$today';
    final tsKey = 'daily_ts_${ridKey}_$today';
    final now = DateTime.now().millisecondsSinceEpoch;
    final blacklist = await _getBlacklistSet();
    final watched = store.watched.toSet();
    if (!force) {
      final cachedTs = store.getDailyTs(tsKey);
      final cached = store.getDailyCache(key);
      if (cached != null && cachedTs != null && (now - cachedTs) < cacheValidMs) {
        try {
          final list = (jsonDecode(cached) as List).map((e) => VideoInfo.fromJson(e as Map<String, dynamic>))
            .where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid) && !watched.contains(v.bvid)).toList();
          if (list.isNotEmpty) return list;
        } catch (_) {}
      }
    }
    if (ridKey != 'sub') {
      final rcmdOn = store.rcmdEnabled;
      if (rcmdOn && ridKey == '') {
        final batch = store.rcmdBatch;
        final rcmdVideos = await _getRcmdVideos(batch: batch);
        final rcmdFiltered = rcmdVideos.where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid) && !watched.contains(v.bvid)).toList();
        KzvLogger.debug('rcmd raw=${rcmdVideos.length} filtered=$minDuration→${rcmdFiltered.length}');
        if (rcmdFiltered.isNotEmpty) {
          final picked = rcmdFiltered.take(rcmdPickLimit).toList()..shuffle(Random());
          final chosen = picked.take(dailyChosenCount).toList();
          KzvLogger.debug('daily(rcmd) min=$minDuration items=${rcmdFiltered.length} chosen=${chosen.length}');
          if (chosen.isNotEmpty) {
            await store.setDailyCache(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
            await store.setDailyTs(tsKey, now);
          }
          return chosen;
        }
      }
    }
    final List<VideoInfo> popular = ridMain == 0 ? await _fetchPopular() : await _fetchRanking(ridMain);
    if (ridKey == 'sub') {
      final subVideos = await _fetchSubVideos(ridMain);
      final subFiltered = subVideos.where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid) && !watched.contains(v.bvid)).toList()
        ..sort((a, b) => b.pubdate.compareTo(a.pubdate));
      final chosen = subFiltered.take(dailyChosenCount).toList();
      KzvLogger.debug('daily(sub) min=$minDuration perUp=5 sub=${subFiltered.length} chosen=${chosen.length}');
      if (chosen.isNotEmpty) {
        await store.setDailyCache(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
        await store.setDailyTs(tsKey, now);
      }
      return chosen;
    }
    final popularFiltered = popular.where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid) && !watched.contains(v.bvid)).toList()
      ..sort((a, b) => b.pubdate.compareTo(a.pubdate));
    final picked = popularFiltered.take(popularPickLimit).toList()..shuffle(Random());
    final chosen = picked.take(dailyChosenCount).toList();
    KzvLogger.debug('daily min=$minDuration popular=${popularFiltered.length} chosen=${chosen.length}');
    if (chosen.isNotEmpty) {
      await store.setDailyCache(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
      await store.setDailyTs(tsKey, now);
    }
    return chosen;
  }
}