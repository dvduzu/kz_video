import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/video_repository.dart';

class SubscriptionSheet extends StatefulWidget {
  const SubscriptionSheet({super.key});

  @override
  State<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<SubscriptionSheet> {
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
    followed = await VideoRepository.instance().getSubscriptions();
    if (mounted) setState(() {});
  }

  Future<void> _search(String keyword) async {
    setState(() { searching = true; results = []; });
    try {
      results = await VideoRepository.instance().searchUsers(keyword.trim());
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('搜索失败，请检查网络后重试')));
    }
    if (mounted) setState(() => searching = false);
  }

  void _unfollow(int mid, String uname) async {
    await VideoRepository.instance().removeSubscription(mid);
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
    final ok = await VideoRepository.instance().addSubscription(mid, uname, face: face);
    if (!mounted) return;
    if (ok) {
      setState(() { followed.insert(0, (mid: mid, name: uname, face: face)); });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已关注 $uname'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('订阅已满 50 人'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DefaultTabController(length: 2, child: Builder(builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(children: [
          ListTile(leading: const Icon(Icons.person_add_alt), title: Text('订阅管理 (${followed.length}/50)', style: Theme.of(ctx).textTheme.titleMedium)),
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
              itemCount: followed.length,
              itemBuilder: (_, i) {
                final s = followed[i];
                if (followedFilter.isNotEmpty && !s.name.contains(followedFilter)) return const SizedBox.shrink();
                return ListTile(
                  title: Text(s.name.isEmpty ? 'UP ${s.mid}' : s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('mid: ${s.mid}'),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _unfollow(s.mid, s.name.isEmpty ? 'UP ${s.mid}' : s.name)),
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
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final u = results[i];
                  final isFollowed = followed.any((f) => f.mid == u.mid);
                  return ListTile(
                    title: Text(u.uname, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('粉丝 ${u.fans} · ${u.sign}', maxLines: 1, overflow: TextOverflow.ellipsis),
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
      ))),
    );
  }
}