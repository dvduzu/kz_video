import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    });
  }

  static const List<({String version, String date, List<String> items})> _logs = [
    (version: '0.4.0-pre1', date: '2026-09-13', items: [
      '订阅分区改为时间线：去重后按发布时间倒序，新增「更新」按钮、上次更新时间与进度',
      '新增全局底部 Dock（所有分区），左右滑动或点击切换到订阅管理',
      '外观「底部栏」：透明度、大小、液态玻璃、描边、阴影',
      '弹幕改用 gRPC 全量拉取（修复部分弹幕），新增智能云屏蔽等级，修复 seek 补入',
      'DASH 优先选择非 mcdn 节点，减少首帧卡顿',
      '数据层重构（api / store / repository）并新增单元测试',
      '新增界面模式（自动 / 手机 / 平板）；统一视频卡片；历史/收藏/黑名单独立页面',
    ]),
    (version: '0.3.1', date: '2026-09-12', items: [
      '播放器迁移到 AndroidX Media3 ExoPlayer（Texture 渲染）',
      '后台播放、通知栏媒体控制、锁屏/耳机键',
      '播放页全屏沉浸',
      '动画细粒度配置（总开关 / 速度 / 页面 / 列表 / 卡片）',
    ]),
    (version: '0.3.0', date: '', items: [
      '外观页色块改为圆形色环 UI',
      '卡片底色层级可调',
      'Vibrant 色相修复、动态色彩与种子色解耦',
      '导入 / 导出（文件选择器）',
    ]),
    (version: '0.2.1', date: '', items: [
      '订阅阈值拖动条支持「不限」',
      '设备身份并发保护、bili_ticket 独立重试',
      '外观独立页面；启动主页分区修复',
    ]),
    (version: '0.2.0', date: '', items: [
      '分区切换走缓存，保留原内容',
      '播放页 Stack 叠加，返回不刷新列表',
      '标题显示当前分区名',
    ]),
    (version: '0.1.5', date: '', items: [
      '主页分区设置（默认全部）',
      '收藏上限 50 + 计数显示',
      '设置改多级子页（内容 / 外观 / 账号 / 关于）',
      '已看完持久化；历史 / 收藏批量删除',
    ]),
    (version: '0.1.4', date: '', items: [
      '订阅独立分区 + 个性化推荐（rcmd）',
      '异常分类与日志统一',
    ]),
    (version: '0.1.3', date: '', items: [
      '扫码登录、UP 搜索、订阅双板块',
      '颜色设置（深浅 / 色调）、字幕支持',
      '设置页独立、游客模式',
    ]),
    (version: '0.1.2', date: '', items: [
      '订阅双轨（web arc/search + app cursor 降级）',
      '分区 tid 映射真正生效',
    ]),
    (version: '0.1.1', date: '', items: [
      '进度条拖动实时预览',
      '订阅关注 / 取消、上限',
    ]),
    (version: '0.1.0', date: '2026-08-31', items: [
      '首个版本：分区选择、UP 订阅（关注 / 订阅管理 / 推荐混合）',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('关于 / 更新日志')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.video_library_outlined, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('KzVideo', style: Theme.of(context).textTheme.titleMedium),
                ]),
                const SizedBox(height: 8),
                Text('当前版本：${_version.isEmpty ? '...' : _version}', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text('github.com/dvduzu/kz_video', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          for (final log in _logs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                    child: Text('v${log.version}', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimaryContainer)),
                  ),
                  const SizedBox(width: 8),
                  if (log.date.isNotEmpty) Text(log.date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ]),
                const SizedBox(height: 6),
                for (final item in log.items)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: Container(width: 4, height: 4, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle))),
                      Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium)),
                    ]),
                  ),
                const Divider(height: 24),
              ]),
            ),
        ],
      ),
    );
  }
}
