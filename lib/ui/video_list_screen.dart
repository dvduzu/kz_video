import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/video_repository.dart';

class VideoListScreen extends StatefulWidget {
  final void Function(VideoInfo) onPlay;
  final ThemeMode mode;
  final VoidCallback onToggleTheme;
  const VideoListScreen({super.key, required this.onPlay, required this.mode, required this.onToggleTheme});

  @override
  State<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen> {
  List<VideoInfo>? videos;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() { loading = true; error = null; });
    try {
      final list = await VideoRepository.instance().getDailyVideos(force: force);
      setState(() { videos = list; loading = false; });
    } catch (e) {
      setState(() { error = e.toString(); loading = false; });
    }
  }

  String _today() {
    final now = DateTime.now();
    return '${now.month}月${now.day}日';
  }

  String _duration(int s) {
    final h = s ~/ 3600; final m = (s % 3600) ~/ 60; final sec = s % 60;
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}' : '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _count(int c) => c >= 10000 ? '${(c / 10000).toStringAsFixed(1)}万' : '$c';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('今日精选 · ${_today()}'),
        actions: [
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode),
            tooltip: '切换主题',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: Builder(builder: (context) {
        if (loading) return const Center(child: CircularProgressIndicator());
        if (error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('加载失败：$error'), const SizedBox(height: 12), FilledButton(onPressed: () => _load(force: true), child: const Text('重试'))]));
        final list = videos!;
        if (list.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('今天还没有内容'), const SizedBox(height: 12), FilledButton(onPressed: () => _load(force: true), child: const Text('重试'))]));
        return ListView.separated(
          key: ValueKey(Theme.of(context).brightness),
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final v = list[i];
            return Card(
              key: ValueKey('${v.bvid}_${Theme.of(context).brightness}'),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () => widget.onPlay(v),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(imageUrl: v.pic, width: 128, height: 76, fit: BoxFit.cover, memCacheWidth: 256),
                      ),
                      Expanded(child: Padding(padding: const EdgeInsets.only(left: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: 4),
                        Text(v.owner, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        Text('${_duration(v.duration)} · ${_count(v.view)} 播放', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ]))),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
