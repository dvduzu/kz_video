import 'package:flutter/material.dart';
import '../data/video_repository.dart';

class ContentSettingsPage extends StatefulWidget {
  final VideoRepository repo;
  final VoidCallback onOpenSubscriptions;
  final VoidCallback onOpenBlacklist;
  const ContentSettingsPage({super.key, required this.repo, required this.onOpenSubscriptions, required this.onOpenBlacklist});

  @override
  State<ContentSettingsPage> createState() => _ContentSettingsPageState();
}

class _ContentSettingsPageState extends State<ContentSettingsPage> {
  late String _rid;
  late String _homeRid;
  late bool _history;
  late bool _watchLater;
  late bool _rcmdEnabled;
  late int _rcmdBatch;
  late String _subAutoUpdate;
  late bool _dimWatched;
  late String _oldRid;
  late String _oldHomeRid;
  late bool _oldRcmdEnabled;
  late int _oldRcmdBatch;

  static const _rids = {'': '全部', 'hot': '热门', 'tech': '科技', 'edu': '知识', 'life': '美食', 'game': '游戏', 'ent': '娱乐', 'music': '音乐', 'sub': '订阅'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = widget.repo.settings;
    setState(() {
      _rid = s.rid;
      _homeRid = s.homeRid;
      _history = s.isHistoryEnabled;
      _watchLater = s.isWatchLaterEnabled;
      _rcmdEnabled = s.rcmdEnabled;
      _rcmdBatch = s.rcmdBatch;
      _subAutoUpdate = s.subAutoUpdate;
      _dimWatched = s.dimWatched;
      _oldRid = s.rid;
      _oldHomeRid = s.homeRid;
      _oldRcmdEnabled = s.rcmdEnabled;
      _oldRcmdBatch = s.rcmdBatch;
    });
  }

  Future<bool> _save() async {
    final s = widget.repo.settings;
    final changed = _rid != _oldRid ||
        _homeRid != _oldHomeRid ||
        _rcmdEnabled != _oldRcmdEnabled ||
        _rcmdBatch != _oldRcmdBatch;
    await s.setRid(_rid);
    await s.setHomeRid(_homeRid);
    await s.setHistoryEnabled(_history);
    await s.setWatchLaterEnabled(_watchLater);
    await s.setRcmdEnabled(_rcmdEnabled);
    await s.setRcmdBatch(_rcmdBatch);
    await s.setSubAutoUpdate(_subAutoUpdate);
    await s.setDimWatched(_dimWatched);
    return changed;
  }

  void _pickHomeRid() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('选择启动主页分区'),
      content: Wrap(spacing: 8, children: _rids.entries.map((e) => ChoiceChip(
        label: Text(e.value),
        selected: _homeRid == e.key,
        onSelected: (_) {
          setState(() => _homeRid = e.key);
          Navigator.pop(ctx);
        },
      )).toList()),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('内容')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const Text('推荐设置', style: TextStyle(fontWeight: FontWeight.bold)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启动主页分区'),
            subtitle: Text('启动时默认进入：${_rids[_homeRid] ?? '全部'}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickHomeRid,
          ),
          const Divider(height: 24),
          SwitchListTile(
            title: const Text('个性化推荐'),
            subtitle: const Text('使用账号个性化推荐（登录后生效）'),
            value: _rcmdEnabled,
            onChanged: (v) => setState(() => _rcmdEnabled = v),
          ),
          if (_rcmdEnabled)
            ExpansionTile(
              leading: const Icon(Icons.tune),
              title: const Text('推荐参数'),
              subtitle: const Text('拉取批数'),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Row(children: [
                  const Text('推荐拉取批数', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 12),
                  Wrap(spacing: 8, children: [1, 3, 5, 8].map((b) => ChoiceChip(
                    label: Text('$b'),
                    selected: _rcmdBatch == b,
                    onSelected: (_) => setState(() => _rcmdBatch = b),
                  )).toList()),
                ]),
                const SizedBox(height: 8),
              ],
            ),
          const Divider(height: 24),
          const Text('订阅', style: TextStyle(fontWeight: FontWeight.bold)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('自动更新', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: {
                'manual': '手动',
                'startup': '启动应用时',
                '30': '30 分钟',
                '60': '1 小时',
                '180': '3 小时',
                '360': '6 小时',
              }.entries.map((e) => ChoiceChip(
                label: Text(e.value),
                selected: _subAutoUpdate == e.key,
                onSelected: (_) => setState(() => _subAutoUpdate = e.key),
              )).toList()),
            ]),
          ),
          const Divider(height: 24),
          const Text('内容管理', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('看完后置灰'),
            subtitle: const Text('当天看过的视频在列表中置灰，次日恢复'),
            value: _dimWatched,
            onChanged: (v) => setState(() => _dimWatched = v),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('管理黑名单'),
            subtitle: const Text('查看/移除已跳过的视频'),
            onTap: widget.onOpenBlacklist,
          ),
          SwitchListTile(
            title: const Text('历史记录'),
            subtitle: const Text('记住看过的视频'),
            value: _history,
            onChanged: (v) => setState(() => _history = v),
          ),
          SwitchListTile(
            title: const Text('书签'),
            subtitle: const Text('收藏到稍后队列'),
            value: _watchLater,
            onChanged: (v) => setState(() => _watchLater = v),
          ),
          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: () async {
              final changed = await _save();
              if (mounted) Navigator.pop(context, changed);
            },
            child: const Text('保存'),
          ),
        ),
      ),
    );
  }
}