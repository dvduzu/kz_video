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
}
