import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../data/video_repository.dart';
import 'content_settings_page.dart';
import 'login_sheet.dart';
import 'other_settings_page.dart';

class SettingsPage extends StatefulWidget {
  final VideoRepository repo;
  final VoidCallback onOpenColorSettings;
  final VoidCallback onOpenSubscriptions;
  final VoidCallback onOpenBlacklist;
  final VoidCallback onAppearanceChanged;
  const SettingsPage({super.key, required this.repo, required this.onOpenColorSettings, required this.onOpenSubscriptions, required this.onOpenBlacklist, required this.onAppearanceChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _guestMode = false;

  @override
  void initState() {
    super.initState();
    _loadGuestMode();
  }

  void _loadGuestMode() {
    _guestMode = widget.repo.settings.guestMode;
  }

  void _showAbout() {
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('关于'),
        content: Text(
          'KzVideo\n'
          '版本：${info.version} (${info.buildNumber})\n'
          '克制的 B 站视频客户端\n\n'
          'GitHub：github.com/dvduzu/kz_video'
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
      ));
    });
  }

  void _showImportExport() {
    final data = jsonEncode(widget.repo.exportData());
    final ctl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('导入 / 导出'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: ctl,
          maxLines: 4,
          decoration: const InputDecoration(hintText: '粘贴导出的数据以导入', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        const Text('支持复制/粘贴，或导出/导入到文件', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ])),
      actions: [
        TextButton(onPressed: () {
          Clipboard.setData(ClipboardData(text: data));
          if (ctx.mounted) Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制导出数据')));
        }, child: const Text('复制导出数据')),
        TextButton(onPressed: () async {
          final bytes = utf8.encode(data);
          final saved = await FilePicker.saveFile(
            dialogTitle: '选择导出保存位置',
            fileName: 'kzv_backup.json',
            type: FileType.custom,
            allowedExtensions: ['json'],
            bytes: bytes,
          );
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved != null ? '已导出到 $saved' : '已取消导出')));
        }, child: const Text('导出到文件')),
        TextButton(onPressed: () async {
          final result = await FilePicker.pickFiles(
            dialogTitle: '选择要导入的文件',
            type: FileType.custom,
            allowedExtensions: ['json'],
          );
          if (!ctx.mounted) return;
          final path = result?.files.single.path;
          if (path == null) return;
          Navigator.pop(ctx);
          try {
            final content = await File(path).readAsString();
            final decoded = jsonDecode(content);
            if (decoded is! Map<String, dynamic>) throw const FormatException('格式错误');
            await widget.repo.importData(decoded);
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('导入成功')));
          } catch (_) {
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('导入失败：数据格式无效')));
          }
        }, child: const Text('从文件导入')),
        FilledButton(onPressed: () async {
          try {
            final decoded = jsonDecode(ctl.text.trim());
            if (decoded is! Map<String, dynamic>) throw const FormatException('格式错误');
            await widget.repo.importData(decoded);
            if (ctx.mounted) Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入成功')));
          } catch (_) {
            if (ctx.mounted) Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入失败：数据格式无效')));
          }
        }, child: const Text('导入')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
      ],
    ));
  }

  Future<void> _openContent() async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => ContentSettingsPage(
        repo: widget.repo,
        onOpenSubscriptions: widget.onOpenSubscriptions,
        onOpenBlacklist: widget.onOpenBlacklist,
      ),
    ));
    if (changed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _openOther() async {
    await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => OtherSettingsPage(repo: widget.repo),
    ));
    if (mounted) widget.onAppearanceChanged();
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.video_library_outlined),
            title: const Text('内容'),
            subtitle: const Text('分区 / 个性化 / 历史 / 书签 / 订阅 / 黑名单'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openContent,
          ),
          const Divider(height: 4),
          ListTile(
            leading: const Icon(Icons.sync_alt),
            title: const Text('导入 / 导出'),
            subtitle: const Text('设置 / 订阅 / 黑名单'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showImportExport,
          ),
          const Divider(height: 4),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('外观'),
            subtitle: const Text('深浅模式 / 色调'),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onOpenColorSettings,
          ),
          const Divider(height: 4),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('其他'),
            subtitle: const Text('视频卡片描边 / 卡片底色层级'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openOther,
          ),
          const Divider(height: 4),
          ListTile(
            leading: Icon(repo.hasAccount ? Icons.account_circle : Icons.login),
            title: Text(repo.hasAccount ? '登录状态：${repo.loginName}' : '登录'),
            subtitle: const Text('扫码登录 / Cookie 登录'),
            trailing: const Icon(Icons.chevron_right),
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
                onSelectionChanged: (s) {
                  setState(() => _guestMode = s.first);
                  widget.repo.setGuestMode(s.first);
                  Navigator.pop(context, true);
                },
              ),
            ),
          const Divider(height: 4),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            subtitle: const Text('版本信息 / 项目仓库'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAbout,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}