import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/logger.dart';
import '../data/models.dart';
import '../data/video_repository.dart';
import 'up_channel_screen.dart';

class SubscriptionSheet extends StatefulWidget {
  final VideoRepository repo;
  final void Function(VideoInfo) onPlay;
  const SubscriptionSheet({super.key, required this.repo, required this.onPlay});

  @override
  State<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<SubscriptionSheet> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<({int mid, String name, String face})> followed = [];
  final searchCtl = TextEditingController();
  final addCtl = TextEditingController();
  List<SearchUser> results = [];
  bool searching = false;
  String followedFilter = '';
  int tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    followed = await widget.repo.subscriptions.all();
    if (mounted) setState(() {});
  }

  Future<void> _search(String keyword) async {
    setState(() { searching = true; results = []; });
    try {
      results = await widget.repo.searchUsers(keyword.trim());
    } catch (e) {
      KzvLogger.debug('search users failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('搜索失败，请检查网络后重试')));
    }
    if (mounted) setState(() => searching = false);
  }

  void _unfollow(int mid, String uname) async {
    await widget.repo.subscriptions.remove(mid);
    setState(() => followed.removeWhere((f) => f.mid == mid));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已取消关注 $uname'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ));
    }
  }

  void _follow(int mid, String uname, String face) async {
    await widget.repo.subscriptions.add(mid, uname, face: face);
    if (!mounted) return;
    setState(() { followed.insert(0, (mid: mid, name: uname, face: face)); });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('已关注 $uname'),
      duration: const Duration(milliseconds: 1500),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ));
  }

  String _face(String f) {
    if (f.isEmpty) return '';
    return f.startsWith('//') ? 'https:$f' : f.replaceFirst('http://', 'https://');
  }

  void _openUp(int mid, String name) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => UpChannelScreen(
      repo: widget.repo,
      mid: mid,
      name: name,
      bvid: '',
      onPlay: widget.onPlay,
    )));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DefaultTabController(length: 2, child: Builder(builder: (ctx) => Column(children: [
          ListTile(leading: const Icon(Icons.person_add_alt), title: Text('已关注 ${followed.length} 位', style: Theme.of(ctx).textTheme.titleMedium)),
          TabBar(
            onTap: (i) => setState(() => tabIndex = i),
            tabs: const [Tab(text: '已关注'), Tab(text: '添加UP')],
          ),
          if (tabIndex == 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: searchCtl,
                decoration: const InputDecoration(hintText: '搜索已关注的 UP', isDense: true, prefixIcon: Icon(Icons.search, size: 20)),
                onChanged: (v) => setState(() => followedFilter = v.trim()),
              ),
            ),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: followed.length,
              itemBuilder: (_, i) {
                final s = followed[i];
                if (followedFilter.isNotEmpty && !s.name.contains(followedFilter)) return const SizedBox.shrink();
                final name = s.name.isEmpty ? 'UP ${s.mid}' : s.name;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    backgroundImage: s.face.isNotEmpty ? CachedNetworkImageProvider(_face(s.face)) : null,
                    child: s.face.isEmpty ? const Icon(Icons.person) : null,
                  ),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('mid: ${s.mid}'),
                  onTap: () => _openUp(s.mid, name),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _unfollow(s.mid, name)),
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
                  onSubmitted: (_) => _search(addCtl.text),
                )),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.search), onPressed: () => _search(addCtl.text)),
              ]),
            ),
            if (searching)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (results.isNotEmpty)
              Expanded(child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final u = results[i];
                  final isFollowed = followed.any((f) => f.mid == u.mid);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      backgroundImage: u.face.isNotEmpty ? CachedNetworkImageProvider(_face(u.face)) : null,
                      child: u.face.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    title: Text(u.uname, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('粉丝 ${u.fans} · ${u.sign}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _openUp(u.mid, u.uname),
                    trailing: isFollowed
                        ? IconButton(
                            icon: Icon(Icons.check_circle, color: Theme.of(ctx).colorScheme.primary),
                            tooltip: '取消关注',
                            onPressed: () => _unfollow(u.mid, u.uname),
                          )
                        : IconButton(icon: const Icon(Icons.add), tooltip: '关注', onPressed: () => _follow(u.mid, u.uname, u.face)),
                  );
                },
              ))
            else
              const Expanded(child: Center(child: Text('搜索添加 UP 主'))),
          ],
        ]),
      ));
  }
}