import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

  Future<void> _onRefresh() async {
    if (!await VideoRepository.instance().canRefreshToday()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('今天已结束，明天再来')));
      return;
    }
    await VideoRepository.instance().recordRefresh();
    await _load(force: true);
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
    var followed = await VideoRepository.instance().getSubscriptions();
    if (!mounted) return;
    final searchCtl = TextEditingController();
    final addCtl = TextEditingController();
    var results = <SearchUser>[];
    var searching = false;
    var followedFilter = '';
    var tabIndex = 0;
    showModalBottomSheet(context: context, showDragHandle: true, isScrollControlled: true, builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: DefaultTabController(length: 2, child: StatefulBuilder(builder: (ctx, setSheet) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(children: [
          ListTile(leading: const Icon(Icons.person_add_alt), title: Text('订阅管理 (${followed.length}/50)', style: Theme.of(ctx).textTheme.titleMedium)),
          TabBar(
            onTap: (i) => setSheet(() => tabIndex = i),
            tabs: const [Tab(text: '已关注'), Tab(text: '添加UP')],
          ),
          if (tabIndex == 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: searchCtl,
                decoration: const InputDecoration(hintText: '搜索已关注的 UP', isDense: true, prefixIcon: Icon(Icons.search, size: 20)),
                onChanged: (v) => setSheet(() => followedFilter = v.trim()),
              ),
            ),
            Expanded(child: ListView.builder(
              itemCount: followed.length,
              itemBuilder: (_, i) {
                final s = followed[i];
                if (followedFilter.isNotEmpty && !s.name.contains(followedFilter)) return const SizedBox.shrink();
                return ListTile(
                  title: Text(s.name.isEmpty ? 'UP ${s.mid}' : s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('mid: ${s.mid}'),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
                    await VideoRepository.instance().removeSubscription(s.mid);
                    setSheet(() => followed.removeWhere((f) => f.mid == s.mid));
                  }),
                );
              },
            )),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: addCtl,
                  decoration: const InputDecoration(hintText: '搜索站内 UP 主', isDense: true, prefixIcon: Icon(Icons.search, size: 20)),
                  onSubmitted: (_) async {
                    setSheet(() { searching = true; results = []; });
                    results = await VideoRepository.instance().searchUsers(addCtl.text.trim());
                    if (ctx.mounted) setSheet(() { searching = false; });
                  },
                )),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.search), onPressed: () async {
                  setSheet(() { searching = true; results = []; });
                  results = await VideoRepository.instance().searchUsers(addCtl.text.trim());
                  if (ctx.mounted) setSheet(() { searching = false; });
                }),
              ]),
            ),
            if (searching)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (results.isNotEmpty)
              Expanded(child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final u = results[i];
                  final isFollowed = followed.any((f) => f.mid == u.mid);
                  return ListTile(
                    title: Text(u.uname, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('粉丝 ${u.fans} · ${u.sign}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: isFollowed
                        ? Icon(Icons.check_circle, color: Theme.of(ctx).colorScheme.primary)
                        : IconButton(icon: const Icon(Icons.add), tooltip: '关注', onPressed: () async {
                            final ok = await VideoRepository.instance().addSubscription(u.mid, u.uname, face: u.face);
                            if (ctx.mounted) {
                              if (ok) {
                                setSheet(() {
                                  followed.insert(0, (mid: u.mid, name: u.uname, face: u.face));
                                });
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text('已关注 ${u.uname}'),
                                  duration: const Duration(milliseconds: 1500),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                ));
                              } else {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: const Text('订阅已满 50 人'),
                                  duration: Duration(milliseconds: 1500),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                ));
                              }
                            }
                          }),
                  );
                },
              ))
            else
              const Expanded(child: Center(child: Text('搜索添加 UP 主'))),
          ],
        ]),
      )),
    )));
  }

  Future<void> _showLogin() async {
    final repo = VideoRepository.instance();
    final loggedIn = repo.isLoggedIn;
    if (loggedIn) {
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('登录状态'),
        content: Text('已登录：${repo.loginName.isEmpty ? 'B站账号' : repo.loginName}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
          TextButton(onPressed: () async {
            await repo.logout();
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('退出登录')),
        ],
      ));
      return;
    }
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('登录'),
      content: const Text('选择登录方式：'),
      actions: [
        TextButton(onPressed: () { Navigator.pop(ctx); _showQrLogin(); }, child: const Text('扫码登录')),
        TextButton(onPressed: () { Navigator.pop(ctx); _showCookieLogin(); }, child: const Text('Cookie 登录')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
      ],
    ));
  }

  void _showCookieLogin() {
    final repo = VideoRepository.instance();
    final ctl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Cookie 登录'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('从已登录 B 站网页的浏览器复制 Cookie（需含 SESSDATA），粘贴到下方：', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        TextField(
          controller: ctl,
          maxLines: 4,
          decoration: const InputDecoration(hintText: '粘贴 Cookie 字符串', border: OutlineInputBorder()),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async {
          final ok = await repo.loginWithCookie(ctl.text.trim());
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(ok ? '登录成功' : '登录失败，请检查 Cookie 是否含 SESSDATA')));
          }
        }, child: const Text('登录')),
      ],
    ));
  }

  void _showQrLogin() {
    final repo = VideoRepository.instance();
    final qrUrl = ValueNotifier<String?>(null);
    final status = ValueNotifier('正在获取二维码…');
    showDialog(context: context, builder: (ctx) => ValueListenableBuilder<String?>(
      valueListenable: qrUrl,
      builder: (ctx, url, _) => AlertDialog(
        title: const Text('扫码登录'),
        content: SingleChildScrollView(child: SizedBox(
          width: 260,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (url != null) ...[
              QrImageView(data: url, size: 200),
              const SizedBox(height: 8),
            ],
            ValueListenableBuilder<String>(valueListenable: status, builder: (ctx, s, _) => Text(s, style: const TextStyle(fontSize: 13))),
          ]),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    ));
    Future<void> start() async {
      final gen = await repo.webQrGenerate();
      if (gen == null) {
        status.value = '获取二维码失败';
        return;
      }
      qrUrl.value = gen.url;
      status.value = '请用 B 站 App 扫码';
      var tries = 0;
      while (tries < 90) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) {
          final ok = await repo.webQrPoll(gen.key);
          if (ok) {
            status.value = '登录成功';
            await Future<void>.delayed(const Duration(milliseconds: 500));
            if (context.mounted) Navigator.pop(context);
            return;
          }
          tries++;
        } else {
          return;
        }
      }
      status.value = '二维码已过期，请重新获取';
    }
    start();
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
    final sourceMode = prefs.getString('setting_source_mode') ?? 'mixed';
    final showModeSel = prefs.getBool('setting_source_mode_enabled') ?? false;
    if (!mounted) return;
    final result = await showModalBottomSheet<({int minDuration, String rid, bool history, bool watchLater, bool manualAdd, String sourceMode, bool showModeSel})>(
      context: context, showDragHandle: true, isScrollControlled: true,
      builder: (ctx) {
        var selDur = minDuration;
        var selRid = rid;
        var selHistory = history;
        var selWatchLater = watchLater;
        var selManual = manualAdd;
        var selMode = sourceMode;
        var selShowMode = showModeSel;
        const durs = {600: '10 分钟', 1200: '20 分钟', 1800: '30 分钟'};
        const rids = {'': '全部', 'tech': '科技', 'edu': '知识', 'life': '美食', 'game': '游戏', 'ent': '娱乐', 'music': '音乐'};
        return StatefulBuilder(builder: (ctx, setModalState) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('分区', style: TextStyle(fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text('按分区排行拉取，非本地过滤', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
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
              leading: Icon(VideoRepository.instance().isLoggedIn ? Icons.account_circle : Icons.login),
              title: Text(VideoRepository.instance().isLoggedIn ? '登录状态：${VideoRepository.instance().loginName}' : '登录'),
              subtitle: const Text('扫码登录 / Cookie 登录'),
              onTap: () { Navigator.pop(ctx); _showLogin(); },
            ),
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
                  subtitle: const Text('在订阅管理中按 mid 手动关注'),
                  value: selManual,
                  onChanged: (v) => setModalState(() => selManual = v),
                ),
                const Divider(height: 4),
                SwitchListTile(
                  title: const Text('数据源模式切换'),
                  subtitle: const Text('默认混合（订阅+热门），开启后可选'),
                  value: selShowMode,
                  onChanged: (v) => setModalState(() => selShowMode = v),
                ),
                if (selShowMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(spacing: 8, children: {
                      'mixed': '混合',
                      'sub': '纯订阅',
                      'popular': '纯热门',
                    }.entries.map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: selMode == e.key,
                      onSelected: (_) => setModalState(() => selMode = e.key),
                    )).toList()),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () => Navigator.pop(ctx, (minDuration: selDur, rid: selRid, history: selHistory, watchLater: selWatchLater, manualAdd: selManual, sourceMode: selMode, showModeSel: selShowMode)),
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
      await prefs.setString('setting_source_mode', result.sourceMode);
      await prefs.setBool('setting_source_mode_enabled', result.showModeSel);
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
