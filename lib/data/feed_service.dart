import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'bilibili_client.dart';
import 'api_endpoints.dart';
import 'models.dart';
import 'video_api.dart';
import 'store/blacklist_store.dart';
import 'store/feed_cache_store.dart';
import 'store/playback_store.dart';
import 'store/settings_store.dart';
import 'store/subscription_store.dart';
import '../core/logger.dart';

class FeedService {
  final BilibiliClient client;
  final VideoApi videoApi;
  final SettingsStore settings;
  final PlaybackStore playback;
  final BlacklistStore blacklist;
  final SubscriptionStore subscriptions;
  final FeedCacheStore feedCache;
  final Dio dio;

  static const int cacheValidMs = 6 * 3600 * 1000;
  static const int dailyChosenCount = 10;
  static const int rcmdPickLimit = 20;
  static const int popularPickLimit = 40;
  static const int rcmdMaxItems = 60;

  FeedService(this.client, this.videoApi, this.settings, this.playback, this.blacklist, this.subscriptions, this.feedCache) : dio = client.dio;

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

  Set<String> _blacklistSet() {
    return blacklist.items.map((e) => e['bvid'] as String? ?? '').where((s) => s.isNotEmpty).toSet();
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
      final minDuration = settings.minDurationOf('hot');
      final blacklistSet = _blacklistSet();
      final watched = playback.watched.toSet();
      var list = _parseVideoList(data['data']?['list'] as List? ?? [])
          .where((v) => v.duration >= minDuration && !blacklistSet.contains(v.bvid) && !watched.contains(v.bvid))
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
    for (var pn = 1; pn <= 12; pn++) {
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

  Future<List<VideoInfo>> _fetchSubVideos(int ridMain, {int want = 30}) async {
    final subs = subscriptions.items;
    final filterMid = settings.subFilterMid;
    final seen = <String>{};
    final all = <VideoInfo>[];
    for (final sub in subs) {
      final mid = sub['mid'];
      if (mid is! int || (filterMid != 0 && mid != filterMid)) continue;
      var pn = 1;
      var cursor = 0;
      var fetched = 0;
      while (fetched < want) {
        final page = await videoApi.getUpVideos(mid, tid: ridMain, pn: pn, cursor: cursor);
        if (page.isEmpty) break;
        var added = 0;
        for (final v in page) {
          if (seen.add(v.bvid)) {
            all.add(v);
            added++;
          }
        }
        fetched += page.length;
        cursor = page.last.aid;
        pn++;
        if (added == 0) break;
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
    final ridKey = settings.rid;
    final minDuration = settings.minDurationOf(ridKey);
    final count = settings.recommendCountOf(ridKey);
    final ridMain = _ridMain(ridKey);
    final today = _today();
    final key = ridKey == 'sub' ? 'daily_${ridKey}_${today}_o$offset' : 'daily_${ridKey}_$today';
    final tsKey = ridKey == 'sub' ? 'daily_ts_${ridKey}_${today}_o$offset' : 'daily_ts_${ridKey}_$today';
    final now = DateTime.now().millisecondsSinceEpoch;
    final blacklistSet = _blacklistSet();
    final watched = playback.watched.toSet();
    if (!force) {
      final cachedTs = feedCache.getDailyTs(tsKey);
      final cached = feedCache.getDailyCache(key);
      if (cached != null && cachedTs != null && (now - cachedTs) < cacheValidMs) {
        try {
          final list = (jsonDecode(cached) as List).map((e) => VideoInfo.fromJson(e as Map<String, dynamic>))
            .where((v) => v.duration >= minDuration && !blacklistSet.contains(v.bvid) && !watched.contains(v.bvid)).toList();
          if (list.isNotEmpty) return list;
        } catch (e) {
          KzvLogger.debug('daily cache parse failed: $e');
        }
      }
    }
    if (ridKey != 'sub') {
      final rcmdOn = settings.rcmdEnabled;
      if (rcmdOn && ridKey == '') {
        final batch = settings.rcmdBatch;
        final rcmdVideos = await _getRcmdVideos(batch: batch);
        final rcmdFiltered = rcmdVideos.where((v) => v.duration >= minDuration && !blacklistSet.contains(v.bvid) && !watched.contains(v.bvid)).toList();
        KzvLogger.debug('rcmd raw=${rcmdVideos.length} filtered=$minDuration→${rcmdFiltered.length}');
        if (rcmdFiltered.isNotEmpty) {
          final rcmdPool = count > rcmdPickLimit ? count * 2 : rcmdPickLimit;
          final picked = rcmdFiltered.take(rcmdPool).toList()..shuffle(Random());
          final chosen = picked.take(count).toList();
          KzvLogger.debug('daily(rcmd) min=$minDuration items=${rcmdFiltered.length} chosen=${chosen.length}');
          if (chosen.isNotEmpty) {
            await feedCache.setDailyCache(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
            await feedCache.setDailyTs(tsKey, now);
          }
          return chosen;
        }
      }
    }
    if (ridKey == 'sub') {
      final subVideos = await _fetchSubVideos(ridMain, want: count * 3);
      final subFiltered = subVideos.where((v) => v.duration >= minDuration && !blacklistSet.contains(v.bvid) && !watched.contains(v.bvid)).toList();
      final interleaved = _interleaveByUp(subFiltered);
      var chosen = interleaved.skip(offset).take(count).toList();
      if (chosen.isEmpty && offset > 0) {
        chosen = interleaved.take(count).toList();
      }
      KzvLogger.debug('daily(sub) min=$minDuration sub=${subFiltered.length} interleaved=${interleaved.length} offset=$offset chosen=${chosen.length}');
      if (chosen.isNotEmpty) {
        await feedCache.setDailyCache(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
        await feedCache.setDailyTs(tsKey, now);
      }
      return chosen;
    }
    final List<VideoInfo> popular = ridMain == 0 ? await _fetchPopular() : await _fetchRanking(ridMain);
    if (ridKey == 'hot') {
      final filtered = popular.where((v) => v.duration >= minDuration && !blacklistSet.contains(v.bvid) && !watched.contains(v.bvid)).toList();
      final chosen = filtered.take(count).toList();
      KzvLogger.debug('daily(hot) min=$minDuration popular=${filtered.length} chosen=${chosen.length}');
      if (chosen.isNotEmpty) {
        await feedCache.setDailyCache(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
        await feedCache.setDailyTs(tsKey, now);
      }
      return chosen;
    }
    final popularFiltered = popular.where((v) => v.duration >= minDuration && !blacklistSet.contains(v.bvid) && !watched.contains(v.bvid)).toList()
      ..sort((a, b) => b.pubdate.compareTo(a.pubdate));
    final poolLimit = count > popularPickLimit ? count * 2 : popularPickLimit;
    final picked = popularFiltered.take(poolLimit).toList()..shuffle(Random());
    final chosen = picked.take(count).toList();
    KzvLogger.debug('daily min=$minDuration popular=${popularFiltered.length} chosen=${chosen.length}');
    if (chosen.isNotEmpty) {
      await feedCache.setDailyCache(key, jsonEncode(chosen.map((e) => e.toJson()).toList()));
      await feedCache.setDailyTs(tsKey, now);
    }
    return chosen;
  }

  Future<List<VideoInfo>> fetchSubscriptionTimeline({void Function(int done, int total)? onProgress}) async {
    final subs = subscriptions.items;
    final mids = subs.map((e) => e['mid']).whereType<int>().toList();
    final seen = <String>{};
    final all = <VideoInfo>[];
    var done = 0;
    for (final mid in mids) {
      try {
        final page = await videoApi.getUpVideos(mid);
        for (final v in page) {
          if (seen.add(v.bvid)) all.add(v);
        }
      } catch (e) {
        KzvLogger.debug('sub timeline mid=$mid failed: $e');
      }
      done++;
      onProgress?.call(done, mids.length);
    }
    all.sort((a, b) => b.pubdate.compareTo(a.pubdate));
    await feedCache.setSubTimeline(jsonEncode(all.map((e) => e.toJson()).toList()));
    await feedCache.setSubUpdatedAt(DateTime.now().millisecondsSinceEpoch);
    return all;
  }

  List<VideoInfo> cachedSubscriptionTimeline() {
    final raw = feedCache.subTimeline;
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => VideoInfo.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
