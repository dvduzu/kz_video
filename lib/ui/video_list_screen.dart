import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
          IconButton(icon: const Icon(Icons.history), tooltip: '历史', onPressed: _showHistory),
          IconButton(icon: const Icon(Icons.bookmarks_outlined), tooltip: '稍后再看', onPressed: _showWatchLater),
          IconButton(icon: const Icon(Icons.settings_outlined), tooltip: '设置', onPressed: _showSettings),
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
        return Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: FilledButton.tonalIcon(
                onPressed: () => _load(force: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('换一批'),
              ),
            ),
          ),
          Expanded(
          child: ListView.separated(
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
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: '跳过',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _skip(v),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          ),
          ),
        ]);
      }),
    );
  }

  Future<void> _skip(VideoInfo v) async {
    await VideoRepository.instance().addBlacklist(v.bvid);
    if (!mounted) return;
    setState(() => videos?.removeWhere((e) => e.bvid == v.bvid));
  }

  Future<void> _showHistory() => _showCollection('历史', VideoRepository.instance().getHistory, Icons.history);

  Future<void> _showWatchLater() => _showCollection('稍后再看', VideoRepository.instance().getWatchLater, Icons.bookmarks_outlined);

  Future<void> _showCollection(String title, Future<List<VideoInfo>> Function() loader, IconData icon) async {
    final items = await loader();
    if (!mounted) return;
    showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.6,
      child: Column(children: [
        ListTile(leading: Icon(icon), title: Text(title, style: Theme.of(ctx).textTheme.titleMedium)),
        if (items.isEmpty) const Expanded(child: Center(child: Text('暂无内容'))),
        Expanded(child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final v = items[i];
            return ListTile(
              title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: title == '稍后再看' ? IconButton(icon: const Icon(Icons.close), onPressed: () async {
                await VideoRepository.instance().removeWatchLater(v.bvid);
                if (ctx.mounted) Navigator.pop(ctx);
                _showWatchLater();
              }) : null,
              onTap: () { Navigator.pop(ctx); widget.onPlay(v); },
            );
          },
        )),
      ]),
    ));
  }

  Future<void> _showSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rid = prefs.getInt('setting_rid') ?? 188;
    final minDuration = prefs.getInt('setting_min_duration') ?? 600;
    if (!mounted) return;
    final result = await showModalBottomSheet<({int rid, int minDuration})>(
      context: context, showDragHandle: true,
      builder: (ctx) {
        var selRid = rid;
        var selDur = minDuration;
        const rids = {188: '科技', 36: '知识', 160: '生活', 201: '纪录片', 4: '游戏', 5: '娱乐'};
        const durs = {600: '10 分钟', 1200: '20 分钟', 1800: '30 分钟'};
        return StatefulBuilder(builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('分区', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 8, children: rids.entries.map((e) => ChoiceChip(
              label: Text(e.value),
              selected: selRid == e.key,
              onSelected: (_) => setModalState(() => selRid = e.key),
            )).toList()),
            const SizedBox(height: 16),
            const Text('长视频阈值', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 8, children: durs.entries.map((e) => ChoiceChip(
              label: Text(e.value),
              selected: selDur == e.key,
              onSelected: (_) => setModalState(() => selDur = e.key),
            )).toList()),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () => Navigator.pop(ctx, (rid: selRid, minDuration: selDur)),
              child: const Text('应用'),
            )),
          ]),
        ));
      },
    );
    if (result != null) {
      await prefs.setInt('setting_rid', result.rid);
      await prefs.setInt('setting_min_duration', result.minDuration);
      await _load(force: true);
    }
  }
}
