import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../preference_keys.dart';

class SettingsStore {
  final SharedPreferences p;
  SettingsStore(this.p);

  bool get isHistoryEnabled => p.getBool(PreferenceKeys.settingHistory) ?? true;
  bool get isWatchLaterEnabled => p.getBool(PreferenceKeys.settingWatchLater) ?? true;
  int get minDuration => p.getInt(PreferenceKeys.settingMinDuration) ?? 0;
  int minDurationOf(String rid) {
    if (rid == 'sub') return p.getInt(PreferenceKeys.settingMinDurationSub) ?? 0;
    if (rid == 'hot') return p.getInt(PreferenceKeys.settingMinDurationHot) ?? 0;
    return p.getInt(PreferenceKeys.settingMinDuration) ?? 0;
  }
  String get rid => p.getString(PreferenceKeys.settingRid) ?? '';
  String get homeRid => p.getString(PreferenceKeys.settingHomeRid) ?? '';
  String get themeMode => p.getString(PreferenceKeys.themeMode) ?? 'system';
  String get themeSeed => p.getString(PreferenceKeys.themeSeed) ?? '';
  bool get dynamicColor => p.getBool(PreferenceKeys.dynamicColor) ?? false;
  String get uiMode => p.getString(PreferenceKeys.uiMode) ?? 'auto';
  UiMode get uiModeMode => switch (uiMode) { 'phone' => UiMode.phone, 'tablet' => UiMode.tablet, _ => UiMode.auto };
  double get dockOpacity => (p.getDouble(PreferenceKeys.dockOpacity) ?? 0.5).clamp(0.1, 1.0);
  double get dockSize => (p.getDouble(PreferenceKeys.dockSize) ?? 1.0).clamp(0.7, 1.6);
  bool get dockGlass => p.getBool(PreferenceKeys.dockGlass) ?? true;
  bool get dockBorder => p.getBool(PreferenceKeys.dockBorder) ?? false;
  bool get dockShadow => p.getBool(PreferenceKeys.dockShadow) ?? false;
  String get subAutoUpdate => p.getString(PreferenceKeys.subAutoUpdate) ?? '60';
  bool get rcmdEnabled => p.getBool(PreferenceKeys.settingRcmdEnabled) ?? false;
  int get rcmdBatch => p.getInt(PreferenceKeys.settingRcmdBatch) ?? 3;
  bool get guestMode => p.getBool(PreferenceKeys.guestMode) ?? false;
  bool get cardOutline => p.getBool(PreferenceKeys.settingCardOutline) ?? false;
  String get cardTone => p.getString(PreferenceKeys.settingCardTone) ?? 'high';
  bool get animEnabled => p.getBool(PreferenceKeys.settingAnimEnabled) ?? true;
  bool get animPage => p.getBool(PreferenceKeys.settingAnimPage) ?? true;
  bool get animList => p.getBool(PreferenceKeys.settingAnimList) ?? true;
  bool get animCard => p.getBool(PreferenceKeys.settingAnimCard) ?? true;
  String get animSpeed => p.getString(PreferenceKeys.settingAnimSpeed) ?? 'normal';
  bool get backgroundPlay => p.getBool(PreferenceKeys.settingBackgroundPlay) ?? true;
  int recommendCountOf(String rid) {
    final raw = p.getInt(PreferenceKeys.recommendCount(rid));
    if (rid == 'hot') return (raw ?? 0).clamp(0, 50);
    return (raw ?? 10).clamp(10, 50);
  }
  int get subFilterMid => p.getInt(PreferenceKeys.settingSubFilterMid) ?? 0;
  double get danmakuOpacity => (p.getDouble(PreferenceKeys.settingDmOpacity) ?? 0.9).clamp(0.2, 1.0);
  double get danmakuFontSize => (p.getDouble(PreferenceKeys.settingDmFontSize) ?? 16).clamp(12, 28);
  double get danmakuDuration => (p.getDouble(PreferenceKeys.settingDmDuration) ?? 8).clamp(4, 16);
  double get danmakuArea => (p.getDouble(PreferenceKeys.settingDmArea) ?? 0.5).clamp(0.1, 1.0);
  bool get danmakuStroke => p.getBool(PreferenceKeys.settingDmStroke) ?? true;
  int get danmakuWeight => (p.getInt(PreferenceKeys.settingDmWeight) ?? 0).clamp(0, 10);
  bool get dimWatched => p.getBool(PreferenceKeys.settingDimWatched) ?? false;

  Future<void> setGuestMode(bool v) => p.setBool(PreferenceKeys.guestMode, v);
  Future<void> setCardOutline(bool v) => p.setBool(PreferenceKeys.settingCardOutline, v);
  Future<void> setCardTone(String v) => p.setString(PreferenceKeys.settingCardTone, v);
  Future<void> setAnimEnabled(bool v) => p.setBool(PreferenceKeys.settingAnimEnabled, v);
  Future<void> setAnimPage(bool v) => p.setBool(PreferenceKeys.settingAnimPage, v);
  Future<void> setAnimList(bool v) => p.setBool(PreferenceKeys.settingAnimList, v);
  Future<void> setAnimCard(bool v) => p.setBool(PreferenceKeys.settingAnimCard, v);
  Future<void> setAnimSpeed(String v) => p.setString(PreferenceKeys.settingAnimSpeed, v);
  Future<void> setBackgroundPlay(bool v) => p.setBool(PreferenceKeys.settingBackgroundPlay, v);
  Future<void> setRecommendCountOf(String rid, int v) => p.setInt(PreferenceKeys.recommendCount(rid), rid == 'hot' ? v.clamp(0, 50) : v.clamp(10, 50));
  Future<void> setSubFilterMid(int v) => p.setInt(PreferenceKeys.settingSubFilterMid, v);
  Future<void> setDanmakuOpacity(double v) => p.setDouble(PreferenceKeys.settingDmOpacity, v.clamp(0.2, 1.0));
  Future<void> setDanmakuFontSize(double v) => p.setDouble(PreferenceKeys.settingDmFontSize, v.clamp(12, 28));
  Future<void> setDanmakuDuration(double v) => p.setDouble(PreferenceKeys.settingDmDuration, v.clamp(4, 16));
  Future<void> setDanmakuArea(double v) => p.setDouble(PreferenceKeys.settingDmArea, v.clamp(0.1, 1.0));
  Future<void> setDanmakuStroke(bool v) => p.setBool(PreferenceKeys.settingDmStroke, v);
  Future<void> setDanmakuWeight(int v) => p.setInt(PreferenceKeys.settingDmWeight, v.clamp(0, 10));
  Future<void> setDimWatched(bool v) => p.setBool(PreferenceKeys.settingDimWatched, v);
  Future<void> setHistoryEnabled(bool v) => p.setBool(PreferenceKeys.settingHistory, v);
  Future<void> setWatchLaterEnabled(bool v) => p.setBool(PreferenceKeys.settingWatchLater, v);
  Future<void> setMinDuration(int v) => p.setInt(PreferenceKeys.settingMinDuration, v);
  Future<void> setMinDurationOf(String rid, int v) => p.setInt(switch (rid) { 'sub' => PreferenceKeys.settingMinDurationSub, 'hot' => PreferenceKeys.settingMinDurationHot, _ => PreferenceKeys.settingMinDuration }, v);
  Future<void> setRid(String v) => p.setString(PreferenceKeys.settingRid, v);
  Future<void> setHomeRid(String v) => p.setString(PreferenceKeys.settingHomeRid, v);
  Future<void> setRcmdEnabled(bool v) => p.setBool(PreferenceKeys.settingRcmdEnabled, v);
  Future<void> setRcmdBatch(int v) => p.setInt(PreferenceKeys.settingRcmdBatch, v);
  Future<void> setThemeMode(String v) => p.setString(PreferenceKeys.themeMode, v);
  Future<void> setThemeSeed(String v) => p.setString(PreferenceKeys.themeSeed, v);
  Future<void> setDynamicColor(bool v) => p.setBool(PreferenceKeys.dynamicColor, v);
  Future<void> setUiMode(String v) => p.setString(PreferenceKeys.uiMode, v);
  Future<void> setDockOpacity(double v) => p.setDouble(PreferenceKeys.dockOpacity, v.clamp(0.1, 1.0));
  Future<void> setDockSize(double v) => p.setDouble(PreferenceKeys.dockSize, v.clamp(0.7, 1.6));
  Future<void> setDockGlass(bool v) => p.setBool(PreferenceKeys.dockGlass, v);
  Future<void> setDockBorder(bool v) => p.setBool(PreferenceKeys.dockBorder, v);
  Future<void> setDockShadow(bool v) => p.setBool(PreferenceKeys.dockShadow, v);
  Future<void> setSubAutoUpdate(String v) => p.setString(PreferenceKeys.subAutoUpdate, v);

  static const List<String> _ridKeys = ['', 'hot', 'tech', 'edu', 'life', 'game', 'ent', 'music', 'sub'];

  Map<String, dynamic> toJson() => {
        'historyEnabled': isHistoryEnabled,
        'watchLaterEnabled': isWatchLaterEnabled,
        'minDuration': minDuration,
        'minDurationSub': minDurationOf('sub'),
        'minDurationHot': minDurationOf('hot'),
        'rid': rid,
        'homeRid': homeRid,
        'themeMode': themeMode,
        'themeSeed': themeSeed,
        'dynamicColor': dynamicColor,
        'uiMode': uiMode,
        'dockOpacity': dockOpacity,
        'dockSize': dockSize,
        'dockGlass': dockGlass,
        'dockBorder': dockBorder,
        'dockShadow': dockShadow,
        'rcmdEnabled': rcmdEnabled,
        'rcmdBatch': rcmdBatch,
        'guestMode': guestMode,
        'cardOutline': cardOutline,
        'cardTone': cardTone,
        'animEnabled': animEnabled,
        'animPage': animPage,
        'animList': animList,
        'animCard': animCard,
        'animSpeed': animSpeed,
        'backgroundPlay': backgroundPlay,
        'subFilterMid': subFilterMid,
        'danmakuOpacity': danmakuOpacity,
        'danmakuFontSize': danmakuFontSize,
        'danmakuDuration': danmakuDuration,
        'danmakuArea': danmakuArea,
        'danmakuStroke': danmakuStroke,
        'danmakuWeight': danmakuWeight,
        'dimWatched': dimWatched,
        'subAutoUpdate': subAutoUpdate,
        'recommendCounts': {for (final r in _ridKeys) r: recommendCountOf(r)},
      };

  Future<void> apply(Map<String, dynamic> m) async {
    if (m['historyEnabled'] is bool) await setHistoryEnabled(m['historyEnabled'] as bool);
    if (m['watchLaterEnabled'] is bool) await setWatchLaterEnabled(m['watchLaterEnabled'] as bool);
    if (m['minDuration'] is int) await setMinDuration(m['minDuration'] as int);
    if (m['minDurationSub'] is int) await setMinDurationOf('sub', m['minDurationSub'] as int);
    if (m['minDurationHot'] is int) await setMinDurationOf('hot', m['minDurationHot'] as int);
    if (m['rid'] is String) await setRid(m['rid'] as String);
    if (m['homeRid'] is String) await setHomeRid(m['homeRid'] as String);
    if (m['themeMode'] is String) await setThemeMode(m['themeMode'] as String);
    if (m['themeSeed'] is String) await setThemeSeed(m['themeSeed'] as String);
    if (m['dynamicColor'] is bool) await setDynamicColor(m['dynamicColor'] as bool);
    if (m['uiMode'] is String) await setUiMode(m['uiMode'] as String);
    if (m['dockOpacity'] is num) await setDockOpacity((m['dockOpacity'] as num).toDouble());
    if (m['dockSize'] is num) await setDockSize((m['dockSize'] as num).toDouble());
    if (m['dockGlass'] is bool) await setDockGlass(m['dockGlass'] as bool);
    if (m['dockBorder'] is bool) await setDockBorder(m['dockBorder'] as bool);
    if (m['dockShadow'] is bool) await setDockShadow(m['dockShadow'] as bool);
    if (m['rcmdEnabled'] is bool) await setRcmdEnabled(m['rcmdEnabled'] as bool);
    if (m['rcmdBatch'] is int) await setRcmdBatch(m['rcmdBatch'] as int);
    if (m['guestMode'] is bool) await setGuestMode(m['guestMode'] as bool);
    if (m['cardOutline'] is bool) await setCardOutline(m['cardOutline'] as bool);
    if (m['cardTone'] is String) await setCardTone(m['cardTone'] as String);
    if (m['animEnabled'] is bool) await setAnimEnabled(m['animEnabled'] as bool);
    if (m['animPage'] is bool) await setAnimPage(m['animPage'] as bool);
    if (m['animList'] is bool) await setAnimList(m['animList'] as bool);
    if (m['animCard'] is bool) await setAnimCard(m['animCard'] as bool);
    if (m['animSpeed'] is String) await setAnimSpeed(m['animSpeed'] as String);
    if (m['backgroundPlay'] is bool) await setBackgroundPlay(m['backgroundPlay'] as bool);
    if (m['subFilterMid'] is int) await setSubFilterMid(m['subFilterMid'] as int);
    if (m['danmakuOpacity'] is num) await setDanmakuOpacity((m['danmakuOpacity'] as num).toDouble());
    if (m['danmakuFontSize'] is num) await setDanmakuFontSize((m['danmakuFontSize'] as num).toDouble());
    if (m['danmakuDuration'] is num) await setDanmakuDuration((m['danmakuDuration'] as num).toDouble());
    if (m['danmakuArea'] is num) await setDanmakuArea((m['danmakuArea'] as num).toDouble());
    if (m['danmakuStroke'] is bool) await setDanmakuStroke(m['danmakuStroke'] as bool);
    if (m['danmakuWeight'] is int) await setDanmakuWeight(m['danmakuWeight'] as int);
    if (m['dimWatched'] is bool) await setDimWatched(m['dimWatched'] as bool);
    if (m['subAutoUpdate'] is String) await setSubAutoUpdate(m['subAutoUpdate'] as String);
    final rc = m['recommendCounts'];
    if (rc is Map) {
      for (final e in rc.entries) {
        if (e.value is int) await setRecommendCountOf(e.key.toString(), e.value as int);
      }
    }
  }
}
