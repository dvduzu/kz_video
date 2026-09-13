import '../preference_keys.dart';
import 'store_base.dart';

class FeedCacheStore extends StoreBase {
  FeedCacheStore(super.p);

  String? getDailyCache(String key) => p.getString(key);
  int? getDailyTs(String key) => p.getInt(key);
  Future<void> setDailyCache(String key, String v) => p.setString(key, v);
  Future<void> setDailyTs(String key, int v) => p.setInt(key, v);

  int getRefreshCount(String today) => p.getInt(PreferenceKeys.refreshCount(today)) ?? 0;
  Future<void> setRefreshCount(String today, int v) => p.setInt(PreferenceKeys.refreshCount(today), v);
  bool get unlimitedRefresh => p.getBool(PreferenceKeys.debugUnlimitedRefresh) ?? false;
  Future<void> setUnlimitedRefresh(bool v) => p.setBool(PreferenceKeys.debugUnlimitedRefresh, v);

  String? get subTimeline => p.getString(PreferenceKeys.subTimeline);
  Future<void> setSubTimeline(String v) => p.setString(PreferenceKeys.subTimeline, v);
  int? get subUpdatedAt => p.getInt(PreferenceKeys.subUpdatedAt);
  Future<void> setSubUpdatedAt(int v) => p.setInt(PreferenceKeys.subUpdatedAt, v);

  Future<void> clearAll() async {
    final keys = p.getKeys().where((k) => k.startsWith(PreferenceKeys.dailyCachePrefix)).toList();
    for (final k in keys) {
      await p.remove(k);
    }
  }

  Future<void> clearFor(String ridKey) async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await p.remove(PreferenceKeys.daily(ridKey, today));
    await p.remove(PreferenceKeys.dailyTs(ridKey, today));
  }
}
