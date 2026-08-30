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
  bool editing = false;
  final Set<String> selected = {};

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
      // ignore: avoid_print
      print('[kzv] load error: $e');
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

  String _pubdate(int ts) {
    if (ts <= 0) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final now = DateTime.now();
    return t.year == now.year ? '${t.month}月${t.day}日' : '${t.year}年${t.month}月${t.day}日';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? '已选择 ${selected.length} 项' : '今日精选 · ${_today()}'),
        leading: editing
            ? IconButton(icon: const Icon(Icons.close), onPressed: _exitEditing)
            : null,
        actions: editing
            ? [
                TextButton.icon(
                  onPressed: selected.isEmpty ? null : _skipSelected,
                  icon: const Icon(Icons.block),
                  label: const Text('跳过'),
                ),
              ]
            : [
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
            final isSelected = selected.contains(v.bvid);
            return Card(
              key: ValueKey('${v.bvid}_${Theme.of(context).brightness}'),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () {
                  if (editing) {
                    setState(() { isSelected ? selected.remove(v.bvid) : selected.add(v.bvid); });
                  } else {
                    widget.onPlay(v);
                  }
                },
                onLongPress: () => setState(() {
                  editing = true;
                  selected.add(v.bvid);
                }),
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
                        Text('${_pubdate(v.pubdate)} · ${_duration(v.duration)} · ${_count(v.view)} 播放', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ]))),
                      if (editing)
                        Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline),
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

  void _exitEditing() => setState(() { editing = false; selected.clear(); });

  Future<void> _skipSelected() async {
    final items = (videos ?? []).where((e) => selected.contains(e.bvid)).toList();
    for (final v in items) {
      await VideoRepository.instance().addBlacklist(v);
    }
    if (!mounted) return;
    setState(() {
      videos?.removeWhere((e) => selected.contains(e.bvid));
      selected.clear();
      editing = false;
    });
  }

  Future<void> _showHistory() async {
    if (!await VideoRepository.instance().isHistoryEnabled()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('历史记录已在设置中关闭')));
      return;
    }
    await _showCollection('历史', VideoRepository.instance().getHistory, Icons.history);
  }

  Future<void> _showWatchLater() async {
    if (!await VideoRepository.instance().isWatchLaterEnabled()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('稍后再看已在设置中关闭')));
      return;
    }
    await _showCollection('稍后再看', VideoRepository.instance().getWatchLater, Icons.bookmarks_outlined);
  }

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

  Future<void> _showSubscriptions() async {
    final subs = await VideoRepository.instance().getSubscriptions();
    if (!mounted) return;
    showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.6,
      child: Column(children: [
        ListTile(leading: const Icon(Icons.person_add_alt), title: Text('订阅管理 (${subs.length}/50)', style: Theme.of(ctx).textTheme.titleMedium)),
        if (subs.isEmpty) const Expanded(child: Center(child: Text('暂无订阅，播放页可关注 UP 主'))),
        Expanded(child: ListView.builder(
          itemCount: subs.length,
          itemBuilder: (_, i) {
            final s = subs[i];
            return ListTile(
              title: Text(s.name.isEmpty ? 'UP ${s.mid}' : s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('mid: ${s.mid}'),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
                await VideoRepository.instance().removeSubscription(s.mid);
                if (ctx.mounted) Navigator.pop(ctx);
                _showSubscriptions();
              }),
            );
          },
        )),
      ]),
    ));
  }

  Future<void> _showBlacklist() async {
    final items = await VideoRepository.instance().getBlacklistItems();
    if (!mounted) return;
    showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.6,
      child: Column(children: [
        ListTile(leading: const Icon(Icons.block), title: Text('黑名单', style: Theme.of(ctx).textTheme.titleMedium)),
        if (items.isEmpty) const Expanded(child: Center(child: Text('暂无黑名单'))),
        Expanded(child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final v = items[i];
            return ListTile(
              title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(icon: const Icon(Icons.undo), tooltip: '移出黑名单', onPressed: () async {
                await VideoRepository.instance().removeBlacklist(v.bvid);
                if (ctx.mounted) Navigator.pop(ctx);
                _showBlacklist();
              }),
            );
          },
        )),
      ]),
    ));
  }

  Future<void> _showSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final minDuration = prefs.getInt('setting_min_duration') ?? 600;
    final rid = prefs.getString('setting_rid') ?? '';
    final history = prefs.getBool('setting_history') ?? true;
    final watchLater = prefs.getBool('setting_watch_later') ?? true;
    final manualAdd = prefs.getBool('setting_manual_mid') ?? false;
    if (!mounted) return;
    final result = await showModalBottomSheet<({int minDuration, String rid, bool history, bool watchLater, bool manualAdd})>(
      context: context, showDragHandle: true, isScrollControlled: true,
      builder: (ctx) {
        var selDur = minDuration;
        var selRid = rid;
        var selHistory = history;
        var selWatchLater = watchLater;
        var selManual = manualAdd;
        final manualCtl = TextEditingController();
        const durs = {600: '10 分钟', 1200: '20 分钟', 1800: '30 分钟'};
        const rids = {'': '全部', 'tech': '科技', 'edu': '知识', 'life': '生活', 'game': '游戏', 'ent': '娱乐'};
        return StatefulBuilder(builder: (ctx, setModalState) => SingleChildScrollView(
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
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: const Text('订阅管理'),
              subtitle: const Text('关注 UP 主，推荐会包含他们的新视频'),
              onTap: () { Navigator.pop(ctx); _showSubscriptions(); },
            ),
            SwitchListTile(
              title: const Text('历史记录'),
              subtitle: const Text('记住看过的视频'),
              value: selHistory,
              onChanged: (v) => setModalState(() => selHistory = v),
            ),
            SwitchListTile(
              title: const Text('稍后再看'),
              subtitle: const Text('收藏到稍后队列'),
              value: selWatchLater,
              onChanged: (v) => setModalState(() => selWatchLater = v),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('管理黑名单'),
              subtitle: const Text('查看/移除已跳过的视频'),
              onTap: () {
                Navigator.pop(ctx);
                _showBlacklist();
              },
            ),
            const Divider(height: 8),
            ExpansionTile(
              leading: const Icon(Icons.settings_suggest),
              title: const Text('其他功能'),
              subtitle: const Text('手动添加 UP 等'),
              children: [
                SwitchListTile(
                  title: const Text('手动添加 UP'),
                  subtitle: const Text('按 mid 手动关注'),
                  value: selManual,
                  onChanged: (v) => setModalState(() => selManual = v),
                ),
                if (selManual)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(children: [
                      Expanded(child: TextField(
                        controller: manualCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '输入 UP 主 mid (数字ID)', isDense: true),
                        onSubmitted: (_) => _manualAddSub(ctx, manualCtl),
                      )),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: () => _manualAddSub(ctx, manualCtl), child: const Text('添加')),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () => Navigator.pop(ctx, (minDuration: selDur, rid: selRid, history: selHistory, watchLater: selWatchLater, manualAdd: selManual)),
              child: const Text('应用'),
            )),
            const SizedBox(height: 8),
          ]),
        ));
      },
    );
    if (result != null) {
      await prefs.setInt('setting_min_duration', result.minDuration);
      await prefs.setString('setting_rid', result.rid);
      await prefs.setBool('setting_history', result.history);
      await prefs.setBool('setting_watch_later', result.watchLater);
      await prefs.setBool('setting_manual_mid', result.manualAdd);
      await _load(force: true);
    }
  }

  Future<void> _manualAddSub(BuildContext ctx, TextEditingController ctl) async {
    final mid = int.tryParse(ctl.text.trim());
    if (mid == null || mid <= 0) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('请输入有效的 mid')));
      return;
    }
    final ok = await VideoRepository.instance().addSubscription(mid, '');
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(ok ? '已添加 mid $mid' : '订阅已满 50 人')));
    }
    ctl.clear();
  }
}
