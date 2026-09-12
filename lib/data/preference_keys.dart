abstract final class PreferenceKeys {
  static const blacklist = 'blacklist';
  static const history = 'history';
  static const watchLater = 'watch_later';
  static const subscriptions = 'subscriptions';
  static const watched = 'watched';
  static const guestMode = 'guest_mode';

  static const settingHistory = 'setting_history';
  static const settingWatchLater = 'setting_watch_later';
  static const settingMinDuration = 'setting_min_duration';
  static const settingMinDurationSub = 'setting_min_duration_sub';
  static const settingMinDurationHot = 'setting_min_duration_hot';
  static const settingRid = 'setting_rid';
  static const settingHomeRid = 'setting_home_rid';
  static const settingRcmdEnabled = 'setting_rcmd_enabled';
  static const settingRcmdBatch = 'setting_rcmd_batch';
  static const settingCardOutline = 'setting_card_outline';
  static const settingCardTone = 'setting_card_tone';
  static const settingAnimEnabled = 'setting_animations';
  static const settingAnimPage = 'setting_anim_page';
  static const settingAnimList = 'setting_anim_list';
  static const settingAnimCard = 'setting_anim_card';
  static const settingAnimSpeed = 'setting_anim_speed';
  static const settingBackgroundPlay = 'setting_background_play';
  static const settingSubFilterMid = 'setting_sub_filter_mid';
  static const settingDmOpacity = 'setting_dm_opacity';
  static const settingDmFontSize = 'setting_dm_fontsize';
  static const settingDmDuration = 'setting_dm_duration';
  static const settingDmArea = 'setting_dm_area';
  static const settingDmStroke = 'setting_dm_stroke';

  static const themeMode = 'theme_mode';
  static const themeSeed = 'theme_seed';
  static const dynamicColor = 'dynamic_color';
  static const uiMode = 'ui_mode';
  static const debugUnlimitedRefresh = 'debug_unlimited_refresh';
  static const dailyCachePrefix = 'daily_';

  static String recommendCount(String rid) => 'setting_recommend_count_$rid';
  static String progress(String bvid) => 'progress_$bvid';
  static String refreshCount(String today) => 'refresh_count_$today';
  static String daily(String rid, String today) => 'daily_${rid}_$today';
  static String dailyTs(String rid, String today) => 'daily_ts_${rid}_$today';
}
