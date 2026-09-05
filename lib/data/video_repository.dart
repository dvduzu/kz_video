import 'package:dio/dio.dart';
import 'auth_repository.dart';
import 'bilibili_client.dart';
import 'feed_service.dart';
import 'local_store.dart';
import 'models.dart';
import 'video_api.dart';

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

}
