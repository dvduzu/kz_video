import '../preference_keys.dart';
import 'store_base.dart';

class HistoryStore extends StoreBase {
  static const int maxItems = 50;
  HistoryStore(super.p);

  List<Map<String, dynamic>> get items => readList(PreferenceKeys.history);
  Future<void> setItems(List<Map<String, dynamic>> v) => writeList(PreferenceKeys.history, v);
}
