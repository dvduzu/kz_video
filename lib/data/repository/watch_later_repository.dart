import '../../core/logger.dart';
import '../models.dart';
import '../store/settings_store.dart';
import '../store/watch_later_store.dart';

class WatchLaterRepository {
  final WatchLaterStore store;
  final SettingsStore settings;
  WatchLaterRepository(this.store, this.settings);

  bool get enabled => settings.isWatchLaterEnabled;

  Future<bool> add(VideoInfo v) async {
    if (!enabled) return false;
    final list = store.items;
    if (!list.any((e) => e['bvid'] == v.bvid)) {
      if (list.length >= WatchLaterStore.maxItems) return false;
      list.add(v.toJson());
      await store.setItems(list);
    }
    return true;
  }

  Future<List<VideoInfo>> all() async {
    return store.items.map((e) {
      try {
        return VideoInfo.fromJson(e);
      } catch (err) {
        KzvLogger.debug('parse watch later failed: $err');
        return null;
      }
    }).whereType<VideoInfo>().toList();
  }

  Future<void> remove(String bvid) async {
    final list = store.items;
    list.removeWhere((e) => e['bvid'] == bvid);
    await store.setItems(list);
  }
}
