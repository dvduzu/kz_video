import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/video_repository.dart';
import 'appearance_settings_page.dart';
import 'settings_page.dart';
import 'subscription_screen.dart';
import 'subscription_sheet.dart';
import 'collection_page.dart';
import 'up_channel_screen.dart';
import 'video_card.dart';
import '../core/app_orientation.dart';
import '../core/logger.dart';

class VideoListScreen extends StatefulWidget {
  final VideoRepository repo;
  final void Function(VideoInfo) onPlay;
  final ThemeMode mode;
  final VoidCallback onToggleTheme;
  final SeedTheme? seed;
  final bool useDynamic;
  final AnimPrefs anims;
  final UiMode uiMode;
  final Future<void> Function(ThemeMode, SeedTheme?, {bool? dynamic}) onSetTheme;
  final ValueChanged<AnimPrefs> onSetAnims;
  final ValueChanged<UiMode> onSetUiMode;
  const VideoListScreen({super.key, required this.repo, required this.onPlay, required this.mode, required this.onToggleTheme, required this.seed, required this.useDynamic, required this.anims, required this.uiMode, required this.onSetTheme, required this.onSetAnims, required this.onSetUiMode});

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
  bool _showManager = false;
  final _pageCtrl = PageController();

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
    _pageCtrl.dispose();
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
    widget.repo.playback.markWatched(v.bvid);
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
    await widget.repo.playback.clearWatched();
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
              widget.repo.feedCache.clearFor(selRid);
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

  Widget _buildVideoCard(BuildContext context, VideoInfo v) {
    final isSelected = selected.contains(v.bvid);
    return VideoCard(
      key: ValueKey('${v.bvid}_${Theme.of(context).brightness}'),
      video: v,
      color: _cardColor,
      outline: _cardOutlineEnabled,
      selected: isSelected,
      editing: editing,
      fading: _fading.contains(v.bvid),
      animDuration: _dur(400),
      cardDuration: _cardDur(220),
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
      onOwnerTap: v.mid > 0 ? () => _openUpChannel(v) : null,
    );
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
                if (widget.repo.settings.rid == 'sub')
                  GestureDetector(
                    onTap: _pickSubFilter,
                    child: const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.filter_alt_outlined, size: 18)),
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
        final Widget content = (() {
        if (widget.repo.settings.rid == 'sub') {
          return SubscriptionScreen(repo: widget.repo, onPlay: widget.onPlay, filterMid: widget.repo.settings.subFilterMid);
        }
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
                final resolved = AppOrientation.resolve(widget.uiMode, MediaQuery.of(context).size.shortestSide);
                final cols = resolved == UiMode.phone ? 1 : (constraints.maxWidth >= 1100 ? 3 : 2);
                final Widget? footer = _hotLoading
                    ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()))
                    : null;
                final extra = footer == null ? 0 : 1;
                if (cols <= 1) {
                  return ListView.separated(
                    controller: _scrollCtrl,
                    key: ValueKey(Theme.of(context).brightness),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    itemCount: list.length + extra,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => i >= list.length ? footer! : _buildVideoCard(context, list[i]),
                  );
                }
                return GridView.builder(
                  controller: _scrollCtrl,
                  key: ValueKey('${Theme.of(context).brightness}_$cols'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
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
        return Stack(children: [
          Positioned.fill(child: PageView(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _showManager = i == 1),
            children: [
              content,
              SubscriptionSheet(repo: widget.repo, onPlay: widget.onPlay),
            ],
          )),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildDock()),
        ]);
      }),
    );
  }

  Widget _buildDock() {
    final cs = Theme.of(context).colorScheme;
    final s = widget.repo.settings;
    final size = s.dockSize * 1.2;
    final alpha = s.dockOpacity;
    final radius = BorderRadius.circular(30 * size);
    final container = Container(
      padding: EdgeInsets.symmetric(horizontal: 18 * size, vertical: 8 * size),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: alpha),
        borderRadius: radius,
        border: s.dockBorder ? Border.all(color: cs.outlineVariant.withValues(alpha: 0.6), width: 1) : null,
        boxShadow: s.dockShadow ? [BoxShadow(color: cs.shadow.withValues(alpha: 0.22), blurRadius: 10, offset: const Offset(0, 3))] : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _dockDot(!_showManager, cs, size, () => _pageCtrl.animateToPage(0, duration: _dur(250), curve: Curves.easeOut)),
        SizedBox(width: 6 * size),
        _dockDot(_showManager, cs, size, () => _pageCtrl.animateToPage(1, duration: _dur(250), curve: Curves.easeOut)),
      ]),
    );
    final dock = s.dockGlass
        ? ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: container),
          )
        : container;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Center(child: dock),
      ),
    );
  }

  Widget _dockDot(bool active, ColorScheme cs, double scale, VoidCallback onTap) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: AnimatedContainer(
            duration: _dur(200),
            width: (active ? 26 : 10) * scale,
            height: 10 * scale,
            decoration: BoxDecoration(
              color: active ? cs.primary : cs.outlineVariant,
              borderRadius: BorderRadius.circular(5 * scale),
            ),
          ),
        ),
      );

  void _exitEditing() => setState(() { editing = false; selected.clear(); });

  Future<void> _skipSelected() async {
    final items = (videos ?? []).where((e) => selected.contains(e.bvid)).toList();
    for (final v in items) {
      await widget.repo.blacklist.add(v);
    }
    if (!mounted) return;
    setState(() {
      videos?.removeWhere((e) => selected.contains(e.bvid));
      selected.clear();
      editing = false;
    });
  }

  Future<void> _showHistory() async {
    if (!widget.repo.history.enabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('历史记录已在设置中关闭')));
      return;
    }
    await _openCollection('历史', widget.repo.history.all, widget.repo.history.remove);
  }

  Future<void> _showWatchLater() async {
    if (!widget.repo.watchLater.enabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('收藏已在设置中关闭')));
      return;
    }
    await _openCollection('收藏', widget.repo.watchLater.all, widget.repo.watchLater.remove);
  }

  Future<void> _openCollection(String title, Future<List<VideoInfo>> Function() loader, Future<void> Function(String bvid) onRemove) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionPage(
      repo: widget.repo,
      title: title,
      loader: loader,
      onRemove: onRemove,
      onPlay: widget.onPlay,
    )));
    if (mounted) setState(() {});
  }

  Future<void> _showSubscriptions() async {
    showModalBottomSheet(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => SubscriptionSheet(repo: widget.repo, onPlay: widget.onPlay));
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
    final subs = await widget.repo.subscriptions.all();
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
    if (mounted) setState(() {});
  }

  void _gotoUp(int mid, String name, String bvid) {    Navigator.push(context, MaterialPageRoute(builder: (_) => UpChannelScreen(
      repo: widget.repo,
      mid: mid,
      name: name,
      bvid: bvid,
      onPlay: widget.onPlay,
    )));
  }

  Future<void> _setDock(double opacity, double size, bool glass, bool border, bool shadow) async {
    await widget.repo.settings.setDockOpacity(opacity);
    await widget.repo.settings.setDockSize(size);
    await widget.repo.settings.setDockGlass(glass);
    await widget.repo.settings.setDockBorder(border);
    await widget.repo.settings.setDockShadow(shadow);
    if (mounted) setState(() {});
  }

  void _showColorSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AppearanceSettingsPage(
      mode: widget.mode,
      theme: widget.seed,
      useDynamic: widget.useDynamic,
      anims: widget.anims,
      uiMode: widget.uiMode,
      dockOpacity: widget.repo.settings.dockOpacity,
      dockSize: widget.repo.settings.dockSize,
      dockGlass: widget.repo.settings.dockGlass,
      dockBorder: widget.repo.settings.dockBorder,
      dockShadow: widget.repo.settings.dockShadow,
      onSetTheme: widget.onSetTheme,
      onSetAnims: widget.onSetAnims,
      onSetUiMode: widget.onSetUiMode,
      onSetDock: _setDock,
    )));
  }


  Future<void> _showBlacklist() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionPage(
      repo: widget.repo,
      title: '黑名单',
      loader: widget.repo.blacklist.all,
      onRemove: widget.repo.blacklist.remove,
      onPlay: widget.onPlay,
    )));
    if (mounted) setState(() {});
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
