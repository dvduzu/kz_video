import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/video_repository.dart';

Future<void> showLoginDialog(BuildContext context, VideoRepository repo) async {
  final loggedIn = repo.hasAccount;
  if (loggedIn) {
    String fmt(int ms) {
      if (ms <= 0) return '未知';
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    final loginAt = repo.loginAt;
    final expires = repo.sessExpires > 0 ? DateTime.fromMillisecondsSinceEpoch(repo.sessExpires * 1000) : null;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('登录状态'),
      content: Text(
        '账号：${repo.loginName.isEmpty ? 'B站账号' : repo.loginName}\n'
        '当前：${repo.guestMode ? '游客模式' : '已登录'}\n'
        '登录时间：${loginAt > 0 ? fmt(loginAt) : '未知'}\n'
        '过期时间：${expires != null ? fmt(expires.millisecondsSinceEpoch) : '未知'}'
      ),
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
      TextButton(onPressed: () { Navigator.pop(ctx); showQrLoginDialog(context, repo); }, child: const Text('扫码登录')),
      TextButton(onPressed: () { Navigator.pop(ctx); showCookieLoginDialog(context, repo); }, child: const Text('Cookie 登录')),
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
    ],
  ));
}

void showCookieLoginDialog(BuildContext context, VideoRepository repo) {
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

void showQrLoginDialog(BuildContext context, VideoRepository repo) {
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
    await for (final ok in repo.webQrLoginFlow(gen.key)) {
      if (!context.mounted) return;
      if (ok) {
        status.value = '登录成功';
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (context.mounted) Navigator.pop(context);
        return;
      }
    }
    status.value = '二维码已过期，请重新获取';
  }
  start();
}