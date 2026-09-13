import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/logger.dart';

class StoreBase {
  final SharedPreferences p;
  StoreBase(this.p);

  List<Map<String, dynamic>> readList(String key) {
    final raw = p.getStringList(key) ?? [];
    return raw.map((e) {
      try {
        return jsonDecode(e) as Map<String, dynamic>;
      } catch (err) {
        KzvLogger.debug('local json parse failed: $err');
        return <String, dynamic>{};
      }
    }).where((e) => e.isNotEmpty).toList();
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> list) {
    return p.setStringList(key, list.map((e) => jsonEncode(e)).toList());
  }
}
