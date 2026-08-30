import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
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
  VideoPlayerController? controller;
  String? error;
  bool isLandscape = true;
  bool showControls = true;
  Timer? hideTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await VideoRepository.instance().getPlayUrl(widget.video.bvid);
      final buvid3 = VideoRepository.instance().buvid3;
      final headers = <String, String>{
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://www.bilibili.com/video/${widget.video.bvid}',
        if (buvid3 != null) 'Cookie': 'buvid3=$buvid3',
      };
      final c = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: headers);
      await c.initialize();
      c.play();
      c.addListener(() { if (mounted) setState(() {}); });
      if (mounted) setState(() => controller = c);
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
    hideTimer?.cancel();
    controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(appBar: AppBar(title: Text(widget.video.title, maxLines: 1)), body: Center(child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))));
    }
    final c = controller;
    if (c == null || !c.value.isInitialized) {
      return Scaffold(appBar: AppBar(title: Text(widget.video.title, maxLines: 1)), body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(children: [
          Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
          if (!c.value.isPlaying)
            Center(child: IconButton(icon: const Icon(Icons.play_arrow, size: 64, color: Colors.white70), onPressed: () { c.play(); setState(() {}); })),
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
                      icon: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                      onPressed: () { c.value.isPlaying ? c.pause() : c.play(); },
                    ),
                    Text(_format(c.value.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                    const Text(' / ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(_format(c.value.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(child: VideoProgressIndicator(c, allowScrubbing: true, colors: VideoProgressColors(playedColor: Theme.of(context).colorScheme.primary, bufferedColor: Colors.white24, backgroundColor: Colors.white10))),
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
