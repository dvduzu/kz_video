import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/local_store.dart';
import '../data/video_repository.dart';
import 'appearance_settings_page.dart';
import 'settings_page.dart';
import 'subscription_sheet.dart';
import 'up_channel_screen.dart';
import '../core/logger.dart';

class VideoListScreen extends StatefulWidget {
  final VideoRepository repo;
  final void Function(VideoInfo) onPlay;
  final ThemeMode mode;
  final VoidCallback onToggleTheme;
  final SeedTheme? seed;
  final bool useDynamic;
  final AnimPrefs anims;
  final Future<void> Function(ThemeMode, SeedTheme?, {bool? dynamic}) onSetTheme;
  final ValueChanged<AnimPrefs> onSetAnims;
  const VideoListScreen({super.key, required this.repo, required this.onPlay, required this.mode, required this.onToggleTheme, required this.seed, required this.useDynamic, required this.anims, required this.onSetTheme, required this.onSetAnims});

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
  int _subOffset = 0;

  bool get _cardOutlineEnabled => widget.repo.settings.cardOutline;

  Duration _dur(int ms) => widget.anims.listOn ? widget.anims.dur(ms) : Duration.zero;

  Duration _cardDur(int ms) => widget.anims.cardOn ? widget.anims.dur(ms) : Duration.zero;

  Color get _cardColor => switch (widget.repo.settings.cardTone) {
    'low' => Theme.of(context).colorScheme.surfaceContainerLow,
    'medium' => Theme.of(context).colorScheme.surfaceContainer,
    'highest' => Theme.of(context).colorScheme.surfaceContainerHighest,
    _ => Theme.of(context).colorScheme.surfaceContainerHigh,
  };

  void markWatched(VideoInfo v) => _markWatched(v);

  final ScrollController _scrollCtrl = ScrollController();
  int _hotPage = 1;
  bool _hotLoading = false;
  bool _hotEnd = false;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(() {
      if (widget.repo.settings.rid != 'hot') return;
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 600) {
        _loadMoreHot();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMoreHot() async {
    if (_hotLoading || _hotEnd) return;
    if (widget.repo.settings.recommendCountOf('hot') > 0) return;
    _hotLoading = true;
    final next = await widget.repo.getHotVideos(pn: _hotPage + 1);
    if (!mounted) return;
    setState(() {
      if (next.isEmpty) {
        _hotEnd = true;
      } else {
        _hotPage++;
        videos = [...?videos, ...next];
      }
      _hotLoading = false;
    });
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
    if (widget.repo.settings.rid == 'sub') {
      _subOffset += 10;
    }
    await _load(force: true);
  }

  Future<void> _load({bool force = false}) async {
    setState(() { loading = true; error = null; });
    try {
      if (widget.repo.settings.rid == 'hot') {
        _hotPage = 1;
        _hotEnd = false;
        final limit = widget.repo.settings.recommendCountOf('hot');
        final list = await widget.repo.getHotVideos(pn: 1, limit: limit);
        setState(() {
          videos = list;
          if (limit > 0) _hotEnd = true;
          loading = false;
        });
        return;
      }
      final offset = widget.repo.settings.rid == 'sub' ? _subOffset : 0;
      final list = await widget.repo.getDailyVideos(force: force, offset: offset);
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
      'hot': '热门',
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
    var selCount = widget.repo.settings.recommendCountOf(selRid);
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => AlertDialog(
      title: const Text('分区设置'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, children: const {
          '': '全部',
          'hot': '热门',
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
              selCount = widget.repo.settings.recommendCountOf(e.key);
            });
          },
        ))).toList()),
      const Divider(height: 16),
      if (selRid == 'sub' || selRid == 'hot') ...[
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
      Row(children: [
        const Text('推荐数量'),
        const SizedBox(width: 8),
        Expanded(child: Slider(
          value: selCount.toDouble().clamp((selRid == 'hot' ? 0 : 10).toDouble(), 50),
          min: (selRid == 'hot' ? 0 : 10).toDouble(),
          max: 50,
          divisions: selRid == 'hot' ? 10 : 8,
          label: selCount == 0 ? '不限' : '$selCount 条',
          onChanged: (v) => setSheet(() => selCount = v.round()),
        )),
        Text(selCount == 0 ? '不限' : '$selCount 条'),
      ]),
      ]),
      actions: [
        FilledButton(
          onPressed: () {
            final ridChanged = selRid != widget.repo.settings.rid;
            final minChanged = selMin != widget.repo.settings.minDurationOf(selRid);
            final countChanged = selCount != widget.repo.settings.recommendCountOf(selRid);
            if (!ridChanged && !minChanged && !countChanged) {
              Navigator.pop(ctx);
              return;
            }
            widget.repo.settings.setRid(selRid);
            widget.repo.settings.setMinDurationOf(selRid, selMin);
            widget.repo.settings.setRecommendCountOf(selRid, selCount);
            Navigator.pop(ctx);
            if (ridChanged) {
              _subOffset = 0;
            }
            if (minChanged || countChanged) {
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

  Widget _buildVideoCard(BuildContext context, VideoInfo v) {
    final isSelected = selected.contains(v.bvid);
    final isFading = _fading.contains(v.bvid);
    return AnimatedSize(
      duration: _dur(400),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        duration: _dur(400),
        opacity: isFading ? 0 : 1,
        child: AnimatedContainer(
          key: ValueKey('${v.bvid}_${Theme.of(context).brightness}'),
          duration: _cardDur(220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(4),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: _cardOutlineEnabled
                ? Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: isSelected ? 1.5 : 1,
                  )
                : null,
          ),
          child: Material(
            color: Colors.transparent,
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
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: v.mid > 0 ? () => _openUpChannel(v) : null,
                        child: Text(v.owner, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                      ),
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
      ),
    );
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
        title: AnimatedSwitcher(
          duration: _dur(200),
          child: editing
            ? Text('已选择 ${selected.length} 项', key: const ValueKey('editing'))
            : Row(key: const ValueKey('normal'), mainAxisSize: MainAxisSize.min, children: [
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
                if (widget.repo.settings.rid == 'sub')
                  GestureDetector(
                    onTap: _pickSubFilter,
                    child: const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.filter_alt_outlined, size: 18)),
                  ),
              ]),
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
        final Widget content = (() {
        if (loading) return const Center(key: ValueKey('loading'), child: CircularProgressIndicator());
        if (error != null) return Center(key: const ValueKey('error'), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('加载失败：$error'), const SizedBox(height: 12), FilledButton(onPressed: () => _load(force: true), child: const Text('重试'))]));
        final list = videos!;
        if (list.isEmpty) return Center(key: const ValueKey('empty'), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('¯\\_(ツ)_/¯', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('换一批'),
          ),
        ]));
        return Column(key: const ValueKey('list'), children: [
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
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: LayoutBuilder(builder: (context, constraints) {
                final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
                final cols = !isTablet ? 1 : (constraints.maxWidth >= 1100 ? 3 : 2);
                final Widget? footer = _hotLoading
                    ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()))
                    : null;
                final extra = footer == null ? 0 : 1;
                if (cols <= 1) {
                  return ListView.separated(
                    controller: _scrollCtrl,
                    key: ValueKey(Theme.of(context).brightness),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length + extra,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => i >= list.length ? footer! : _buildVideoCard(context, list[i]),
                  );
                }
                return GridView.builder(
                  controller: _scrollCtrl,
                  key: ValueKey('${Theme.of(context).brightness}_$cols'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    mainAxisExtent: 140,
                  ),
                  itemCount: list.length + extra,
                  itemBuilder: (context, i) => i >= list.length ? footer! : _buildVideoCard(context, list[i]),
                );
              }),
            ),
          ),
        ]);
        })();
        return AnimatedSwitcher(duration: _dur(250), child: content);
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

  Future<void> _openUpChannel(VideoInfo v) async {
    if (v.mid <= 0) return;
    if (v.owner.contains('联合创作')) {
      final staff = await widget.repo.getVideoStaff(v.bvid);
      if (!mounted) return;
      if (staff.length > 1) {
        showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: ListView(
          shrinkWrap: true,
          children: staff.map((s) => ListTile(
            leading: CircleAvatar(
              backgroundImage: s.face.isNotEmpty ? CachedNetworkImageProvider(s.face.startsWith('//') ? 'https:${s.face}' : s.face) : null,
              child: s.face.isEmpty ? const Icon(Icons.person) : null,
            ),
            title: Text(s.name),
            onTap: () { Navigator.pop(ctx); _gotoUp(s.mid, s.name, v.bvid); },
          )).toList(),
        )));
        return;
      }
    }
    _gotoUp(v.mid, v.owner, v.bvid);
  }

  Future<void> _pickSubFilter() async {
    final subs = await widget.repo.getSubscriptions();
    if (!mounted) return;
    final current = widget.repo.settings.subFilterMid;
    showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          leading: const Icon(Icons.all_inclusive),
          title: const Text('全部'),
          selected: current == 0,
          onTap: () { Navigator.pop(ctx); _setSubFilter(0); },
        ),
        ...subs.map((s) => ListTile(
          leading: CircleAvatar(
            backgroundImage: s.face.isNotEmpty ? CachedNetworkImageProvider(s.face.startsWith('//') ? 'https:${s.face}' : s.face) : null,
            child: s.face.isEmpty ? const Icon(Icons.person) : null,
          ),
          title: Text(s.name),
          selected: current == s.mid,
          onTap: () { Navigator.pop(ctx); _setSubFilter(s.mid); },
        )),
      ],
    )));
  }

  void _setSubFilter(int mid) {
    widget.repo.settings.setSubFilterMid(mid);
    _subOffset = 0;
    _load(force: true);
  }

  void _gotoUp(int mid, String name, String bvid) {    Navigator.push(context, MaterialPageRoute(builder: (_) => UpChannelScreen(
      repo: widget.repo,
      mid: mid,
      name: name,
      bvid: bvid,
      onPlay: widget.onPlay,
    )));
  }

  void _showColorSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AppearanceSettingsPage(
      mode: widget.mode,
      theme: widget.seed,
      useDynamic: widget.useDynamic,
      anims: widget.anims,
      onSetTheme: widget.onSetTheme,
      onSetAnims: widget.onSetAnims,
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
      _subOffset = 0;
      await _load(force: false);
    } else if (changed == true || accountChanged) {
      await _load(force: true);
    }
  }
}
