import '../preference_keys.dart';
import 'store_base.dart';

class WatchLaterStore extends StoreBase {
  WatchLaterStore(super.p);

  List<Map<String, dynamic>> get items => readList(PreferenceKeys.watchLater);
  Future<void> setItems(List<Map<String, dynamic>> v) => writeList(PreferenceKeys.watchLater, v);
}
