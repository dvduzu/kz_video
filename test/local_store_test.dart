import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kz_video/data/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('export includes schemaVersion and import round trips', () async {
    final store = await LocalStore.create();
    await store.setSubscriptions([{'mid': 1, 'name': 'u', 'face': ''}]);
    await store.setRid('hot');
    final data = store.exportData();
    expect(data['schemaVersion'], LocalStore.exportSchemaVersion);

    final store2 = await LocalStore.create();
    await store2.importData(data);
    expect(store2.rid, 'hot');
    expect(store2.subscriptions, hasLength(1));
  });

  test('imports a v1 backup without schemaVersion', () async {
    final store = await LocalStore.create();
    await store.importData({
      'version': 1,
      'settings': {'rid': 'tech', 'minDuration': 600},
    });
    expect(store.rid, 'tech');
    expect(store.minDuration, 600);
  });

  test('playback progress round trips', () async {
    final store = await LocalStore.create();
    await store.setProgress('BV1', '1200|6000');
    expect(store.getProgress('BV1'), '1200|6000');
  });

  test('recommendCount defaults: hot unlimited, others ten', () async {
    final store = await LocalStore.create();
    expect(store.recommendCountOf('hot'), 0);
    expect(store.recommendCountOf('tech'), 10);
    await store.setRecommendCountOf('hot', 25);
    expect(store.recommendCountOf('hot'), 25);
  });
}
