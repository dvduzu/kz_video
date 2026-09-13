import '../../core/logger.dart';
import '../models.dart';
import '../store/blacklist_store.dart';

class BlacklistRepository {
  final BlacklistStore store;
  BlacklistRepository(this.store);

  Future<void> add(VideoInfo v) async {
    final list = store.items;
    list.removeWhere((e) => e['bvid'] == v.bvid);
    list.add(v.toJson());
    await store.setItems(list);
  }

  Future<List<VideoInfo>> all() async {
    return store.items.map((e) {
      try {
        return VideoInfo.fromJson(e);
      } catch (err) {
        KzvLogger.debug('parse blacklist failed: $err');
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
