import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kz_video/data/store/settings_store.dart';
import 'package:kz_video/data/store/feed_cache_store.dart';
import 'package:kz_video/data/store/playback_store.dart';
import 'package:kz_video/data/store/subscription_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('settings store defaults and setters', () async {
    final p = await SharedPreferences.getInstance();
    final s = SettingsStore(p);
    expect(s.rid, '');
    expect(s.recommendCountOf('hot'), 0);
    expect(s.recommendCountOf('tech'), 10);
    await s.setRid('hot');
    await s.setRecommendCountOf('hot', 25);
    expect(s.rid, 'hot');
    expect(s.recommendCountOf('hot'), 25);
  });

  test('playback store progress round trips', () async {
    final p = await SharedPreferences.getInstance();
    final s = PlaybackStore(p);
    await s.setProgress('BV1', '1200|6000');
    expect(s.getProgress('BV1'), '1200|6000');
    await s.setWatched(['BV1']);
    expect(s.watched, contains('BV1'));
  });

  test('subscription store round trips', () async {
    final p = await SharedPreferences.getInstance();
    final s = SubscriptionStore(p);
    await s.setItems([{'mid': 1, 'name': 'u', 'face': ''}]);
    expect(s.items, hasLength(1));
  });

  test('feed cache refresh count', () async {
    final p = await SharedPreferences.getInstance();
    final s = FeedCacheStore(p);
    expect(s.getRefreshCount('2026-09-13'), 0);
    await s.setRefreshCount('2026-09-13', 3);
    expect(s.getRefreshCount('2026-09-13'), 3);
  });
}
