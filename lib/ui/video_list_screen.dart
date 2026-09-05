import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/video_repository.dart';
import 'settings_page.dart';
import 'subscription_sheet.dart';
import '../core/logger.dart';

class VideoListScreen extends StatefulWidget {
  final VideoRepository repo;
  final void Function(VideoInfo) onPlay;
  final ThemeMode mode;
  final VoidCallback onToggleTheme;
  final Color? seed;
  final Future<void> Function(ThemeMode, Color?) onSetTheme;
  const VideoListScreen({super.key, required this.repo, required this.onPlay, required this.mode, required this.onToggleTheme, required this.seed, required this.onSetTheme});

  @override
  State<VideoListScreen> createState() => VideoListScreenState();
}

class VideoListScreenState extends State<VideoListScreen> {
  List<VideoInfo>? videos;
  String? error;
  bool loading = true;
  bool editing = false;
  int _titleTaps = 0;
  final Set<String> _watched = {};
  final Set<String> selected = {};

  void markWatched(VideoInfo v) => _markWatched(v);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _markWatched(VideoInfo v) {
    widget.repo.markWatched(v.bvid);
    setState(() {
      videos?.removeWhere((x) => x.bvid == v.bvid);
      _watched.add(v.bvid);
    });
  }

  Future<void> _markSelectedWatched() async {
    final list = (videos ?? []).where((e) => selected.contains(e.bvid)).toList();
    for (final v in list) {
      _markWatched(v);
    }
    if (mounted) {
      setState(() { selected.clear(); editing = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已标记 ${list.length} 个看完')));
    }
  }

  Future<void> _onTitleTap() async {
    _titleTaps++;
    if (_titleTaps >= 10) {
      _titleTaps = 0;
      final unlimited = !widget.repo.unlimitedRefresh;
      await widget.repo.setUnlimitedRefresh(unlimited);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(unlimited ? 'debug' : 'release')));
      }
    }
  }

  Future<void> _onRefresh() async {
    if (!await widget.repo.canRefreshToday()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('今天已结束，明天再来')));
      return;
    }
    await widget.repo.recordRefresh();
    await widget.repo.clearWatched();
    _watched.clear();
    await _load(force: true);
  }

  Future<void> _load({bool force = false}) async {
    setState(() { loading = true; error = null; });
    try {
      final list = await widget.repo.getDailyVideos(force: force);
      setState(() { videos = list; loading = false; });
    } catch (e) {
      KzvLogger.debug('load error: $e');
      setState(() { error = e.toString(); loading = false; });
      if (!force) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) await _load(force: true);
      }
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
        title: GestureDetector(
          onTap: editing ? null : _onTitleTap,
          child: Text(editing ? '已选择 ${selected.length} 项' : '今日精选 · ${_today()}'),
        ),
        leading: editing
            ? IconButton(icon: const Icon(Icons.close), onPressed: _exitEditing)
            : null,
        actions: editing
            ? [
                TextButton.icon(
                  onPressed: () => setState(() {
                    final allSelected = (videos ?? const []).isNotEmpty && selected.length == videos!.length;
                    if (allSelected) {
                      selected.clear();
                    } else {
                      selected.clear();
                      selected.addAll((videos ?? const []).map((e) => e.bvid));
                    }
                  }),
                  icon: Icon((videos ?? const []).isNotEmpty && selected.length == videos!.length ? Icons.deselect : Icons.select_all),
                  label: Text((videos ?? const []).isNotEmpty && selected.length == videos!.length ? '取消全选' : '全选'),
                ),
                TextButton.icon(
                  onPressed: selected.isEmpty ? null : _markSelectedWatched,
                  icon: const Icon(Icons.done_all),
                  label: const Text('标记看完'),
                ),
                TextButton.icon(
                  onPressed: selected.isEmpty ? null : _skipSelected,
                  icon: const Icon(Icons.block),
                  label: const Text('跳过'),
                ),
              ]
            : [
                IconButton(icon: const Icon(Icons.done_all), tooltip: '标记看完', onPressed: () => setState(() => editing = true)),
                if (widget.repo.settings.isHistoryEnabled)
                  IconButton(icon: const Icon(Icons.history), tooltip: '历史', onPressed: _showHistory),
                if (widget.repo.settings.isWatchLaterEnabled)
                  IconButton(icon: const Icon(Icons.bookmarks_outlined), tooltip: '收藏', onPressed: _showWatchLater),
                IconButton(icon: const Icon(Icons.settings_outlined), tooltip: '设置', onPressed: _showSettings),
              ],
      ),
      body: Builder(builder: (context) {
        if (loading) return const Center(child: CircularProgressIndicator());
        if (error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('加载失败：$error'), const SizedBox(height: 12), FilledButton(onPressed: () => _load(force: true), child: const Text('重试'))]));
        final list = videos!;
        if (list.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('¯\\_(ツ)_/¯', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('换一批'),
          ),
        ]));
        return Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: FilledButton.tonalIcon(
                onPressed: _onRefresh,
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
      await widget.repo.addBlacklist(v);
    }
    if (!mounted) return;
    setState(() {
      videos?.removeWhere((e) => selected.contains(e.bvid));
      selected.clear();
      editing = false;
    });
  }

  Future<void> _showHistory() async {
    if (!await widget.repo.isHistoryEnabled()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('历史记录已在设置中关闭')));
      return;
    }
    await _showCollection('历史', widget.repo.getHistory, Icons.history);
  }

  Future<void> _showWatchLater() async {
    if (!await widget.repo.isWatchLaterEnabled()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('收藏已在设置中关闭')));
      return;
    }
    await _showCollection('收藏', widget.repo.getWatchLater, Icons.bookmarks_outlined);
  }

  Future<void> _showCollection(String title, Future<List<VideoInfo>> Function() loader, IconData icon) async {
    final items = await loader();
    if (!mounted) return;
    var selectMode = false;
    final selectedSet = <String>{};
    showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.6,
      child: Column(children: [
        ListTile(
          leading: Icon(icon),
          title: Text(selectMode ? '已选择 ${selectedSet.length} 项' : title, style: Theme.of(ctx).textTheme.titleMedium),
          trailing: selectMode
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton.icon(
                    onPressed: () => setSheet(() {
                      final allSelected = items.isNotEmpty && selectedSet.length == items.length;
                      selectedSet.clear();
                      if (!allSelected) selectedSet.addAll(items.map((e) => e.bvid));
                    }),
                    icon: Icon(items.isNotEmpty && selectedSet.length == items.length ? Icons.deselect : Icons.select_all),
                    label: Text(items.isNotEmpty && selectedSet.length == items.length ? '取消全选' : '全选'),
                  ),
                  TextButton.icon(
                    onPressed: selectedSet.isEmpty ? null : () async {
                      for (final bvid in selectedSet) {
                        if (title == '收藏') {
                          await widget.repo.removeWatchLater(bvid);
                        } else {
                          await widget.repo.removeHistory(bvid);
                        }
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (title == '收藏') { await _showWatchLater(); } else { await _showHistory(); }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除选中'),
                  ),
                ])
              : TextButton.icon(
                  onPressed: items.isEmpty ? null : () => setSheet(() => selectMode = true),
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('删除'),
                ),
        ),
        if (items.isEmpty) const Expanded(child: Center(child: Text('暂无内容'))),
        Expanded(child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final v = items[i];
            return ListTile(
              leading: selectMode
                  ? Icon(selectedSet.contains(v.bvid) ? Icons.check_box : Icons.check_box_outline_blank, color: Theme.of(ctx).colorScheme.primary)
                  : null,
              title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                if (selectMode) {
                  setSheet(() {
                    if (!selectedSet.remove(v.bvid)) selectedSet.add(v.bvid);
                  });
                } else {
                  Navigator.pop(ctx);
                  widget.onPlay(v);
                }
              },
            );
          },
        )),
      ]),
    )));
  }

  Future<void> _showSubscriptions() async {
    showModalBottomSheet(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => SubscriptionSheet(repo: widget.repo));
  }

  void _showColorSettings() {
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
          selected: widget.mode == e.key,
          onSelected: (_) { setDlg(() {}); widget.onSetTheme(e.key, widget.seed); },
        )).toList()),
        const SizedBox(height: 16),
        const Text('色调', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(spacing: 8, children: [
          ChoiceChip(
            avatar: const Icon(Icons.brightness_auto, size: 16),
            label: const Text('跟随系统'),
            selected: widget.seed == null,
            onSelected: (_) { setDlg(() {}); widget.onSetTheme(widget.mode, null); },
          ),
          ...aospSeeds.entries.map((e) => ChoiceChip(
            avatar: CircleAvatar(backgroundColor: e.value, radius: 8),
            label: Text(e.value == Colors.blueGrey ? '灰' : e.key),
            selected: widget.seed == e.value,
            onSelected: (_) { setDlg(() {}); widget.onSetTheme(widget.mode, e.value); },
          )),
        ]),
      ])),
    )));
  }


  Future<void> _showBlacklist() async {
    final items = await widget.repo.getBlacklistItems();
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
                await widget.repo.removeBlacklist(v.bvid);
                setState(() {
                  if (!(videos ?? const []).any((x) => x.bvid == v.bvid)) {
                    videos?.insert(0, v);
                  }
                });
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
    final oldHasAccount = widget.repo.hasAccount;
    final oldGuestMode = widget.repo.guestMode;
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => SettingsPage(
        repo: widget.repo,
        onOpenColorSettings: _showColorSettings,
        onOpenSubscriptions: _showSubscriptions,
        onOpenBlacklist: _showBlacklist,
      ),
    ));
    if (!mounted) return;
    final accountChanged = widget.repo.hasAccount != oldHasAccount || widget.repo.guestMode != oldGuestMode;
    if (changed != null) {
      setState(() {});
    }
    if (changed == true || accountChanged) {
      await _load(force: true);
    }
  }
}
