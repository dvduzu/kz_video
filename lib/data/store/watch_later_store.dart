import '../preference_keys.dart';
import 'store_base.dart';

class WatchLaterStore extends StoreBase {
  static const int maxItems = 50;
  WatchLaterStore(super.p);

  List<Map<String, dynamic>> get items => readList(PreferenceKeys.watchLater);
  Future<void> setItems(List<Map<String, dynamic>> v) => writeList(PreferenceKeys.watchLater, v);
}
