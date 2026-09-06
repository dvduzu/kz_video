import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/local_store.dart';
import '../data/video_repository.dart';
import 'appearance_settings_page.dart';
import 'settings_page.dart';
import 'subscription_sheet.dart';
import '../core/logger.dart';

class VideoListScreen extends StatefulWidget {
  final VideoRepository repo;
  final void Function(VideoInfo) onPlay;
  final ThemeMode mode;
  final VoidCallback onToggleTheme;
  final SeedTheme? seed;
  final bool useDynamic;
  final Future<void> Function(ThemeMode, SeedTheme?, {bool? dynamic}) onSetTheme;
  const VideoListScreen({super.key, required this.repo, required this.onPlay, required this.mode, required this.onToggleTheme, required this.seed, required this.useDynamic, required this.onSetTheme});

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
  final Set<String> _fading = {};
  final Set<String> selected = {};

  bool get _cardOutlineEnabled => widget.repo.settings.cardOutline;

  Color get _cardColor => switch (widget.repo.settings.cardTone) {
    'low' => Theme.of(context).colorScheme.surfaceContainerLow,
    'medium' => Theme.of(context).colorScheme.surfaceContainer,
    'highest' => Theme.of(context).colorScheme.surfaceContainerHighest,
    _ => Theme.of(context).colorScheme.surfaceContainerHigh,
  };

  void markWatched(VideoInfo v) => _markWatched(v);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _markWatched(VideoInfo v) {
    widget.repo.markWatched(v.bvid);
    setState(() {
      _fading.add(v.bvid);
      _watched.add(v.bvid);
    });
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;      setState(() {
        videos?.removeWhere((x) => x.bvid == v.bvid);
        _fading.remove(v.bvid);
      });
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
    _fading.clear();
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

  String _ridName(String key) {
    return const {
      '': '全部',
      'tech': '科技',
      'edu': '知识',
      'life': '美食',
      'game': '游戏',
      'ent': '娱乐',
      'music': '音乐',
      'sub': '订阅',
    }[key] ?? '全部';
  }

  void _pickRid() {
    var selRid = widget.repo.settings.rid;
    var selMin = widget.repo.settings.minDurationOf(selRid);
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => AlertDialog(
      title: const Text('分区设置'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, children: const {
          '': '全部',
          'tech': '科技',
          'edu': '知识',
          'life': '美食',
          'game': '游戏',
          'ent': '娱乐',
          'music': '音乐',
          'sub': '订阅',
        }.entries.map((e) => Builder(builder: (ctx) => ChoiceChip(
          label: Text(e.value),
          selected: selRid == e.key,
          onSelected: (_) {
            setSheet(() {
              selRid = e.key;
              selMin = widget.repo.settings.minDurationOf(e.key);
            });
          },
        ))).toList()),
      const Divider(height: 16),
      if (selRid == 'sub') ...[
            Row(children: [
              const Text('长视频时长'),
              const SizedBox(width: 8),
              Expanded(child: Slider(
                value: _minToSubIndex(selMin).toDouble(),
                min: 0,
                max: 3,
                divisions: 3,
                label: selMin == 0 ? '不限' : '${(selMin / 60).round()} 分钟',
                onChanged: (v) => setSheet(() => selMin = _subIndexToMin(v.round())),
              )),
              Text(selMin == 0 ? '不限' : '${(selMin / 60).round()} 分钟'),
            ]),
          ] else
            Row(children: [
              const Text('长视频阈值'),
              const SizedBox(width: 8),
              Expanded(child: Slider(
                value: selMin.clamp(600, 1800).toDouble(),
                min: 600,
                max: 1800,
                divisions: 2,
                label: '${(selMin / 60).round()} 分钟',
                onChanged: (v) => setSheet(() => selMin = v.round()),
              )),
              Text('${(selMin / 60).round()} 分钟'),
            ]),
      ]),
      actions: [
        FilledButton(
          onPressed: () {
            final ridChanged = selRid != widget.repo.settings.rid;
            final minChanged = selMin != widget.repo.settings.minDurationOf(selRid);
            if (!ridChanged && !minChanged) {
              Navigator.pop(ctx);
              return;
            }
            widget.repo.settings.setRid(selRid);
            widget.repo.settings.setMinDurationOf(selRid, selMin);
            Navigator.pop(ctx);
            if (minChanged) {
              widget.repo.store.clearDailyCacheFor(selRid);
              _load(force: true);
            } else {
              _load(force: false);
            }
          },
          child: const Text('应用'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
      ],
    )));
  }

  int _minToSubIndex(int min) {
    if (min == 0) return 0;
    if (min <= 600) return 1;
    if (min <= 1200) return 2;
    return 3;
  }

  int _subIndexToMin(int index) {
    return switch (index) { 0 => 0, 1 => 600, 2 => 1200, _ => 1800 };
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
        title: editing
            ? Text('已选择 ${selected.length} 项')
            : Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: _pickRid,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_ridName(widget.repo.settings.rid), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ]),
                ),
                GestureDetector(
                  onTap: _onTitleTap,
                  child: Text(' ${_today()}'),
                ),
              ]),
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
            final isFading = _fading.contains(v.bvid);
            return AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: isFading ? 0 : 1,
                child: Card(
              key: ValueKey('${v.bvid}_${Theme.of(context).brightness}'),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : _cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: _cardOutlineEnabled
                    ? BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: isSelected ? 1.5 : 1,
                      )
                    : BorderSide.none,
              ),
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
          title: Text(selectMode ? '已选择 ${selectedSet.length} 项' : (title == '收藏' ? '收藏 (${items.length}/${LocalStore.maxWatchLaterItems})' : title), style: Theme.of(ctx).textTheme.titleMedium),
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => AppearanceSettingsPage(
      mode: widget.mode,
      theme: widget.seed,
      useDynamic: widget.useDynamic,
      onSetTheme: widget.onSetTheme,
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
    final oldRid = widget.repo.settings.rid;
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => SettingsPage(
        repo: widget.repo,
        onOpenColorSettings: _showColorSettings,
        onOpenSubscriptions: _showSubscriptions,
        onOpenBlacklist: _showBlacklist,
        onAppearanceChanged: () {
          if (mounted) setState(() {});
        },
      ),
    ));
    if (!mounted) return;
    final accountChanged = widget.repo.hasAccount != oldHasAccount || widget.repo.guestMode != oldGuestMode;
    final ridChanged = widget.repo.settings.rid != oldRid;
    if (changed != null) {
      setState(() {});
    }
    if (ridChanged) {
      await _load(force: false);
    } else if (changed == true || accountChanged) {
      await _load(force: true);
    }
  }
}
