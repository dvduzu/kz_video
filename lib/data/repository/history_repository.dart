import '../../core/logger.dart';
import '../models.dart';
import '../store/history_store.dart';
import '../store/settings_store.dart';

class HistoryRepository {
  final HistoryStore store;
  final SettingsStore settings;
  HistoryRepository(this.store, this.settings);

  bool get enabled => settings.isHistoryEnabled;

  Future<void> add(VideoInfo v) async {
    if (!enabled) return;
    final list = store.items;
    list.removeWhere((e) => e['bvid'] == v.bvid);
    list.insert(0, v.toJson());
    if (list.length > HistoryStore.maxItems) list.removeRange(HistoryStore.maxItems, list.length);
    await store.setItems(list);
  }

  Future<List<VideoInfo>> all() async {
    return store.items.map((e) {
      try {
        return VideoInfo.fromJson(e);
      } catch (err) {
        KzvLogger.debug('parse history failed: $err');
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
