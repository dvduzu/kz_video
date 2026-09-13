import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_orientation.dart';
import '../core/logger.dart';
import '../data/models.dart';
import '../data/video_repository.dart';

class UpChannelScreen extends StatefulWidget {
  final VideoRepository repo;
  final int mid;
  final String name;
  final String bvid;
  final void Function(VideoInfo) onPlay;
  final bool fromPlayer;
  const UpChannelScreen({super.key, required this.repo, required this.mid, required this.name, required this.bvid, required this.onPlay, this.fromPlayer = false});

  @override
  State<UpChannelScreen> createState() => _UpChannelScreenState();
}

class _UpChannelScreenState extends State<UpChannelScreen> {
  final _scroll = ScrollController();
  final List<VideoInfo> _videos = [];
  String _face = '';
  String _banner = '';
  int _fans = 0;
  bool _subscribed = false;
  int _pn = 1;
  int _cursor = 0;
  bool _loading = false;
  bool _noMore = false;

  @override
  void initState() {
    super.initState();
    AppOrientation.apply(widget.repo.settings.uiModeMode);
    _loadUser();
    _loadSubscribed();
    _loadMore();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) _loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    if (widget.fromPlayer) {
      SystemChrome.setPreferredOrientations(const [DeviceOrientation.landscapeLeft]);
    } else {
      AppOrientation.apply(widget.repo.settings.uiModeMode);
    }
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final subs = await widget.repo.subscriptions.all();
      for (final s in subs) {
        if (s.mid == widget.mid && s.face.isNotEmpty) {
          if (mounted) setState(() => _face = _normalizeFace(s.face));
          break;
        }
      }
    } catch (e) {
      KzvLogger.debug('load sub face failed: $e');
    }
    if (_face.isEmpty && widget.bvid.isNotEmpty) {
      final info = await widget.repo.getUpInfoByVideo(widget.bvid);
      if (mounted && info != null && info.face.isNotEmpty) {
        setState(() => _face = info.face);
      }
    }
    final info = await widget.repo.getUserInfo(widget.mid);
    if (!mounted || info == null) return;
    setState(() {
      if (info.face.isNotEmpty) _face = info.face;
      if (info.banner.isNotEmpty) _banner = info.banner;
      _fans = info.fans;
    });
  }

  Future<void> _loadSubscribed() async {
    final v = await widget.repo.subscriptions.contains(widget.mid);
    if (mounted) setState(() => _subscribed = v);
  }

  Future<void> _toggleSubscribed() async {
    if (_subscribed) {
      await widget.repo.subscriptions.remove(widget.mid);
      if (mounted) setState(() => _subscribed = false);
      return;
    }
    final ok = await widget.repo.subscriptions.add(widget.mid, widget.name);
    if (!mounted) return;
    if (ok) {
      setState(() => _subscribed = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('订阅已满 50 人')));
    }
  }

  String _normalizeFace(String f) {
    if (f.startsWith('//')) return 'https:$f';
    return f.replaceFirst('http://', 'https://');
  }

  Future<void> _loadMore() async {
    if (_loading || _noMore) return;
    setState(() => _loading = true);
    try {
      final list = await widget.repo.getUpVideos(widget.mid, pn: _pn, cursor: _cursor);
      if (!mounted) return;
      final existing = _videos.map((v) => v.bvid).toSet();
      final fresh = list.where((v) => !existing.contains(v.bvid)).toList();
      setState(() {
        _videos.addAll(fresh);
        if (list.isNotEmpty) {
          _pn++;
          final lastAid = list.last.aid;
          if (lastAid > 0) _cursor = lastAid;
        }
        if (list.isEmpty || fresh.isEmpty) _noMore = true;
        _loading = false;
      });
    } catch (e) {
      KzvLogger.debug('load up videos failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _count(int c) => c >= 10000 ? '${(c / 10000).toStringAsFixed(1)}万' : '$c';

  String _duration(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}' : '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _pubdate(int ts) {
    if (ts <= 0) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final now = DateTime.now();
    return t.year == now.year ? '${t.month}月${t.day}日' : '${t.year}年${t.month}月${t.day}日';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFooter = _loading || _noMore;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        itemCount: _videos.length + 1 + (hasFooter ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: _banner.isNotEmpty ? 130 : 64,
                  child: Stack(children: [
                    if (_banner.isNotEmpty)
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: _banner,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: cs.surfaceContainerHigh),
                        ),
                      ),
                    if (_banner.isNotEmpty)
                      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, cs.surface.withValues(alpha: 0.85)],
                      )))),
                    Positioned(
                      left: 4, right: 4, bottom: 4,
                      child: Row(children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: cs.surfaceContainerHigh,
                          backgroundImage: _face.isNotEmpty ? CachedNetworkImageProvider(_face) : null,
                          child: _face.isEmpty ? const Icon(Icons.person) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(widget.name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (_fans > 0) Text('${_count(_fans)} 粉丝', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ])),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _toggleSubscribed,
                          child: Text(_subscribed ? '已关注' : '关注'),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          }
          if (i > _videos.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _noMore && !_loading
                    ? Text('没有更多了', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))
                    : const CircularProgressIndicator(),
              ),
            );
          }
          final v = _videos[i - 1];
          return Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            color: cs.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                widget.onPlay(v);
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(imageUrl: v.pic, width: 128, height: 76, fit: BoxFit.cover, memCacheWidth: 256),
                  ),
                  Expanded(child: Padding(padding: const EdgeInsets.only(left: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurface)),
                    const SizedBox(height: 4),
                    Text('${_pubdate(v.pubdate)} · ${_duration(v.duration)} · ${_count(v.view)} 播放', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ]))),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
