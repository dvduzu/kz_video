import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static const int maxHistoryItems = 50;
  static const int maxWatchLaterItems = 50;
  static const int maxSubscriptions = 50;

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
  int minDurationOf(String rid) {
    if (rid == 'sub') return _p.getInt('setting_min_duration_sub') ?? 0;
    return _p.getInt('setting_min_duration') ?? 600;
  }
  String get rid => _p.getString('setting_rid') ?? '';
  String get homeRid => _p.getString('setting_home_rid') ?? '';
  String get themeMode => _p.getString('theme_mode') ?? 'system';
  String get themeSeed => _p.getString('theme_seed') ?? '';
  Future<void> setThemeMode(String v) => _p.setString('theme_mode', v);
  Future<void> setThemeSeed(String v) => _p.setString('theme_seed', v);
  bool get rcmdEnabled => _p.getBool('setting_rcmd_enabled') ?? false;
  int get rcmdBatch => _p.getInt('setting_rcmd_batch') ?? 3;
  bool get guestMode => _p.getBool('guest_mode') ?? false;

  Future<void> setGuestMode(bool v) => _p.setBool('guest_mode', v);
  Future<void> setHistoryEnabled(bool v) => _p.setBool('setting_history', v);
  Future<void> setWatchLaterEnabled(bool v) => _p.setBool('setting_watch_later', v);
  Future<void> setMinDuration(int v) => _p.setInt('setting_min_duration', v);
  Future<void> setMinDurationOf(String rid, int v) => _p.setInt(rid == 'sub' ? 'setting_min_duration_sub' : 'setting_min_duration', v);
  Future<void> setRid(String v) => _p.setString('setting_rid', v);
  Future<void> setHomeRid(String v) => _p.setString('setting_home_rid', v);
  Future<void> setRcmdEnabled(bool v) => _p.setBool('setting_rcmd_enabled', v);
  Future<void> setRcmdBatch(int v) => _p.setInt('setting_rcmd_batch', v);

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
  bool get unlimitedRefresh => _p.getBool('debug_unlimited_refresh') ?? false;
  Future<void> setUnlimitedRefresh(bool v) => _p.setBool('debug_unlimited_refresh', v);

  List<String> get watched => _p.getStringList('watched') ?? [];
  Future<void> setWatched(List<String> v) => _p.setStringList('watched', v);

  Future<void> clearAllDailyCache() async {
    final keys = _p.getKeys().where((k) => k.startsWith('daily_')).toList();
    for (final k in keys) {
      await _p.remove(k);
    }
  }

  Future<void> clearDailyCacheFor(String ridKey) async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await _p.remove('daily_${ridKey}_$today');
    await _p.remove('daily_ts_${ridKey}_$today');
  }

  Map<String, dynamic> exportData() {
    return {
      'version': 1,
      'settings': {
        'rid': rid,
        'homeRid': homeRid,
        'minDuration': _p.getInt('setting_min_duration') ?? 600,
        'minDurationSub': _p.getInt('setting_min_duration_sub') ?? 0,
        'rcmdEnabled': rcmdEnabled,
        'rcmdBatch': rcmdBatch,
        'history': isHistoryEnabled,
        'watchLater': isWatchLaterEnabled,
        'guestMode': guestMode,
      },
      'subscriptions': subscriptions,
      'blacklist': blacklist,
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    final settings = data['settings'] as Map<String, dynamic>?;
    if (settings != null) {
      if (settings['rid'] is String) await setRid(settings['rid'] as String);
      if (settings['homeRid'] is String) await setHomeRid(settings['homeRid'] as String);
      if (settings['minDuration'] is int) await setMinDuration(settings['minDuration'] as int);
      if (settings['minDurationSub'] is int) await setMinDurationOf('sub', settings['minDurationSub'] as int);
      if (settings['rcmdEnabled'] is bool) await setRcmdEnabled(settings['rcmdEnabled'] as bool);
      if (settings['rcmdBatch'] is int) await setRcmdBatch(settings['rcmdBatch'] as int);
      if (settings['history'] is bool) await setHistoryEnabled(settings['history'] as bool);
      if (settings['watchLater'] is bool) await setWatchLaterEnabled(settings['watchLater'] as bool);
      if (settings['guestMode'] is bool) await setGuestMode(settings['guestMode'] as bool);
    }
    if (data['subscriptions'] is List) {
      await _writeList(_subscriptions, (data['subscriptions'] as List).whereType<Map<String, dynamic>>().toList());
    }
    if (data['blacklist'] is List) {
      await _writeList(_blacklist, (data['blacklist'] as List).whereType<Map<String, dynamic>>().toList());
    }
  }
}