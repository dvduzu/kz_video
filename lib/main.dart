import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/models.dart';
import 'data/video_repository.dart';
import 'ui/player_screen.dart';
import 'ui/video_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final repo = await VideoRepository.create();
  repo.restoreLogin();
  final homeRid = repo.settings.homeRid;
  if (homeRid.isNotEmpty && homeRid != repo.settings.rid) {
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
  Color? seed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('theme_mode') ?? 'system';
    final seedStr = prefs.getString('theme_seed') ?? '';
    setState(() {
      mode = switch (modeStr) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system };
      seed = seedStr.isEmpty ? null : (aospSeeds[seedStr] ?? const Color(0xFF6750A4));
    });
  }

  Future<void> setTheme(ThemeMode newMode, Color? newSeed) async {
    setState(() { mode = newMode; seed = newSeed; });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', switch (newMode) { ThemeMode.light => 'light', ThemeMode.dark => 'dark', _ => 'system' });
    final seedName = newSeed == null ? '' : (aospSeeds.entries.firstWhere((e) => e.value == newSeed, orElse: () => const MapEntry('蓝', Color(0xFF6750A4))).key);
    await prefs.setString('theme_seed', seedName);
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
      final isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
      final seedColor = seed ?? ((isDark ? darkDynamic : lightDynamic)?.primary ?? const Color(0xFF6750A4));
      return MaterialApp(
        title: 'KzVideo',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seedColor), useMaterial3: true, snackBarTheme: _snackBarTheme(Brightness.light, seedColor)),
        darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark), useMaterial3: true, snackBarTheme: _snackBarTheme(Brightness.dark, seedColor)),
        themeMode: mode,
        home: App(repo: widget.repo, mode: mode, onToggleTheme: toggle, seed: seed, onSetTheme: setTheme),
      );
    });
  }

  void toggle() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = mode == ThemeMode.dark || (mode == ThemeMode.system && brightness == Brightness.dark);
    setTheme(isDark ? ThemeMode.light : ThemeMode.dark, seed);
  }
}

class App extends StatefulWidget {
  final VideoRepository repo;
  final ThemeMode mode;
  final VoidCallback onToggleTheme;
  final Color? seed;
  final Future<void> Function(ThemeMode, Color?) onSetTheme;
  const App({super.key, required this.repo, required this.mode, required this.onToggleTheme, required this.seed, required this.onSetTheme});

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
      VideoListScreen(key: _listKey, repo: widget.repo, mode: widget.mode, onToggleTheme: widget.onToggleTheme, seed: widget.seed, onSetTheme: widget.onSetTheme, onPlay: (v) => setState(() => playing = v)),
      if (video != null)
        PlayerScreen(repo: widget.repo, video: video, onBack: () => setState(() => playing = null), onWatched: (v) => _listKey.currentState?.markWatched(v)),
    ]);
  }
}