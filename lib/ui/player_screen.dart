import 'dart:async';
import 'package:canvas_danmaku/canvas_danmaku.dart' hide DanmakuItem;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../data/native_player.dart';
import '../data/video_repository.dart';
import '../core/logger.dart';
import 'native_video.dart';

class PlayerScreen extends StatefulWidget {
  final VideoRepository repo;
  final VideoInfo video;
  final VoidCallback onBack;
  final ValueChanged<VideoInfo> onWatched;
  const PlayerScreen({super.key, required this.repo, required this.video, required this.onBack, required this.onWatched});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final NativePlayer player;
  String? error;
  bool showControls = true;
  Timer? hideTimer;
  double speed = 1.0;
  int? currentQn;
  bool ready = false;
  bool longPressAccel = false;
  bool watchLaterEnabled = true;
  bool subscribed = false;
  bool watchLaterAdded = false;
  bool subtitleOn = false;
  List<SubtitleCue>? _subtitleCues;
  double subtitleFontSize = 32;
  double subtitlePos = 24;
  bool subtitleSemi = false;
  bool danmakuOn = true;
  List<DanmakuItem> _danmaku = [];
  double _dmOpacity = 0.9;
  double _dmFontSize = 16;
  double _dmDuration = 8;
  double _dmArea = 0.5;
  bool _dmStroke = true;
  DanmakuController<Object?>? _dmController;
  int _dmCursor = 0;
  int _lastPumpMs = 0;
  DateTime? _loadT0;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Duration _danmakuPos = Duration.zero;
  static const qnLabels = {80: '高清(1080p)', 64: '标清(720p)', 32: '流畅(480p)'};

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addObserver(this);
    player = NativePlayer.instance;
    _listen();
    widget.repo.isWatchLaterEnabled().then((v) { if (mounted) setState(() => watchLaterEnabled = v); });
    if (widget.video.mid > 0) {
      widget.repo.isSubscribed(widget.video.mid).then((v) { if (mounted) setState(() => subscribed = v); });
    }
    widget.repo.getWatchLater().then((list) {
      if (mounted) setState(() => watchLaterAdded = list.any((v) => v.bvid == widget.video.bvid));
    });
    _ticker = createTicker((elapsed) {
      final dt = elapsed - _lastTick;
      _lastTick = elapsed;
      if (player.state.playing) {
        _danmakuPos += dt;
        _pumpDanmaku();
      }
    })..start();
    final ds = widget.repo.settings;
    _dmOpacity = ds.danmakuOpacity;
    _dmFontSize = ds.danmakuFontSize;
    _dmDuration = ds.danmakuDuration;
    _dmArea = ds.danmakuArea;
    _dmStroke = ds.danmakuStroke;
    _load();
  }

  void _listen() {
    player.stream.playing.listen((playing) {
      if (playing && _loadT0 != null) {
        KzvLogger.debug('load: firstFrame ${DateTime.now().difference(_loadT0!).inMilliseconds}ms');
        _loadT0 = null;
      }
      if (playing) {
        _dmController?.resume();
      } else {
        _dmController?.pause();
      }
      if (mounted) setState(() {});
    });
    player.stream.position.listen((p) {
      _danmakuPos = p;
      if (mounted) setState(() {});
    });
    player.stream.duration.listen((_) { if (mounted) setState(() {}); });
    player.stream.completed.listen((_) {
      final pos = player.state.position.inMilliseconds;
      final dur = player.state.duration.inMilliseconds;
      if (dur > 0 && pos >= dur * 0.95) {
        widget.onWatched(widget.video);
      }
    });
    player.stream.error.listen((e) { _onPlaybackError(e); });
  }

  int _retryCount = 0;
  Future<void> _onPlaybackError(Object? e) async {
    if (!mounted || e == null) return;
    if (_retryCount >= 2) {
      setState(() => error = '播放中断：$e');
      return;
    }
    _retryCount++;
    // 视频轨中断/格式错误：尝试降一个清晰度重载
    final q = (currentQn ?? 80) == 80 ? 64 : 32;
    KzvLogger.debug('playback error, retry qn=$q: $e');
    await _load(qn: q);
  }

  Future<void> _load({int? qn}) async {
    final t0 = DateTime.now();
    _loadT0 = t0;
    setState(() { error = null; });
    try {
      int? resumeMs;
      if (ready) {
        resumeMs = player.state.position.inMilliseconds;
        await widget.repo.saveProgress(widget.video.bvid, resumeMs, player.state.duration.inMilliseconds);
        await player.stop();
        setState(() => ready = false);
        setState(() { _subtitleCues = null; });
      }
      final tPlay = DateTime.now();
      final info = await widget.repo.getPlayUrl(widget.video.bvid, qn: qn);
      KzvLogger.debug('load: getPlayUrl ${DateTime.now().difference(tPlay).inMilliseconds}ms qn=${qn ?? 80}');
      final buvid3 = widget.repo.buvid3;
      final headers = <String, String>{
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://www.bilibili.com/video/${widget.video.bvid}',
        if (buvid3 != null) 'Cookie': 'buvid3=$buvid3',
      };
      final tOpen = DateTime.now();
      await player.open(info.videoUrl, audio: info.audioUrl, headers: headers, title: widget.video.title, artist: widget.video.owner, artwork: widget.video.pic);
      KzvLogger.debug('load: open ${DateTime.now().difference(tOpen).inMilliseconds}ms');
      await player.setRate(speed);
      final seekTarget = resumeMs ?? (await widget.repo.getProgress(widget.video.bvid))?.positionMs;
      if (seekTarget != null && seekTarget > 0) {
        for (var i = 0; i < 20 && player.state.duration.inMilliseconds <= 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        await player.seek(Duration(milliseconds: seekTarget));
      }
      await player.play();
      if (mounted) setState(() { ready = true; currentQn = qn; });
      _retryCount = 0;
      widget.repo.addHistory(widget.video);
      _loadSubtitle();
      _loadDanmaku();
      _startHideTimer();
      KzvLogger.debug('load: total ${DateTime.now().difference(t0).inMilliseconds}ms');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _loadSubtitle() async {
    final cues = await widget.repo.getSubtitles(widget.video.bvid);
    if (!mounted || cues == null || cues.isEmpty) return;
    KzvLogger.debug('subtitle loaded cues=${cues.length}');
    setState(() { _subtitleCues = cues; });
  }

  Future<void> _loadDanmaku() async {
    final list = await widget.repo.getDanmaku(widget.video.bvid, durationSec: widget.video.duration);
    if (!mounted || list.isEmpty) return;
    setState(() => _danmaku = list);
  }

  DanmakuItemType _dmType(int mode) {
    if (mode == 4) return DanmakuItemType.bottom;
    if (mode == 5) return DanmakuItemType.top;
    return DanmakuItemType.scroll;
  }

  DanmakuOption _dmOption() => DanmakuOption(
    fontSize: _dmFontSize,
    fontWeight: FontWeight.w600.index,
    area: _dmArea,
    duration: _dmDuration,
    opacity: _dmOpacity,
    strokeWidth: _dmStroke ? 1.2 : 0,
    safeArea: true,
    lineHeight: 1.2,
  );

  void _updateDmOption() {
    _dmController?.updateOption(_dmOption());
  }

  void _pumpDanmaku() {
    final c = _dmController;
    if (c == null || !danmakuOn || _danmaku.isEmpty) return;
    final posMs = _danmakuPos.inMilliseconds;
    if (posMs < _lastPumpMs - 1000) {
      c.clear();
      _dmCursor = 0;
      while (_dmCursor < _danmaku.length && (_danmaku[_dmCursor].time * 1000) <= posMs) {
        _dmCursor++;
      }
    }
    while (_dmCursor < _danmaku.length && (_danmaku[_dmCursor].time * 1000) <= posMs) {
      final d = _danmaku[_dmCursor];
      final base = Color(0xFF000000 | d.color);
      c.addDanmaku(DanmakuContentItem(
        d.text,
        color: base.computeLuminance() < 0.05 ? Colors.white : base,
        type: _dmType(d.mode),
      ));
      _dmCursor++;
    }
    _lastPumpMs = posMs;
  }

  void _setSubtitle(bool on) {
    subtitleOn = on;
    setState(() {});
  }

  String? _currentSubtitle() {
    if (!subtitleOn || _subtitleCues == null) return null;
    final pos = player.state.position.inMilliseconds / 1000.0;
    for (final c in _subtitleCues!) {
      if (pos >= c.from && pos <= c.to) return c.content;
    }
    return null;
  }

  void _showSubtitleMenu() {
    showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setModalState) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
            title: const Text('显示字幕'),
            value: subtitleOn,
            onChanged: (v) { _setSubtitle(v); setModalState(() {}); },
          ),
          const Text('字号', style: TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: subtitleFontSize,
            min: 20, max: 60,
            onChanged: (v) { subtitleFontSize = v; setModalState(() {}); setState(() {}); },
          ),
          const Text('位置（越高越靠上）', style: TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: subtitlePos,
            min: 10, max: 200,
            onChanged: (v) { subtitlePos = v; setModalState(() {}); setState(() {}); },
          ),
          SwitchListTile(
            title: const Text('半透明背景'),
            value: subtitleSemi,
            onChanged: (v) { subtitleSemi = v; setModalState(() {}); setState(() {}); },
          ),
        ]),
      ));
    });
  }

  void _showDanmakuMenu() {
    final s = widget.repo.settings;
    showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setModalState) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
            title: const Text('显示弹幕'),
            value: danmakuOn,
            onChanged: (v) { setState(() => danmakuOn = v); setModalState(() {}); },
          ),
          Row(children: [
            const Text('透明度'),
            Expanded(child: Slider(value: _dmOpacity, min: 0.2, max: 1.0, divisions: 8,
              label: '${(_dmOpacity * 100).round()}%',
              onChanged: (v) { setState(() => _dmOpacity = v); setModalState(() {}); s.setDanmakuOpacity(v); _updateDmOption(); })),
            Text('${(_dmOpacity * 100).round()}%'),
          ]),
          Row(children: [
            const Text('字号'),
            Expanded(child: Slider(value: _dmFontSize, min: 12, max: 28, divisions: 8,
              label: '${_dmFontSize.round()}',
              onChanged: (v) { setState(() => _dmFontSize = v); setModalState(() {}); s.setDanmakuFontSize(v); _updateDmOption(); })),
            Text('${_dmFontSize.round()}'),
          ]),
          Row(children: [
            const Text('速度'),
            Expanded(child: Slider(value: _dmDuration, min: 4, max: 16, divisions: 6,
              label: '${_dmDuration.round()}s',
              onChanged: (v) { setState(() => _dmDuration = v); setModalState(() {}); s.setDanmakuDuration(v); _updateDmOption(); })),
            Text('${_dmDuration.round()}s'),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Text('显示区域'),
            const SizedBox(width: 8),
            Expanded(child: Wrap(spacing: 6, children: [0.1, 0.25, 0.5, 0.75, 1.0].map((a) => ChoiceChip(
              label: Text('${(a * 100).round()}%'),
              selected: (_dmArea - a).abs() < 0.01,
              onSelected: (_) {
                setState(() => _dmArea = a);
                setModalState(() {});
                s.setDanmakuArea(a);
                _updateDmOption();
                _dmController?.clear();
              },
            )).toList())),
          ]),
          SwitchListTile(
            title: const Text('描边加粗'),
            subtitle: const Text('复杂画面下更清晰'),
            value: _dmStroke,
            onChanged: (v) { setState(() => _dmStroke = v); setModalState(() {}); s.setDanmakuStroke(v); _updateDmOption(); },
          ),
        ]),
      ));
    });
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
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    SystemChrome.setPreferredOrientations(landscape
        ? [DeviceOrientation.portraitUp]
        : [DeviceOrientation.landscapeLeft]);
  }

  String? _toastMsg;
  Timer? _toastTimer;
  void _toast(String msg, {int ms = 1500}) {
    if (!mounted) return;
    _toastTimer?.cancel();
    setState(() => _toastMsg = msg);
    _toastTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _toastMsg = null);
    });
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
      widget.repo.saveProgress(widget.video.bvid, player.state.position.inMilliseconds, player.state.duration.inMilliseconds);
    }
    hideTimer?.cancel();
    _toastTimer?.cancel();
    _ticker.dispose();
    player.stop();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !widget.repo.settings.backgroundPlay) {
      player.pause();
    }
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
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final playBtn = IconButton(
      icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
      onPressed: () { playing ? player.pause() : player.play(); },
    );
    final timeLabel = Row(mainAxisSize: MainAxisSize.min, children: [
      Text(_format(position), style: const TextStyle(color: Colors.white, fontSize: 12)),
      const Text(' / ', style: TextStyle(color: Colors.white70, fontSize: 12)),
      Text(_format(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
    final speedBtn = PopupMenuButton<double>(
      tooltip: '倍速',
      color: Colors.black87,
      initialValue: speed,
      onSelected: (v) { player.setRate(v); setState(() => speed = v); },
      itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) => PopupMenuItem(value: s, child: Text('${s}x', style: const TextStyle(color: Colors.white)))).toList(),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${speed}x', style: const TextStyle(color: Colors.white, fontSize: 12))),
    );
    final qnBtn = PopupMenuButton<int>(
      tooltip: '清晰度',
      color: Colors.black87,
      initialValue: currentQn ?? 80,
      onSelected: (q) { if (q != currentQn) _load(qn: q); },
      itemBuilder: (_) => qnLabels.entries.map((e) => PopupMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(color: Colors.white)))).toList(),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(qnLabels[currentQn ?? 80] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12))),
    );
    final subBtn = (_subtitleCues != null && _subtitleCues!.isNotEmpty)
        ? IconButton(
            tooltip: subtitleOn ? '关闭字幕' : '字幕',
            icon: Icon(subtitleOn ? Icons.closed_caption : Icons.closed_caption_off, color: subtitleOn ? Theme.of(context).colorScheme.primary : Colors.white),
            onPressed: _showSubtitleMenu,
          )
        : null;
    final dmBtn = IconButton(
      tooltip: '弹幕设置',
      icon: Icon(danmakuOn ? Icons.chat : Icons.chat_bubble_outline, color: danmakuOn ? Theme.of(context).colorScheme.primary : Colors.white),
      onPressed: _showDanmakuMenu,
    );
    final favBtn = watchLaterEnabled
        ? IconButton(
            tooltip: watchLaterAdded ? '取消收藏' : '收藏',
            icon: Icon(watchLaterAdded ? Icons.bookmark : Icons.bookmark_add_outlined, color: watchLaterAdded ? Theme.of(context).colorScheme.primary : Colors.white),
            onPressed: () async {
              if (watchLaterAdded) {
                await widget.repo.removeWatchLater(widget.video.bvid);
                if (mounted) {
                  setState(() => watchLaterAdded = false);
                  _toast('已取消收藏');
                }
              } else {
                final ok = await widget.repo.addWatchLater(widget.video);
                if (mounted) {
                  if (ok) {
                    setState(() => watchLaterAdded = true);
                    _toast('已加入收藏');
                  } else {
                    _toast('收藏已满 50');
                  }
                }
              }
            },
          )
        : null;
    final upBtn = widget.video.mid > 0
        ? IconButton(
            tooltip: subscribed ? '已关注' : '关注UP',
            icon: Icon(subscribed ? Icons.person : Icons.person_add_alt, color: subscribed ? Theme.of(context).colorScheme.primary : Colors.white),
            onPressed: () async {
              if (subscribed) {
                await widget.repo.removeSubscription(widget.video.mid);
                if (mounted) {
                  setState(() => subscribed = false);
                  _toast('已取消关注');
                }
                return;
              }
              final ok = await widget.repo.addSubscription(widget.video.mid, widget.video.owner);
              if (mounted) {
                if (ok) {
                  setState(() => subscribed = true);
                  _toast('已关注 ${widget.video.owner}');
                } else {
                  _toast('订阅已满 50 人，请到设置→订阅管理移除一个', ms: 2000);
                }
              }
            },
          )
        : null;
    final fullBtn = IconButton(icon: const Icon(Icons.fullscreen, color: Colors.white), onPressed: _toggleOrientation);
    final progressBar = _ProgressBar(player: player, position: position, duration: duration, onInteract: _startHideTimer);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
          Center(child: NativeVideo(player: player)),
          Positioned.fill(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onDoubleTap: () { playing ? player.pause() : player.play(); },
            onLongPressStart: (_) {
              player.setRate(2.0);
              setState(() { longPressAccel = true; showControls = false; });
            },
            onLongPressEnd: (_) {
              player.setRate(speed);
              setState(() => longPressAccel = false);
            },
            onLongPressCancel: () {
              player.setRate(speed);
              if (mounted) setState(() => longPressAccel = false);
            },
          )),
          AnimatedOpacity(
            opacity: showControls ? 0.4 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(child: Container(color: Colors.black)),
          ),
          Center(
            child: IgnorePointer(
              child: AspectRatio(
                aspectRatio: player.aspectRatio,
                child: Opacity(
                  opacity: danmakuOn ? 1 : 0,
                  child: DanmakuScreen<Object?>(
                    createdController: (c) {
                      _dmController = c;
                      c.updateOption(_dmOption());
                    },
                    option: _dmOption(),
                  ),
                ),
              ),
            ),
          ),
          if (_currentSubtitle() case final sub?)
            IgnorePointer(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: subtitlePos, left: 16, right: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: subtitleSemi ? Colors.black54 : Colors.black, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        sub,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: subtitleFontSize, color: Colors.white, height: 1.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          IgnorePointer(
            ignoring: !showControls,
            child: AnimatedOpacity(
              opacity: showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Center(
                child: IconButton(
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 64, color: Colors.white70),
                  onPressed: () { playing ? player.pause() : player.play(); },
                ),
              ),
            ),
          ),
          if (longPressAccel)
            IgnorePointer(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                      child: const Text('2x 加速中', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  ),
                ),
              ),
            ),
          if (_toastMsg != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xE6212121), borderRadius: BorderRadius.circular(20)),
                    child: Text(_toastMsg!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ),
              ),
            ),
          IgnorePointer(
            ignoring: !showControls,
            child: AnimatedOpacity(
              opacity: showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Column(children: [
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(children: [
                    IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back, color: Colors.white)),
                    Expanded(child: Text(widget.video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white))),
                    TextButton(onPressed: _toggleOrientation, child: Text(landscape ? '竖屏' : '横屏', style: const TextStyle(color: Colors.white))),
                  ]),
                ),
              ),
              const Spacer(),
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Listener(
                    onPointerDown: (_) => _startHideTimer(),
                    child: landscape
                        ? Row(children: [
                            playBtn,
                            timeLabel,
                            const SizedBox(width: 8),
                            Expanded(child: progressBar),
                            speedBtn,
                            qnBtn,
                            if (subBtn != null) subBtn,
                            dmBtn,
                            if (favBtn != null) favBtn,
                            if (upBtn != null) upBtn,
                            fullBtn,
                          ])
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            Row(children: [
                              playBtn,
                              timeLabel,
                              const SizedBox(width: 8),
                              Expanded(child: progressBar),
                            ]),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(children: [
                                speedBtn,
                                qnBtn,
                                if (subBtn != null) subBtn,
                                dmBtn,
                                if (favBtn != null) favBtn,
                                if (upBtn != null) upBtn,
                                fullBtn,
                              ]),
                            ),
                          ]),
                    ),
                ),
              ),
            ]),
              ),
            ),
]),
      ),
    );
  }
}

class _ProgressBar extends StatefulWidget {
  final NativePlayer player;
  final Duration position;
  final Duration duration;
  final VoidCallback onInteract;
  const _ProgressBar({required this.player, required this.position, required this.duration, required this.onInteract});
  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds.toDouble();
    final pos = widget.position.inMilliseconds.toDouble().clamp(0.0, max);
    final dragging = _dragMs != null;
    final display = (dragging ? _dragMs! : pos).clamp(0.0, max);
    return Stack(
        alignment: Alignment.topCenter,
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: dragging ? 8 : 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: max <= 0 ? 0.0 : display,
              max: max <= 0 ? 1.0 : max,
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Colors.white24,
              onChangeStart: (v) { setState(() => _dragMs = v); widget.onInteract(); },
              onChanged: (v) { setState(() => _dragMs = v); widget.onInteract(); },
              onChangeEnd: (v) {
                widget.player.seek(Duration(milliseconds: v.round()));
                setState(() => _dragMs = null);
                widget.onInteract();
              },
            ),
          ),
        ],
      );
  }
}

