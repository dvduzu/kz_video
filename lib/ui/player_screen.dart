import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../data/models.dart';
import '../data/video_repository.dart';

class PlayerScreen extends StatefulWidget {
  final VideoInfo video;
  final VoidCallback onBack;
  const PlayerScreen({super.key, required this.video, required this.onBack});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player;
  late final VideoController controller;
  String? error;
  bool isLandscape = true;
  bool showControls = true;
  Timer? hideTimer;
  double speed = 1.0;
  int? currentQn;
  bool ready = false;
  bool watchLaterEnabled = true;
  static const qnLabels = {80: '高清(1080p)', 64: '标清(720p)', 32: '流畅(480p)'};

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    player = Player();
    controller = VideoController(player);
    _listen();
    VideoRepository.instance().isWatchLaterEnabled().then((v) { if (mounted) setState(() => watchLaterEnabled = v); });
    _load();
  }

  void _listen() {
    player.stream.playing.listen((_) { if (mounted) setState(() {}); });
    player.stream.position.listen((_) { if (mounted) setState(() {}); });
    player.stream.duration.listen((_) { if (mounted) setState(() {}); });
    player.stream.error.listen((e) { if (mounted && e != null) setState(() => error = e.toString()); });
  }

  Future<void> _load({int? qn}) async {
    setState(() { error = null; });
    try {
      if (ready) {
        await VideoRepository.instance().saveProgress(widget.video.bvid, player.state.position.inMilliseconds, player.state.duration.inMilliseconds);
        await player.stop();
        setState(() => ready = false);
      }
      final url = await VideoRepository.instance().getPlayUrl(widget.video.bvid, qn: qn);
      final buvid3 = VideoRepository.instance().buvid3;
      final headers = <String, String>{
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://www.bilibili.com/video/${widget.video.bvid}',
        if (buvid3 != null) 'Cookie': 'buvid3=$buvid3',
      };
      await player.open(Media(url, httpHeaders: headers));
      await player.setRate(speed);
      final progress = await VideoRepository.instance().getProgress(widget.video.bvid);
      if (progress != null && progress.durationMs > 0 && progress.positionMs < progress.durationMs) {
        await player.seek(Duration(milliseconds: progress.positionMs));
      }
      await player.play();
      if (mounted) setState(() { ready = true; currentQn = qn; });
      VideoRepository.instance().addHistory(widget.video);
      _startHideTimer();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  void _startHideTimer() {
    hideTimer?.cancel();
    hideTimer = Timer(const Duration(seconds: 3), () { if (mounted) setState(() => showControls = false); });
  }

  void _toggleControls() {
    setState(() => showControls = !showControls);
    if (showControls) _startHideTimer();
  }

  void _toggleOrientation() {
    setState(() => isLandscape = !isLandscape);
    SystemChrome.setPreferredOrientations(isLandscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    if (ready) {
      VideoRepository.instance().saveProgress(widget.video.bvid, player.state.position.inMilliseconds, player.state.duration.inMilliseconds);
    }
    hideTimer?.cancel();
    player.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(appBar: AppBar(title: Text(widget.video.title, maxLines: 1)), body: Center(child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))));
    }
    if (!ready) {
      return Scaffold(appBar: AppBar(title: Text(widget.video.title, maxLines: 1)), body: const Center(child: CircularProgressIndicator()));
    }
    final position = player.state.position;
    final duration = player.state.duration;
    final playing = player.state.playing;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(children: [
          Center(child: Video(controller: controller, controls: NoVideoControls)),
          if (!playing)
            Center(child: IconButton(icon: const Icon(Icons.play_arrow, size: 64, color: Colors.white70), onPressed: () { player.play(); })),
          AnimatedOpacity(
            opacity: showControls ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Column(children: [
              SafeArea(
                child: Container(
                  color: Colors.black38,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(children: [
                    IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back, color: Colors.white)),
                    Expanded(child: Text(widget.video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white))),
                    TextButton(onPressed: _toggleOrientation, child: Text(isLandscape ? '竖屏' : '横屏', style: const TextStyle(color: Colors.white))),
                  ]),
                ),
              ),
              const Spacer(),
              SafeArea(
                child: Container(
                  color: Colors.black38,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(children: [
                    IconButton(
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
                      onPressed: () { playing ? player.pause() : player.play(); },
                    ),
                    Text(_format(position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                    const Text(' / ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(_format(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(child: _ProgressBar(player: player, position: position, duration: duration)),
                    PopupMenuButton<double>(
                      tooltip: '倍速',
                      color: Colors.black87,
                      initialValue: speed,
                      onSelected: (v) { player.setRate(v); setState(() => speed = v); },
                      itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) => PopupMenuItem(value: s, child: Text('${s}x', style: const TextStyle(color: Colors.white)))).toList(),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${speed}x', style: const TextStyle(color: Colors.white, fontSize: 12))),
                    ),
                    PopupMenuButton<int>(
                      tooltip: '清晰度',
                      color: Colors.black87,
                      initialValue: currentQn ?? 80,
                      onSelected: (q) { if (q != currentQn) _load(qn: q); },
                      itemBuilder: (_) => qnLabels.entries.map((e) => PopupMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(color: Colors.white)))).toList(),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(qnLabels[currentQn ?? 80] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12))),
                    ),
                    if (watchLaterEnabled)
                      IconButton(
                        tooltip: '稍后再看',
                        icon: const Icon(Icons.bookmark_add_outlined, color: Colors.white),
                        onPressed: () async {
                          await VideoRepository.instance().addWatchLater(widget.video);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入稍后再看')));
                        },
                      ),
                    IconButton(icon: const Icon(Icons.fullscreen, color: Colors.white), onPressed: _toggleOrientation),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final Player player;
  final Duration position;
  final Duration duration;
  const _ProgressBar({required this.player, required this.position, required this.duration});
  @override
  Widget build(BuildContext context) {
    final max = duration.inMilliseconds.toDouble();
    final cur = position.inMilliseconds.toDouble().clamp(0.0, max);
    return SliderTheme(
      data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 12)),
      child: Slider(
        value: max <= 0 ? 0.0 : cur,
        max: max <= 0 ? 1.0 : max,
        activeColor: Theme.of(context).colorScheme.primary,
        inactiveColor: Colors.white24,
        onChangeEnd: (v) => player.seek(Duration(milliseconds: v.round())),
        onChanged: (_) {},
      ),
    );
  }
}