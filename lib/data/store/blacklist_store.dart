import '../preference_keys.dart';
import 'store_base.dart';

class BlacklistStore extends StoreBase {
  BlacklistStore(super.p);

  List<Map<String, dynamic>> get items => readList(PreferenceKeys.blacklist);
  Future<void> setItems(List<Map<String, dynamic>> v) => writeList(PreferenceKeys.blacklist, v);
}
