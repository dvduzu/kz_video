import 'dart:io';
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
  final cookiePath = '${Directory.systemTemp.path}/kzv_cookies';
  await Directory(cookiePath).create(recursive: true);
  VideoRepository.init(VideoRepository.create(cookiePath));
  VideoRepository.instance().restoreLogin();
  runApp(const MyApp());
}

const aospSeeds = <String, Color>{
  '蓝': Color(0xFF6750A4),
  '紫': Colors.deepPurple,
  '靛蓝': Colors.indigo,
  '青': Colors.teal,
  '绿': Colors.green,
  '橙': Colors.orange,
  '红': Colors.red,
  '粉': Colors.pink,
  '棕': Colors.brown,
  '灰': Colors.blueGrey,
};

class MyApp extends StatefulWidget {
  const MyApp({super.key});
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
  Color seed = const Color(0xFF6750A4);

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
      seed = aospSeeds[seedStr] ?? const Color(0xFF6750A4);
    });
  }

  Future<void> setTheme(ThemeMode newMode, Color newSeed) async {
    setState(() { mode = newMode; seed = newSeed; });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', switch (newMode) { ThemeMode.light => 'light', ThemeMode.dark => 'dark', _ => 'system' });
    final seedName = aospSeeds.entries.firstWhere((e) => e.value == newSeed, orElse: () => const MapEntry('蓝', Color(0xFF6750A4))).key;
    await prefs.setString('theme_seed', seedName);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KzVideo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed), useMaterial3: true, snackBarTheme: _snackBarTheme(Brightness.light, seed)),
      darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark), useMaterial3: true, snackBarTheme: _snackBarTheme(Brightness.dark, seed)),
      themeMode: mode,
      home: App(mode: mode, onToggleTheme: toggle, onOpenThemeSettings: _openThemeSettings),
    );
  }

  void toggle() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = mode == ThemeMode.dark || (mode == ThemeMode.system && brightness == Brightness.dark);
    setTheme(isDark ? ThemeMode.light : ThemeMode.dark, seed);
  }

  void _openThemeSettings() {
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
      title: const Text('颜色设置'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('深浅模式', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(spacing: 8, children: {
          ThemeMode.system: '跟随系统',
          ThemeMode.light: '浅色',
          ThemeMode.dark: '深色',
        }.entries.map((e) => ChoiceChip(
          label: Text(e.value),
          selected: mode == e.key,
          onSelected: (_) { setDlg(() {}); setTheme(e.key, seed); },
        )).toList()),
        const SizedBox(height: 16),
        const Text('色调', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(spacing: 8, children: aospSeeds.entries.map((e) => ChoiceChip(
          avatar: CircleAvatar(backgroundColor: e.value, radius: 8),
          label: Text(e.value == Colors.blueGrey ? '灰' : e.key),
          selected: seed == e.value,
          onSelected: (_) { setDlg(() {}); setTheme(mode, e.value); },
        )).toList()),
      ])),
    )));
  }
}

class App extends StatefulWidget {
  final ThemeMode mode;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenThemeSettings;
  const App({super.key, required this.mode, required this.onToggleTheme, required this.onOpenThemeSettings});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  VideoInfo? playing;

  @override
  Widget build(BuildContext context) {
    final video = playing;
    if (video == null) {
      return VideoListScreen(mode: widget.mode, onToggleTheme: widget.onToggleTheme, onOpenThemeSettings: widget.onOpenThemeSettings, onPlay: (v) => setState(() => playing = v));
    }
    return PlayerScreen(video: video, onBack: () => setState(() => playing = null));
  }
}