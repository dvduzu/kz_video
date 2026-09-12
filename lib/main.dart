import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'core/app_orientation.dart';
import 'data/models.dart';
import 'data/video_repository.dart';
import 'ui/player_screen.dart';
import 'ui/video_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = await VideoRepository.create();
  await repo.restoreLogin();
  await AppOrientation.apply(repo.settings.uiModeMode);
  final homeRid = repo.settings.homeRid;
  if (homeRid != repo.settings.rid) {
    await repo.settings.setRid(homeRid);
  }
  runApp(MyApp(repo: repo));
}

class MyApp extends StatefulWidget {
  final VideoRepository repo;
  const MyApp({super.key, required this.repo});
  @override
  State<MyApp> createState() => _MyAppState();
}

const _pageTransitions = PageTransitionsTheme(builders: {
  TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
});

const _noPageTransitions = PageTransitionsTheme(builders: {
  TargetPlatform.android: _NoTransitionsBuilder(),
});

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) => child;
}

SnackBarThemeData _snackBarTheme(Brightness brightness, Color seed) {
  final cs = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  return SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    backgroundColor: cs.inverseSurface,
    contentTextStyle: TextStyle(color: cs.onInverseSurface),
    actionTextColor: cs.onInverseSurface,
  );
}

class _MyAppState extends State<MyApp> {
  ThemeMode mode = ThemeMode.system;
  SeedTheme? theme;
  bool useDynamic = false;
  UiMode uiMode = UiMode.auto;
  AnimPrefs anims = const AnimPrefs();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final s = widget.repo.settings;
    setState(() {
      mode = switch (s.themeMode) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system };
      theme = seedThemeForKey(s.themeSeed);
      useDynamic = s.dynamicColor;
      uiMode = s.uiModeMode;
      anims = AnimPrefs(enabled: s.animEnabled, page: s.animPage, list: s.animList, card: s.animCard, speed: s.animSpeed);
    });
  }

  Future<void> setTheme(ThemeMode newMode, SeedTheme? newTheme, {bool? dynamic}) async {
    final next = dynamic ?? useDynamic;
    setState(() { mode = newMode; theme = newTheme; useDynamic = next; });
    final s = widget.repo.settings;
    await s.setThemeMode(switch (newMode) { ThemeMode.light => 'light', ThemeMode.dark => 'dark', _ => 'system' });
    await s.setDynamicColor(next);
    if (!next) await s.setThemeSeed(newTheme?.key ?? '');
  }

  Future<void> setAnims(AnimPrefs a) async {
    setState(() => anims = a);
    final s = widget.repo.settings;
    await s.setAnimEnabled(a.enabled);
    await s.setAnimPage(a.page);
    await s.setAnimList(a.list);
    await s.setAnimCard(a.card);
    await s.setAnimSpeed(a.speed);
  }

  Future<void> setUiMode(UiMode m) async {
    setState(() => uiMode = m);
    await widget.repo.settings.setUiMode(switch (m) { UiMode.phone => 'phone', UiMode.tablet => 'tablet', UiMode.auto => 'auto' });
    await AppOrientation.apply(m);
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
      final isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
      final dynamicOn = this.useDynamic;
      final lightCs = (dynamicOn && lightDynamic != null)
          ? lightDynamic
          : theme?.toColorScheme(false) ?? ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
      final darkCs = (dynamicOn && darkDynamic != null)
          ? darkDynamic
          : theme?.toColorScheme(true) ?? ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: Brightness.dark);
      final useDynamic = dynamicOn && (isDark ? darkDynamic : lightDynamic) != null;
      return MaterialApp(
        title: 'KzVideo',
        theme: ThemeData(colorScheme: lightCs, useMaterial3: true, pageTransitionsTheme: anims.pageOn ? _pageTransitions : _noPageTransitions, snackBarTheme: _snackBarTheme(Brightness.light, lightCs.primary)),
        darkTheme: ThemeData(colorScheme: darkCs, useMaterial3: true, pageTransitionsTheme: anims.pageOn ? _pageTransitions : _noPageTransitions, snackBarTheme: _snackBarTheme(Brightness.dark, darkCs.primary)),
        themeMode: mode,
        home: App(repo: widget.repo, mode: mode, onToggleTheme: toggle, theme: theme, useDynamic: useDynamic, anims: anims, uiMode: uiMode, onSetTheme: setTheme, onSetAnims: setAnims, onSetUiMode: setUiMode),
      );
    });
  }

  void toggle() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = mode == ThemeMode.dark || (mode == ThemeMode.system && brightness == Brightness.dark);
    setTheme(isDark ? ThemeMode.light : ThemeMode.dark, theme);
  }
}

class App extends StatefulWidget {
  final VideoRepository repo;
  final ThemeMode mode;
  final VoidCallback onToggleTheme;
  final SeedTheme? theme;
  final bool useDynamic;
  final AnimPrefs anims;
  final UiMode uiMode;
  final Future<void> Function(ThemeMode, SeedTheme?, {bool? dynamic}) onSetTheme;
  final ValueChanged<AnimPrefs> onSetAnims;
  final ValueChanged<UiMode> onSetUiMode;
  const App({super.key, required this.repo, required this.mode, required this.onToggleTheme, required this.theme, required this.useDynamic, required this.anims, required this.uiMode, required this.onSetTheme, required this.onSetAnims, required this.onSetUiMode});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  VideoInfo? playing;
  final _listKey = GlobalKey<VideoListScreenState>();

  @override
  Widget build(BuildContext context) {
    final video = playing;
    return Stack(children: [
      VideoListScreen(key: _listKey, repo: widget.repo, mode: widget.mode, onToggleTheme: widget.onToggleTheme, seed: widget.theme, useDynamic: widget.useDynamic, anims: widget.anims, uiMode: widget.uiMode, onSetTheme: widget.onSetTheme, onSetAnims: widget.onSetAnims, onSetUiMode: widget.onSetUiMode, onPlay: (v) => setState(() => playing = v)),
      AnimatedSwitcher(
        duration: widget.anims.pageOn ? widget.anims.dur(280) : Duration.zero,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.04, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        child: video == null
            ? const SizedBox.shrink(key: ValueKey('no-player'))
            : PlayerScreen(key: ValueKey('player-${video.bvid}'), repo: widget.repo, video: video, onBack: () => setState(() => playing = null), onWatched: (v) => _listKey.currentState?.markWatched(v)),
      ),
    ]);
  }
}