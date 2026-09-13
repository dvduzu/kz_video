import '../preference_keys.dart';
import 'store_base.dart';

class PlaybackStore extends StoreBase {
  PlaybackStore(super.p);

  String? getProgress(String bvid) => p.getString(PreferenceKeys.progress(bvid));
  Future<void> setProgress(String bvid, String v) => p.setString(PreferenceKeys.progress(bvid), v);
  List<String> get watched {
    final date = p.getString(PreferenceKeys.watchedDate);
    if (date != _today()) return const [];
    return p.getStringList(PreferenceKeys.watched) ?? [];
  }

  Future<void> setWatched(List<String> v) async {
    await p.setStringList(PreferenceKeys.watched, v);
    await p.setString(PreferenceKeys.watchedDate, _today());
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
