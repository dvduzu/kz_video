import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logger.dart';
import 'preference_keys.dart';

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

  bool get isHistoryEnabled => _p.getBool(PreferenceKeys.settingHistory) ?? true;
  bool get isWatchLaterEnabled => _p.getBool(PreferenceKeys.settingWatchLater) ?? true;
  int get minDuration => _p.getInt(PreferenceKeys.settingMinDuration) ?? 600;
  int minDurationOf(String rid) {
    if (rid == 'sub') return _p.getInt(PreferenceKeys.settingMinDurationSub) ?? 0;
    if (rid == 'hot') return _p.getInt(PreferenceKeys.settingMinDurationHot) ?? 0;
    return _p.getInt(PreferenceKeys.settingMinDuration) ?? 600;
  }
  String get rid => _p.getString(PreferenceKeys.settingRid) ?? '';
  String get homeRid => _p.getString(PreferenceKeys.settingHomeRid) ?? '';
  String get themeMode => _p.getString(PreferenceKeys.themeMode) ?? 'system';
  String get themeSeed => _p.getString(PreferenceKeys.themeSeed) ?? '';
  bool get dynamicColor => _p.getBool(PreferenceKeys.dynamicColor) ?? false;
  Future<void> setThemeMode(String v) => _p.setString(PreferenceKeys.themeMode, v);
  Future<void> setThemeSeed(String v) => _p.setString(PreferenceKeys.themeSeed, v);
  Future<void> setDynamicColor(bool v) => _p.setBool(PreferenceKeys.dynamicColor, v);
  bool get rcmdEnabled => _p.getBool(PreferenceKeys.settingRcmdEnabled) ?? false;
  int get rcmdBatch => _p.getInt(PreferenceKeys.settingRcmdBatch) ?? 3;
  bool get guestMode => _p.getBool(PreferenceKeys.guestMode) ?? false;
  bool get cardOutline => _p.getBool(PreferenceKeys.settingCardOutline) ?? false;
  String get cardTone => _p.getString(PreferenceKeys.settingCardTone) ?? 'high';
  bool get animEnabled => _p.getBool(PreferenceKeys.settingAnimEnabled) ?? true;
  bool get animPage => _p.getBool(PreferenceKeys.settingAnimPage) ?? true;
  bool get animList => _p.getBool(PreferenceKeys.settingAnimList) ?? true;
  bool get animCard => _p.getBool(PreferenceKeys.settingAnimCard) ?? true;
  String get animSpeed => _p.getString(PreferenceKeys.settingAnimSpeed) ?? 'normal';
  bool get backgroundPlay => _p.getBool(PreferenceKeys.settingBackgroundPlay) ?? true;
  int recommendCountOf(String rid) {
    final raw = _p.getInt(PreferenceKeys.recommendCount(rid));
    if (rid == 'hot') return (raw ?? 0).clamp(0, 50);
    return (raw ?? 10).clamp(10, 50);
  }
  int get subFilterMid => _p.getInt(PreferenceKeys.settingSubFilterMid) ?? 0;
  double get danmakuOpacity => (_p.getDouble(PreferenceKeys.settingDmOpacity) ?? 0.9).clamp(0.2, 1.0);
  double get danmakuFontSize => (_p.getDouble(PreferenceKeys.settingDmFontSize) ?? 16).clamp(12, 28);
  double get danmakuDuration => (_p.getDouble(PreferenceKeys.settingDmDuration) ?? 8).clamp(4, 16);
  double get danmakuArea => (_p.getDouble(PreferenceKeys.settingDmArea) ?? 0.5).clamp(0.1, 1.0);
  bool get danmakuStroke => _p.getBool(PreferenceKeys.settingDmStroke) ?? true;

  Future<void> setGuestMode(bool v) => _p.setBool(PreferenceKeys.guestMode, v);
  Future<void> setCardOutline(bool v) => _p.setBool(PreferenceKeys.settingCardOutline, v);
  Future<void> setCardTone(String v) => _p.setString(PreferenceKeys.settingCardTone, v);
  Future<void> setAnimEnabled(bool v) => _p.setBool(PreferenceKeys.settingAnimEnabled, v);
  Future<void> setAnimPage(bool v) => _p.setBool(PreferenceKeys.settingAnimPage, v);
  Future<void> setAnimList(bool v) => _p.setBool(PreferenceKeys.settingAnimList, v);
  Future<void> setAnimCard(bool v) => _p.setBool(PreferenceKeys.settingAnimCard, v);
  Future<void> setAnimSpeed(String v) => _p.setString(PreferenceKeys.settingAnimSpeed, v);
  Future<void> setBackgroundPlay(bool v) => _p.setBool(PreferenceKeys.settingBackgroundPlay, v);
  Future<void> setRecommendCountOf(String rid, int v) => _p.setInt(PreferenceKeys.recommendCount(rid), rid == 'hot' ? v.clamp(0, 50) : v.clamp(10, 50));
  Future<void> setSubFilterMid(int v) => _p.setInt(PreferenceKeys.settingSubFilterMid, v);
  Future<void> setDanmakuOpacity(double v) => _p.setDouble(PreferenceKeys.settingDmOpacity, v.clamp(0.2, 1.0));
  Future<void> setDanmakuFontSize(double v) => _p.setDouble(PreferenceKeys.settingDmFontSize, v.clamp(12, 28));
  Future<void> setDanmakuDuration(double v) => _p.setDouble(PreferenceKeys.settingDmDuration, v.clamp(4, 16));
  Future<void> setDanmakuArea(double v) => _p.setDouble(PreferenceKeys.settingDmArea, v.clamp(0.1, 1.0));
  Future<void> setDanmakuStroke(bool v) => _p.setBool(PreferenceKeys.settingDmStroke, v);
  Future<void> setHistoryEnabled(bool v) => _p.setBool(PreferenceKeys.settingHistory, v);
  Future<void> setWatchLaterEnabled(bool v) => _p.setBool(PreferenceKeys.settingWatchLater, v);
  Future<void> setMinDuration(int v) => _p.setInt(PreferenceKeys.settingMinDuration, v);
  Future<void> setMinDurationOf(String rid, int v) => _p.setInt(switch (rid) { 'sub' => PreferenceKeys.settingMinDurationSub, 'hot' => PreferenceKeys.settingMinDurationHot, _ => PreferenceKeys.settingMinDuration }, v);
  Future<void> setRid(String v) => _p.setString(PreferenceKeys.settingRid, v);
  Future<void> setHomeRid(String v) => _p.setString(PreferenceKeys.settingHomeRid, v);
  Future<void> setRcmdEnabled(bool v) => _p.setBool(PreferenceKeys.settingRcmdEnabled, v);
  Future<void> setRcmdBatch(int v) => _p.setInt(PreferenceKeys.settingRcmdBatch, v);

  List<Map<String, dynamic>> _readList(String key) {
    final raw = _p.getStringList(key) ?? [];
    return raw.map((e) {
      try { return jsonDecode(e) as Map<String, dynamic>; } catch (err) { KzvLogger.debug('local json parse failed: $err'); return <String, dynamic>{}; }
    }).where((e) => e.isNotEmpty).toList();
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> list) {
    return _p.setStringList(key, list.map((e) => jsonEncode(e)).toList());
  }

  List<Map<String, dynamic>> get blacklist => _readList(PreferenceKeys.blacklist);
  Future<void> setBlacklist(List<Map<String, dynamic>> v) => _writeList(PreferenceKeys.blacklist, v);

  List<Map<String, dynamic>> get history => _readList(PreferenceKeys.history);
  Future<void> setHistory(List<Map<String, dynamic>> v) => _writeList(PreferenceKeys.history, v);

  List<Map<String, dynamic>> get watchLater => _readList(PreferenceKeys.watchLater);
  Future<void> setWatchLater(List<Map<String, dynamic>> v) => _writeList(PreferenceKeys.watchLater, v);

  List<Map<String, dynamic>> get subscriptions => _readList(PreferenceKeys.subscriptions);
  Future<void> setSubscriptions(List<Map<String, dynamic>> v) => _writeList(PreferenceKeys.subscriptions, v);

  String? getProgress(String bvid) => _p.getString(PreferenceKeys.progress(bvid));
  Future<void> setProgress(String bvid, String v) => _p.setString(PreferenceKeys.progress(bvid), v);

  String? getDailyCache(String key) => _p.getString(key);
  int? getDailyTs(String key) => _p.getInt(key);
  Future<void> setDailyCache(String key, String v) => _p.setString(key, v);
  Future<void> setDailyTs(String key, int v) => _p.setInt(key, v);

  int getRefreshCount(String today) => _p.getInt(PreferenceKeys.refreshCount(today)) ?? 0;
  Future<void> setRefreshCount(String today, int v) => _p.setInt(PreferenceKeys.refreshCount(today), v);
  bool get unlimitedRefresh => _p.getBool(PreferenceKeys.debugUnlimitedRefresh) ?? false;
  Future<void> setUnlimitedRefresh(bool v) => _p.setBool(PreferenceKeys.debugUnlimitedRefresh, v);

  List<String> get watched => _p.getStringList(PreferenceKeys.watched) ?? [];
  Future<void> setWatched(List<String> v) => _p.setStringList(PreferenceKeys.watched, v);

  Future<void> clearAllDailyCache() async {
    final keys = _p.getKeys().where((k) => k.startsWith(PreferenceKeys.dailyCachePrefix)).toList();
    for (final k in keys) {
      await _p.remove(k);
    }
  }

  Future<void> clearDailyCacheFor(String ridKey) async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await _p.remove(PreferenceKeys.daily(ridKey, today));
    await _p.remove(PreferenceKeys.dailyTs(ridKey, today));
  }

  static const int exportSchemaVersion = 2;

  Map<String, dynamic> exportData() {
    return {
      'schemaVersion': exportSchemaVersion,
      'settings': {
        'rid': rid,
        'homeRid': homeRid,
        'minDuration': _p.getInt(PreferenceKeys.settingMinDuration) ?? 600,
        'minDurationSub': _p.getInt(PreferenceKeys.settingMinDurationSub) ?? 0,
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
    final schemaVersion = (data['schemaVersion'] as int?) ?? (data['version'] as int?) ?? 1;
    final migrated = _migrateExport(data, schemaVersion);
    final settings = migrated['settings'] as Map<String, dynamic>?;
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
    if (migrated['subscriptions'] is List) {
      await _writeList(PreferenceKeys.subscriptions, (migrated['subscriptions'] as List).whereType<Map<String, dynamic>>().toList());
    }
    if (migrated['blacklist'] is List) {
      await _writeList(PreferenceKeys.blacklist, (migrated['blacklist'] as List).whereType<Map<String, dynamic>>().toList());
    }
  }

  Map<String, dynamic> _migrateExport(Map<String, dynamic> data, int fromVersion) {
    if (fromVersion >= exportSchemaVersion) return data;
    final migrated = Map<String, dynamic>.from(data);
    migrated['schemaVersion'] = exportSchemaVersion;
    return migrated;
  }
}
