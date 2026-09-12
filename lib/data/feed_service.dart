import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'bilibili_client.dart';
import 'api_endpoints.dart';
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
        final resp = await dio.get(ApiEndpoints.recommend, queryParameters: {'fresh_type': 3, 'fresh_idx': b}, options: Options(headers: client.auth.requestHeaders()));
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

  Future<List<VideoInfo>> getHotVideos({int pn = 1, int limit = 0}) async {
    try {
      final data = await client.wbiGet(ApiEndpoints.popular, {'pn': pn, 'ps': 30});
      final minDuration = store.minDurationOf('hot');
      final blacklist = await _getBlacklistSet();
      final watched = store.watched.toSet();
      var list = _parseVideoList(data['data']?['list'] as List? ?? [])
          .where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid) && !watched.contains(v.bvid))
          .toList();
      if (limit > 0 && list.length > limit) list = list.sublist(0, limit);
      return list;
    } catch (e) {
      KzvLogger.debug('hot pn=$pn failed: $e');
      return [];
    }
  }

  Future<List<VideoInfo>> _fetchPopular() async {
    final all = <VideoInfo>[];
    for (var pn = 1; pn <= 8; pn++) {
      try {
        final data = await client.wbiGet(ApiEndpoints.popular, {'pn': pn, 'ps': 30});
        all.addAll(_parseVideoList(data['data']?['list'] as List? ?? []));
      } catch (e) {
        KzvLogger.debug('popular pn=$pn failed: $e');
      }
    }
    return all;
  }

  Future<List<VideoInfo>> _fetchRanking(int ridMain) async {
    try {
      final data = await client.wbiGet(ApiEndpoints.ranking, {'rid': ridMain, 'type': 'all'});
      return _parseVideoList(data['data']?['list'] as List? ?? []);
    } catch (e) {
      KzvLogger.debug('ranking rid=$ridMain failed: $e');
      return [];
    }
  }

  Future<List<VideoInfo>> _fetchSubVideos(int ridMain, {int perUp = 30}) async {
    final subs = await store.subscriptions;
    final filterMid = store.subFilterMid;
    final all = <VideoInfo>[];
    for (final sub in subs) {
      final mid = sub['mid'];
      if (mid is int && (filterMid == 0 || mid == filterMid)) {
        final upVideos = await videoApi.getUpVideos(mid, tid: ridMain);
        all.addAll(upVideos.take(perUp));
      }
    }
    return all;
  }

  List<VideoInfo> _interleaveByUp(List<VideoInfo> videos) {
    final byUp = <int, List<VideoInfo>>{};
    for (final v in videos) {
      byUp.putIfAbsent(v.mid, () => []).add(v);
    }
    for (final list in byUp.values) {
      list.sort((a, b) => b.pubdate.compareTo(a.pubdate));
    }
    final upIds = byUp.keys.toList()..shuffle(Random());
    final picked = <VideoInfo>[];
    var round = 0;
    while (upIds.any((id) => round < byUp[id]!.length)) {
      for (final id in upIds) {
        final list = byUp[id]!;
        if (round < list.length) picked.add(list[round]);
      }
      round++;
    }
    return picked;
  }

  Future<List<VideoInfo>> getDailyVideos({bool force = false, int offset = 0}) async {
    final ridKey = store.rid;
    final minDuration = store.minDurationOf(ridKey);
    final count = store.recommendCountOf(ridKey);
    final ridMain = _ridMain(ridKey);
    final today = _today();
    final key = ridKey == 'sub' ? 'daily_${ridKey}_${today}_o$offset' : 'daily_${ridKey}_$today';
    final tsKey = ridKey == 'sub' ? 'daily_ts_${ridKey}_${today}_o$offset' : 'daily_ts_${ridKey}_$today';
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
        } catch (e) {
          KzvLogger.debug('daily cache parse failed: $e');
        }
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
          final chosen = picked.take(count).toList();
          KzvLogger.debug('daily(rcmd) min=$minDuration items=${rcmdFiltered.length} chosen=${chosen.length}');
          if (chosen.isNotEmpty) {
            await store.setDailyCache(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
            await store.setDailyTs(tsKey, now);
          }
          return chosen;
        }
      }
    }
    if (ridKey == 'sub') {
      final subVideos = await _fetchSubVideos(ridMain);
      final subFiltered = subVideos.where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid) && !watched.contains(v.bvid)).toList();
      final interleaved = _interleaveByUp(subFiltered);
      var chosen = interleaved.skip(offset).take(count).toList();
      if (chosen.isEmpty && offset > 0) {
        chosen = interleaved.take(count).toList();
      }
      KzvLogger.debug('daily(sub) min=$minDuration sub=${subFiltered.length} interleaved=${interleaved.length} offset=$offset chosen=${chosen.length}');
      if (chosen.isNotEmpty) {
        await store.setDailyCache(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
        await store.setDailyTs(tsKey, now);
      }
      return chosen;
    }
    final List<VideoInfo> popular = ridMain == 0 ? await _fetchPopular() : await _fetchRanking(ridMain);
    if (ridKey == 'hot') {
      final filtered = popular.where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid) && !watched.contains(v.bvid)).toList();
      final chosen = filtered.take(count).toList();
      KzvLogger.debug('daily(hot) min=$minDuration popular=${filtered.length} chosen=${chosen.length}');
      if (chosen.isNotEmpty) {
        await store.setDailyCache(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
        await store.setDailyTs(tsKey, now);
      }
      return chosen;
    }
    final popularFiltered = popular.where((v) => v.duration >= minDuration && !blacklist.contains(v.bvid) && !watched.contains(v.bvid)).toList()
      ..sort((a, b) => b.pubdate.compareTo(a.pubdate));
    final picked = popularFiltered.take(popularPickLimit).toList()..shuffle(Random());
    final chosen = picked.take(count).toList();
    KzvLogger.debug('daily min=$minDuration popular=${popularFiltered.length} chosen=${chosen.length}');
    if (chosen.isNotEmpty) {
      await store.setDailyCache(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
      await store.setDailyTs(tsKey, now);
    }
    return chosen;
  }
}