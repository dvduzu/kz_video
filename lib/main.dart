import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'data/models.dart';
import 'data/video_repository.dart';
import 'ui/player_screen.dart';
import 'ui/video_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final repo = await VideoRepository.create();
  await repo.restoreLogin();
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

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
      final isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
      final useDynamic = this.useDynamic && (isDark ? darkDynamic : lightDynamic) != null;
      final lightCs = useDynamic ? lightDynamic! : theme?.toColorScheme(false) ?? ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
      final darkScheme = darkDynamic ?? lightDynamic;
      final darkCs = useDynamic ? (darkScheme ?? ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: Brightness.dark)) : theme?.toColorScheme(true) ?? ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: Brightness.dark);
      return MaterialApp(
        title: 'KzVideo',
        theme: ThemeData(colorScheme: lightCs, useMaterial3: true, snackBarTheme: _snackBarTheme(Brightness.light, lightCs.primary)),
        darkTheme: ThemeData(colorScheme: darkCs, useMaterial3: true, snackBarTheme: _snackBarTheme(Brightness.dark, darkCs.primary)),
        themeMode: mode,
        home: App(repo: widget.repo, mode: mode, onToggleTheme: toggle, theme: theme, useDynamic: useDynamic, onSetTheme: setTheme),
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
  final Future<void> Function(ThemeMode, SeedTheme?, {bool? dynamic}) onSetTheme;
  const App({super.key, required this.repo, required this.mode, required this.onToggleTheme, required this.theme, required this.useDynamic, required this.onSetTheme});

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
      VideoListScreen(key: _listKey, repo: widget.repo, mode: widget.mode, onToggleTheme: widget.onToggleTheme, seed: widget.theme, useDynamic: widget.useDynamic, onSetTheme: widget.onSetTheme, onPlay: (v) => setState(() => playing = v)),
      if (video != null)
        PlayerScreen(repo: widget.repo, video: video, onBack: () => setState(() => playing = null), onWatched: (v) => _listKey.currentState?.markWatched(v)),
    ]);
  }
}