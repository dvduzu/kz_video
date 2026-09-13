import '../preference_keys.dart';
import 'store_base.dart';

class SubscriptionStore extends StoreBase {
  static const int maxItems = 50;
  SubscriptionStore(super.p);

  List<Map<String, dynamic>> get items => readList(PreferenceKeys.subscriptions);
  Future<void> setItems(List<Map<String, dynamic>> v) => writeList(PreferenceKeys.subscriptions, v);
}
