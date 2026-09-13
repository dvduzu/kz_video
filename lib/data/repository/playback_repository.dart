import '../store/playback_store.dart';

class PlaybackRepository {
  final PlaybackStore store;
  PlaybackRepository(this.store);

  Future<void> save(String bvid, int positionMs, int durationMs) async {
    await store.setProgress(bvid, '$positionMs|$durationMs');
  }

  Future<({int positionMs, int durationMs})?> get(String bvid) async {
    final raw = store.getProgress(bvid);
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 2) return null;
    final pos = int.tryParse(parts[0]);
    final dur = int.tryParse(parts[1]);
    if (pos == null || dur == null) return null;
    return (positionMs: pos, durationMs: dur);
  }

  Future<void> markWatched(String bvid) async {
    final list = store.watched;
    if (!list.contains(bvid)) {
      list.add(bvid);
      await store.setWatched(list);
    }
  }

  Set<String> get watched => store.watched.toSet();
  Future<Set<String>> watchedSet() async => store.watched.toSet();

  Future<void> clearWatched() async {
    await store.setWatched([]);
  }
}
