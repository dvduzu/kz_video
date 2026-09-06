import 'dart:async';
import 'package:dio/dio.dart';
import 'auth_repository.dart';
import 'bilibili_client.dart';
import 'feed_service.dart';
import 'local_store.dart';
import 'models.dart';
import 'video_api.dart';

// 本文件是 Facade，只做委托和最基础的本地 CRUD。
// 新的业务规则（判断逻辑、多步骤编排）请写进对应的 XxxRepository/XxxService，
// 这里只允许出现 "调用某个 service 的方法" 这种单行委托。
class VideoRepository {
  static VideoRepository? _instance;
  static VideoRepository instance() => _instance!;
  static void init(VideoRepository repo) => _instance = repo;

  bool get isLoggedIn => client.auth.isLoggedIn;
  bool get hasAccount => client.auth.hasAccount;
  bool get guestMode => client.auth.guestMode;
  String get loginName => client.auth.loginName;
  int get loginAt => client.auth.loginAt;
  int get sessExpires => client.auth.sessExpires;
  LocalStore get settings => store;
  Future<void> setGuestMode(bool enabled) async {
    await client.auth.setGuestMode(enabled);
    await store.setGuestMode(enabled);
  }

  final BilibiliClient client;
  final LocalStore store;
  final Dio dio;
  final AuthRepository auth;
  final VideoApi videoApi;
  late final FeedService feed;

  VideoRepository._(this.client, this.store) : dio = client.dio, auth = AuthRepository(client, store), videoApi = VideoApi(client) {
    feed = FeedService(client, store, videoApi);
  }

  static Future<VideoRepository> create() async {
    final client = BilibiliClient(BilibiliClient.createDio());
    final store = await LocalStore.create();
    return VideoRepository._(client, store);
  }

  Future<({String key, String url})?> webQrGenerate() => auth.webQrGenerate();
  Future<bool> webQrPoll(String key) => auth.webQrPoll(key);
  Stream<bool> webQrLoginFlow(String key) => auth.webQrLoginFlow(key);
  Future<bool> loginWithCookie(String cookieHeader) => auth.loginWithCookie(cookieHeader);
  Future<void> restoreLogin() => auth.restoreLogin();
  Future<void> logout() => auth.logout();
  Future<String> getPlayUrl(String bvid, {int? qn}) => videoApi.getPlayUrl(bvid, qn: qn);
  Future<List<SearchUser>> searchUsers(String keyword) => videoApi.searchUsers(keyword);
  Future<List<VideoInfo>> getUpVideos(int mid, {int tid = 0}) => videoApi.getUpVideos(mid, tid: tid);
  Future<List<SubtitleCue>?> getSubtitles(String bvid) => videoApi.getSubtitles(bvid);
  Future<List<VideoInfo>> getDailyVideos({bool force = false}) => feed.getDailyVideos(force: force);

  String? get buvid3 => client.auth.buvid3;

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
    if (list.length > LocalStore.maxHistoryItems) list.removeRange(LocalStore.maxHistoryItems, list.length);
    await store.setHistory(list);
  }

  Future<List<VideoInfo>> getHistory() async {
    return store.history.map((e) {
      try { return VideoInfo.fromJson(e); } catch (_) { return null; }
    }).whereType<VideoInfo>().toList();
  }

  Future<void> removeHistory(String bvid) async {
    final list = store.history;
    list.removeWhere((e) => e['bvid'] == bvid);
    await store.setHistory(list);
  }

  Future<bool> addWatchLater(VideoInfo v) async {
    if (!await isWatchLaterEnabled()) return false;
    final list = store.watchLater;
    if (!list.any((e) => e['bvid'] == v.bvid)) {
      if (list.length >= LocalStore.maxWatchLaterItems) return false;
      list.add(v.toJson());
      await store.setWatchLater(list);
    }
    return true;
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
    if (list.length >= LocalStore.maxSubscriptions) return false;
    list.add({'mid': mid, 'name': name, 'face': face});
    await store.setSubscriptions(list);
    await store.clearDailyCacheFor('sub');
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
    await store.clearDailyCacheFor('sub');
  }

  Future<void> markWatched(String bvid) async {
    final list = store.watched;
    if (!list.contains(bvid)) {
      list.add(bvid);
      await store.setWatched(list);
    }
  }

  Future<Set<String>> getWatchedSet() async => store.watched.toSet();

  Future<void> clearWatched() async {
    await store.setWatched([]);
  }

  Future<void> clearDailyCache() => store.clearAllDailyCache();

  Map<String, dynamic> exportData() => store.exportData();

  Future<void> importData(Map<String, dynamic> data) async {
    await store.importData(data);
    await client.auth.setGuestMode(store.guestMode);
    await store.clearAllDailyCache();
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<bool> canRefreshToday() async {
    return store.unlimitedRefresh || store.getRefreshCount(_today()) < 5;
  }

  bool get unlimitedRefresh => store.unlimitedRefresh;
  Future<void> setUnlimitedRefresh(bool v) => store.setUnlimitedRefresh(v);

  Future<void> recordRefresh() async {
    final today = _today();
    await store.setRefreshCount(today, store.getRefreshCount(today) + 1);
  }

  Future<void> resetRefreshCount() async {
    await store.setRefreshCount(_today(), 0);
  }
}
