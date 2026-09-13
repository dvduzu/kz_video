import '../preference_keys.dart';
import 'store_base.dart';

class PlaybackStore extends StoreBase {
  PlaybackStore(super.p);

  String? getProgress(String bvid) => p.getString(PreferenceKeys.progress(bvid));
  Future<void> setProgress(String bvid, String v) => p.setString(PreferenceKeys.progress(bvid), v);

  List<String> get watched => p.getStringList(PreferenceKeys.watched) ?? [];
  Future<void> setWatched(List<String> v) => p.setStringList(PreferenceKeys.watched, v);
}
