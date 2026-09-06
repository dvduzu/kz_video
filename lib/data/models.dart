import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

enum KzStyle { tonalSpot, spritz, fruitSalad, vibrant, monochrome }

class _Spec {
  final double chroma;
  final double Function(double hue) hueShift;
  const _Spec(this.chroma, this.hueShift);
}

double _hueShift(double hue, List<(double, double)> table) {
  for (var i = 0; i < table.length - 1; i++) {
    final (lo, shift) = table[i];
    final (hi, _) = table[i + 1];
    if (hue >= lo && hue < hi) return shift;
  }
  return 0;
}

const _vibrantSecondary = [(0.0, 18.0), (41.0, 15.0), (61.0, 10.0), (101.0, 12.0), (131.0, 15.0), (181.0, 18.0), (251.0, 15.0), (301.0, 12.0), (360.0, 12.0)];
const _vibrantTertiary = [(0.0, 35.0), (41.0, 30.0), (61.0, 20.0), (101.0, 25.0), (131.0, 30.0), (181.0, 35.0), (251.0, 30.0), (301.0, 25.0), (360.0, 25.0)];

final _a1Specs = <KzStyle, _Spec>{
  KzStyle.tonalSpot: _Spec(36, (_) => 0),
  KzStyle.spritz: _Spec(12, (_) => 0),
  KzStyle.fruitSalad: _Spec(48, (_) => -50),
  KzStyle.vibrant: _Spec(48, (_) => 0),
  KzStyle.monochrome: _Spec(0, (_) => 0),
};

final _a2Specs = <KzStyle, _Spec>{
  KzStyle.tonalSpot: _Spec(16, (_) => 0),
  KzStyle.spritz: _Spec(8, (_) => 0),
  KzStyle.fruitSalad: _Spec(36, (_) => -30),
  KzStyle.vibrant: _Spec(24, (h) => _hueShift(h, _vibrantSecondary)),
  KzStyle.monochrome: _Spec(0, (_) => 0),
};

final _a3Specs = <KzStyle, _Spec>{
  KzStyle.tonalSpot: _Spec(24, (_) => 60),
  KzStyle.spritz: _Spec(16, (_) => 30),
  KzStyle.fruitSalad: _Spec(36, (_) => 0),
  KzStyle.vibrant: _Spec(32, (h) => _hueShift(h, _vibrantTertiary)),
  KzStyle.monochrome: _Spec(0, (_) => 0),
};

class SeedTheme {
  final String key;
  final Color seed;
  final KzStyle style;
  const SeedTheme(this.key, this.seed, this.style);

  String get label => switch (style) {
    KzStyle.tonalSpot => '音调',
    KzStyle.spritz => '清冽',
    KzStyle.fruitSalad => '果色',
    KzStyle.vibrant => '鲜艳',
    KzStyle.monochrome => '单色',
  };

  Color _transform(double tone, _Spec spec) {
    final h = Hct.fromInt(seed.toARGB32());
    final hue = (h.hue + spec.hueShift(h.hue)) % 360;
    return Color(Hct.from(hue, spec.chroma, tone).toInt());
  }

  List<Color> get trio => [
    _transform(80, _a1Specs[style]!),
    _transform(90, _a2Specs[style]!),
    _transform(60, _a3Specs[style]!),
  ];

  DynamicScheme _scheme(bool isDark) {
    final sc = Hct.fromInt(seed.toARGB32());
    final (a1h, a1c, a2h, a2c, a3h, a3c) = switch (style) {
      KzStyle.tonalSpot => (sc.hue, 36.0, sc.hue, 16.0, (sc.hue + 60) % 360, 24.0),
      KzStyle.spritz => (sc.hue, 12.0, sc.hue, 8.0, (sc.hue + 30) % 360, 16.0),
      KzStyle.fruitSalad => ((sc.hue - 50) % 360, 48.0, (sc.hue - 30) % 360, 36.0, sc.hue, 36.0),
      KzStyle.vibrant => (sc.hue, 48.0, (sc.hue + _hueShift(sc.hue, _vibrantSecondary)) % 360, 24.0, (sc.hue + _hueShift(sc.hue, _vibrantTertiary)) % 360, 32.0),
      KzStyle.monochrome => (0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
    };
    final hue1 = a1h % 360;
    final hue2 = a2h % 360;
    final hue3 = a3h % 360;
    final variant = switch (style) {
      KzStyle.tonalSpot => Variant.tonalSpot,
      KzStyle.spritz => Variant.content,
      KzStyle.fruitSalad => Variant.fruitSalad,
      KzStyle.vibrant => Variant.vibrant,
      KzStyle.monochrome => Variant.content,
    };
    return DynamicScheme(
      sourceColorHct: sc,
      variant: variant,
      isDark: isDark,
      primaryPalette: TonalPalette.of(hue1, a1c),
      secondaryPalette: TonalPalette.of(hue2, a2c),
      tertiaryPalette: TonalPalette.of(hue3, a3c),
      neutralPalette: TonalPalette.of(sc.hue, _neutralChroma),
      neutralVariantPalette: TonalPalette.of(sc.hue, _neutralVariantChroma),
    );
  }

  double get _neutralChroma => switch (style) {
    KzStyle.tonalSpot => 6,
    KzStyle.spritz => 2,
    KzStyle.fruitSalad => 10,
    KzStyle.vibrant => 10,
    KzStyle.monochrome => 0,
  };

  double get _neutralVariantChroma => switch (style) {
    KzStyle.tonalSpot => 8,
    KzStyle.spritz => 2,
    KzStyle.fruitSalad => 16,
    KzStyle.vibrant => 12,
    KzStyle.monochrome => 0,
  };

  ColorScheme toColorScheme(bool isDark) {
    final s = _scheme(isDark);
    return ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: Color(s.primary),
      onPrimary: Color(s.onPrimary),
      primaryContainer: Color(s.primaryContainer),
      onPrimaryContainer: Color(s.onPrimaryContainer),
      secondary: Color(s.secondary),
      onSecondary: Color(s.onSecondary),
      secondaryContainer: Color(s.secondaryContainer),
      onSecondaryContainer: Color(s.onSecondaryContainer),
      tertiary: Color(s.tertiary),
      onTertiary: Color(s.onTertiary),
      tertiaryContainer: Color(s.tertiaryContainer),
      onTertiaryContainer: Color(s.onTertiaryContainer),
      error: Color(s.error),
      onError: Color(s.onError),
      errorContainer: Color(s.errorContainer),
      onErrorContainer: Color(s.onErrorContainer),
      surface: Color(s.surface),
      onSurface: Color(s.onSurface),
      surfaceContainerLowest: Color(s.surfaceContainerLowest),
      surfaceContainerLow: Color(s.surfaceContainerLow),
      surfaceContainer: Color(s.surfaceContainer),
      surfaceContainerHigh: Color(s.surfaceContainerHigh),
      surfaceContainerHighest: Color(s.surfaceContainerHighest),
      onSurfaceVariant: Color(s.onSurfaceVariant),
      inverseSurface: Color(s.inverseSurface),
      inversePrimary: Color(s.inversePrimary),
      outline: Color(s.outline),
      outlineVariant: Color(s.outlineVariant),
      shadow: Color(s.shadow),
      scrim: Color(s.scrim),
      surfaceTint: Color(s.surfaceTint),
    );
  }
}

final _hues = [140, 175, 210, 245, 280, 315, 350, 35, 70, 105];

String _hueName(int hue) => switch (hue) {
  140 => '绿', 175 => '青绿', 210 => '青', 245 => '天蓝',
  280 => '蓝', 315 => '紫', 350 => '品红', 35 => '红', 70 => '橙', 105 => '黄绿',
  _ => '$hue',
};

final aospSeeds = <String, Color>{
  for (final t in aospThemes) t.key: t.seed,
};

final aospThemes = <SeedTheme>[
  for (final h in _hues)
    for (final s in const [KzStyle.tonalSpot, KzStyle.spritz, KzStyle.fruitSalad, KzStyle.vibrant])
      SeedTheme('${_hueName(h)}·${s.name}', Color(Hct.from(h.toDouble(), 40, 40).toInt()), s),
  const SeedTheme('单色·monochrome', Color(0xFF000000), KzStyle.monochrome),
];

SeedTheme? seedThemeForKey(String key) {
  if (key.isEmpty) return null;
  for (final t in aospThemes) {
    if (t.key == key) return t;
  }
  final legacyColor = aospSeeds[key];
  if (legacyColor != null) {
    return aospThemes.firstWhere((t) => t.seed.toARGB32() == legacyColor.toARGB32(), orElse: () => aospThemes.first);
  }
  return null;
}

class VideoInfo {
  final String bvid;
  final String title;
  final String pic;
  final int duration;
  final String owner;
  final int view;
  final int pubdate;
  final int mid;
  final int tid;
  VideoInfo({required this.bvid, required this.title, required this.pic, required this.duration, required this.owner, required this.view, this.pubdate = 0, this.mid = 0, this.tid = 0});
  factory VideoInfo.fromJson(Map<String, dynamic> json) => VideoInfo(
    bvid: json['bvid'] as String,
    title: json['title'] as String,
    pic: json['pic'] as String,
    duration: json['duration'] as int,
    owner: json['owner'] as String,
    view: json['view'] as int,
    pubdate: json['pubdate'] as int? ?? 0,
    mid: json['mid'] as int? ?? 0,
    tid: json['tid'] as int? ?? 0,
  );
  Map<String, dynamic> toJson() => {'bvid': bvid, 'title': title, 'pic': pic, 'duration': duration, 'owner': owner, 'view': view, 'pubdate': pubdate, 'mid': mid, 'tid': tid};
}

class SubtitleCue {
  final double from;
  final double to;
  final String content;
  SubtitleCue({required this.from, required this.to, required this.content});
}

class SearchUser {
  final int mid;
  final String uname;
  final String sign;
  final int fans;
  final String face;
  SearchUser({required this.mid, required this.uname, required this.sign, required this.fans, required this.face});
}