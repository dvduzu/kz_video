import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/danmaku_api.dart';
import 'api/play_api.dart';
import 'api/search_api.dart';
import 'api/subtitle_api.dart';
import 'api/user_api.dart';
import 'auth_repository.dart';
import 'bilibili_client.dart';
import 'feed_service.dart';
import 'models.dart';
import 'repository/blacklist_repository.dart';
import 'repository/history_repository.dart';
import 'repository/playback_repository.dart';
import 'repository/subscription_repository.dart';
import 'repository/watch_later_repository.dart';
import 'store/blacklist_store.dart';
import 'store/feed_cache_store.dart';
import 'store/history_store.dart';
import 'store/playback_store.dart';
import 'store/settings_store.dart';
import 'store/subscription_store.dart';
import 'store/watch_later_store.dart';
import 'video_api.dart';

// 本文件是 Facade：委托 api/feed/领域 Repository。
class VideoRepository {
  static VideoRepository? _instance;
  static VideoRepository instance() => _instance!;
  static void init(VideoRepository repo) => _instance = repo;

  static const int exportSchemaVersion = 3;

  bool get isLoggedIn => client.auth.isLoggedIn;
  bool get hasAccount => client.auth.hasAccount;
  bool get guestMode => client.auth.guestMode;
  String get loginName => client.auth.loginName;
  int get loginAt => client.auth.loginAt;
  int get sessExpires => client.auth.sessExpires;

  Future<void> setGuestMode(bool enabled) async {
    await client.auth.setGuestMode(enabled);
    await settings.setGuestMode(enabled);
  }

  final BilibiliClient client;
  final SettingsStore settings;
  final FeedCacheStore feedCache;
  final Dio dio;
  final AuthRepository auth;
  final PlayApi playApi;
  final VideoApi videoApi;
  final UserApi userApi;
  final SearchApi searchApi;
  final DanmakuApi danmakuApi;
  final SubtitleApi subtitleApi;
  final HistoryRepository history;
  final WatchLaterRepository watchLater;
  final SubscriptionRepository subscriptions;
  final BlacklistRepository blacklist;
  final PlaybackRepository playback;
  late final FeedService feed;

  VideoRepository._(this.client, this.settings, HistoryStore historyStore, WatchLaterStore watchLaterStore, SubscriptionStore subscriptionStore, BlacklistStore blacklistStore, PlaybackStore playbackStore, this.feedCache)
      : dio = client.dio,
        auth = AuthRepository(client, settings),
        playApi = PlayApi(client),
        videoApi = VideoApi(client),
        userApi = UserApi(client),
        searchApi = SearchApi(client),
        danmakuApi = DanmakuApi(client),
        subtitleApi = SubtitleApi(client),
        history = HistoryRepository(historyStore, settings),
        watchLater = WatchLaterRepository(watchLaterStore, settings),
        subscriptions = SubscriptionRepository(subscriptionStore, feedCache),
        blacklist = BlacklistRepository(blacklistStore),
        playback = PlaybackRepository(playbackStore) {
    feed = FeedService(client, videoApi, settings, playbackStore, blacklistStore, subscriptionStore, feedCache);
  }

  static Future<VideoRepository> create() async {
    final client = BilibiliClient(BilibiliClient.createDio());
    final p = await SharedPreferences.getInstance();
    return VideoRepository._(
      client,
      SettingsStore(p),
      HistoryStore(p),
      WatchLaterStore(p),
      SubscriptionStore(p),
      BlacklistStore(p),
      PlaybackStore(p),
      FeedCacheStore(p),
    );
  }

  Future<({String key, String url})?> webQrGenerate() => auth.webQrGenerate();
  Future<bool> webQrPoll(String key) => auth.webQrPoll(key);
  Stream<bool> webQrLoginFlow(String key) => auth.webQrLoginFlow(key);
  Future<bool> loginWithCookie(String cookieHeader) => auth.loginWithCookie(cookieHeader);
  Future<void> restoreLogin() => auth.restoreLogin();
  Future<void> logout() => auth.logout();
  Future<({String videoUrl, String? audioUrl})> getPlayUrl(String bvid, {int? qn}) => playApi.getPlayUrl(bvid, qn: qn);
  Future<VideoShot?> getVideoShot(String bvid) => playApi.getVideoShot(bvid);
  Future<List<SearchUser>> searchUsers(String keyword) => searchApi.searchUsers(keyword);
  Future<List<DanmakuItem>> getDanmaku(String bvid, {int durationSec = 0}) => danmakuApi.getDanmaku(bvid, durationSec: durationSec);
  Future<List<({int mid, String name, String face})>> getVideoStaff(String bvid) => videoApi.getVideoStaff(bvid);
  Future<List<VideoInfo>> getUpVideos(int mid, {int tid = 0, int pn = 1, int cursor = 0}) => videoApi.getUpVideos(mid, tid: tid, pn: pn, cursor: cursor);
  Future<({String name, String face, int fans, String banner})?> getUserInfo(int mid) => userApi.getUserInfo(mid);
  Future<({String name, String face, int fans, String banner})?> getUpInfoByVideo(String bvid) => videoApi.getUpInfoByVideo(bvid);
  Future<List<SubtitleCue>?> getSubtitles(String bvid) => subtitleApi.getSubtitles(bvid);
  Future<List<VideoInfo>> getDailyVideos({bool force = false}) => feed.getDailyVideos(force: force);
  Future<List<VideoInfo>> getHotVideos({int pn = 1, int limit = 0}) => feed.getHotVideos(pn: pn, limit: limit);
  Future<List<VideoInfo>> fetchSubscriptionTimeline({void Function(int done, int total)? onProgress}) => feed.fetchSubscriptionTimeline(onProgress: onProgress);
  List<VideoInfo> cachedSubscriptionTimeline() => feed.cachedSubscriptionTimeline();
  int? get subscriptionUpdatedAt => feedCache.subUpdatedAt;

  String? get buvid3 => client.auth.buvid3;

  Map<String, dynamic> exportData() => {
        'schemaVersion': exportSchemaVersion,
        'settings': settings.toJson(),
        'subscriptions': subscriptions.store.items,
        'blacklist': blacklist.store.items,
        'history': history.store.items,
        'watchLater': watchLater.store.items,
      };

  Future<void> importData(Map<String, dynamic> data) async {
    final schemaVersion = (data['schemaVersion'] as int?) ?? (data['version'] as int?) ?? 1;
    final migrated = schemaVersion >= exportSchemaVersion ? data : (Map<String, dynamic>.from(data)..['schemaVersion'] = exportSchemaVersion);
    final s = migrated['settings'];
    if (s is Map<String, dynamic>) {
      await settings.apply(s);
    }
    List<Map<String, dynamic>> asList(Object? v) => v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];
    if (migrated['subscriptions'] is List) await subscriptions.store.setItems(asList(migrated['subscriptions']));
    if (migrated['blacklist'] is List) await blacklist.store.setItems(asList(migrated['blacklist']));
    if (migrated['history'] is List) await history.store.setItems(asList(migrated['history']));
    if (migrated['watchLater'] is List) await watchLater.store.setItems(asList(migrated['watchLater']));
    await client.auth.setGuestMode(settings.guestMode);
    await feedCache.clearAll();
  }
}
