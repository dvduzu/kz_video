import '../../core/logger.dart';
import '../store/feed_cache_store.dart';
import '../store/subscription_store.dart';

class SubscriptionRepository {
  final SubscriptionStore store;
  final FeedCacheStore feedCache;
  SubscriptionRepository(this.store, this.feedCache);

  Future<bool> add(int mid, String name, {String face = ''}) async {
    final list = store.items;
    if (list.any((e) => e['mid'] == mid)) return true;
    list.add({'mid': mid, 'name': name, 'face': face});
    await store.setItems(list);
    await feedCache.clearFor('sub');
    return true;
  }

  Future<bool> contains(int mid) async => store.items.any((e) => e['mid'] == mid);

  Future<List<({int mid, String name, String face})>> all() async {
    return store.items.map((m) {
      try {
        return (mid: m['mid'] as int, name: m['name'] as String? ?? '', face: (m['face'] as String?) ?? '');
      } catch (err) {
        KzvLogger.debug('parse subscription failed: $err');
        return null;
      }
    }).whereType<({int mid, String name, String face})>().toList();
  }

  Future<void> remove(int mid) async {
    final list = store.items;
    list.removeWhere((e) => e['mid'] == mid);
    await store.setItems(list);
    await feedCache.clearFor('sub');
  }
}
