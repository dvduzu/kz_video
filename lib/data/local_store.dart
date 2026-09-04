import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  final SharedPreferences _p;

  LocalStore(this._p);

  static Future<LocalStore> create() async => LocalStore(await SharedPreferences.getInstance());

  String? getString(String key, [String? def]) => _p.getString(key) ?? def;
  Future<void> setString(String key, String v) => _p.setString(key, v);
  bool? getBool(String key, [bool? def]) => _p.getBool(key) ?? def;
  Future<void> setBool(String key, bool v) => _p.setBool(key, v);
  int? getInt(String key, [int? def]) => _p.getInt(key) ?? def;
  Future<void> setInt(String key, int v) => _p.setInt(key, v);
  List<String>? getStringList(String key) => _p.getStringList(key);
  Future<void> setStringList(String key, List<String> v) => _p.setStringList(key, v);

  static const _blacklist = 'blacklist';
  static const _history = 'history';
  static const _watchLater = 'watch_later';
  static const _subscriptions = 'subscriptions';

  bool get isHistoryEnabled => _p.getBool('setting_history') ?? true;
  bool get isWatchLaterEnabled => _p.getBool('setting_watch_later') ?? true;
  int get minDuration => _p.getInt('setting_min_duration') ?? 600;
  String get rid => _p.getString('setting_rid') ?? '';
  bool get rcmdEnabled => _p.getBool('setting_rcmd_enabled') ?? false;
  int get rcmdBatch => _p.getInt('setting_rcmd_batch') ?? 3;
  List<String> get rcmdRids => _p.getStringList('setting_rcmd_rids') ?? const ['', 'tech', 'edu', 'life', 'game', 'ent', 'music'];
  bool get guestMode => _p.getBool('guest_mode') ?? false;

  Future<void> setGuestMode(bool v) => _p.setBool('guest_mode', v);

  List<Map<String, dynamic>> _readList(String key) {
    final raw = _p.getStringList(key) ?? [];
    return raw.map((e) {
      try { return jsonDecode(e) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
    }).where((e) => e.isNotEmpty).toList();
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> list) {
    return _p.setStringList(key, list.map((e) => jsonEncode(e)).toList());
  }

  List<Map<String, dynamic>> get blacklist => _readList(_blacklist);
  Future<void> setBlacklist(List<Map<String, dynamic>> v) => _writeList(_blacklist, v);

  List<Map<String, dynamic>> get history => _readList(_history);
  Future<void> setHistory(List<Map<String, dynamic>> v) => _writeList(_history, v);

  List<Map<String, dynamic>> get watchLater => _readList(_watchLater);
  Future<void> setWatchLater(List<Map<String, dynamic>> v) => _writeList(_watchLater, v);

  List<Map<String, dynamic>> get subscriptions => _readList(_subscriptions);
  Future<void> setSubscriptions(List<Map<String, dynamic>> v) => _writeList(_subscriptions, v);

  String? getProgress(String bvid) => _p.getString('progress_$bvid');
  Future<void> setProgress(String bvid, String v) => _p.setString('progress_$bvid', v);

  String? getDailyCache(String key) => _p.getString(key);
  int? getDailyTs(String key) => _p.getInt(key);
  Future<void> setDailyCache(String key, String v) => _p.setString(key, v);
  Future<void> setDailyTs(String key, int v) => _p.setInt(key, v);

  int getRefreshCount(String today) => _p.getInt('refresh_count_$today') ?? 0;
  Future<void> setRefreshCount(String today, int v) => _p.setInt('refresh_count_$today', v);
}