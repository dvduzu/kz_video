import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/models.dart';
import 'data/video_repository.dart';
import 'ui/player_screen.dart';
import 'ui/video_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final cookiePath = '${Directory.systemTemp.path}/kzv_cookies';
  await Directory(cookiePath).create(recursive: true);
  VideoRepository.init(VideoRepository.create(cookiePath));
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode mode = ThemeMode.system;
  void toggle() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = mode == ThemeMode.dark || (mode == ThemeMode.system && brightness == Brightness.dark);
    setState(() => mode = isDark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KzVideo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark), useMaterial3: true),
      themeMode: mode,
      home: App(mode: mode, onToggleTheme: toggle),
    );
  }
}

class App extends StatefulWidget {
  final ThemeMode mode;
  final VoidCallback onToggleTheme;
  const App({super.key, required this.mode, required this.onToggleTheme});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  VideoInfo? playing;

  @override
  Widget build(BuildContext context) {
    final video = playing;
    if (video == null) {
      return VideoListScreen(mode: widget.mode, onToggleTheme: widget.onToggleTheme, onPlay: (v) => setState(() => playing = v));
    }
    return PlayerScreen(video: video, onBack: () => setState(() => playing = null));
  }
}
