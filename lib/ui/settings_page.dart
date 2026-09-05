import 'package:flutter/material.dart';
import '../data/video_repository.dart';
import 'login_sheet.dart';

class SettingsPage extends StatefulWidget {
  final VideoRepository repo;
  final VoidCallback onOpenColorSettings;
  final VoidCallback onOpenSubscriptions;
  final VoidCallback onOpenBlacklist;
  const SettingsPage({super.key, required this.repo, required this.onOpenColorSettings, required this.onOpenSubscriptions, required this.onOpenBlacklist});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _minDuration;
  late String _rid;
  late bool _history;
  late bool _watchLater;
  late bool _rcmdEnabled;
  late int _rcmdBatch;
  late Set<String> _rcmdRids;
  late bool _guestMode;

  static const _durs = {600: '10 分钟', 1200: '20 分钟', 1800: '30 分钟'};
  static const _rids = {'': '全部', 'tech': '科技', 'edu': '知识', 'life': '美食', 'game': '游戏', 'ent': '娱乐', 'music': '音乐', 'sub': '订阅'};
  static const _rcmdRidLabels = {'': '全部', 'tech': '科技', 'edu': '知识', 'life': '美食', 'game': '游戏', 'ent': '娱乐', 'music': '音乐'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = widget.repo.settings;
    setState(() {
      _minDuration = s.minDuration;
      _rid = s.rid;
      _history = s.isHistoryEnabled;
      _watchLater = s.isWatchLaterEnabled;
      _rcmdEnabled = s.rcmdEnabled;
      _rcmdBatch = s.rcmdBatch;
      _rcmdRids = s.rcmdRids.toSet();
      _guestMode = s.guestMode;
    });
  }

  Future<void> _save() async {
    final s = widget.repo.settings;
    await s.setMinDuration(_minDuration);
    await s.setRid(_rid);
    await s.setHistoryEnabled(_history);
    await s.setWatchLaterEnabled(_watchLater);
    await s.setRcmdEnabled(_rcmdEnabled);
    await s.setRcmdBatch(_rcmdBatch);
    await s.setRcmdRids(_rcmdRids.toList());
    await widget.repo.setGuestMode(_guestMode);
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const Text('分区', style: TextStyle(fontWeight: FontWeight.bold)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Text('按分区排行拉取，非本地过滤', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Wrap(spacing: 8, children: _rids.entries.map((e) => ChoiceChip(
            label: Text(e.value),
            selected: _rid == e.key,
            onSelected: (_) => setState(() => _rid = e.key),
          )).toList()),
          const SizedBox(height: 16),
          const Text('长视频阈值', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(spacing: 8, children: _durs.entries.map((e) => ChoiceChip(
            label: Text(e.value),
            selected: _minDuration == e.key,
            onSelected: (_) => setState(() => _minDuration = e.key),
          )).toList()),
          const Divider(height: 24),
          if (!_guestMode) ...[
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
                subtitle: const Text('拉取批数 / 个性化分区'),
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
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('个性化分区', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, children: _rcmdRidLabels.entries.map((e) => FilterChip(
                      label: Text(e.value),
                      selected: _rcmdRids.contains(e.key),
                      onSelected: (sel) => setState(() {
                        if (sel) { _rcmdRids.add(e.key); } else { _rcmdRids.remove(e.key); }
                      }),
                    )).toList()),
                  ]),
                  const SizedBox(height: 8),
                ],
              ),
          ],
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('颜色设置'),
            subtitle: const Text('深浅模式 / 色调'),
            onTap: widget.onOpenColorSettings,
          ),
          ListTile(
            leading: Icon(repo.hasAccount ? Icons.account_circle : Icons.login),
            title: Text(repo.hasAccount ? '登录状态：${repo.loginName}' : '登录'),
            subtitle: const Text('扫码登录 / Cookie 登录'),
            onTap: () => showLoginDialog(context, widget.repo),
          ),
          if (repo.hasAccount)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('已登录'), icon: Icon(Icons.person)),
                  ButtonSegment(value: true, label: Text('游客'), icon: Icon(Icons.visibility_off)),
                ],
                selected: {_guestMode},
                onSelectionChanged: (s) => setState(() => _guestMode = s.first),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: const Text('订阅管理'),
            subtitle: const Text('关注 UP 主，推荐会包含他们的新视频'),
            onTap: widget.onOpenSubscriptions,
          ),
          SwitchListTile(
            title: const Text('历史记录'),
            subtitle: const Text('记住看过的视频'),
            value: _history,
            onChanged: (v) => setState(() => _history = v),
          ),
          SwitchListTile(
            title: const Text('收藏'),
            subtitle: const Text('收藏到稍后队列'),
            value: _watchLater,
            onChanged: (v) => setState(() => _watchLater = v),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('管理黑名单'),
            subtitle: const Text('查看/移除已跳过的视频'),
            onTap: widget.onOpenBlacklist,
          ),
          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: () async {
              await _save();
              if (mounted) Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ),
      ),
    );
  }
}