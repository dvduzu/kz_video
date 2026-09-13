import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/video_repository.dart';
import 'up_channel_screen.dart';
import 'video_card.dart';

class SubscriptionScreen extends StatefulWidget {
  final VideoRepository repo;
  final void Function(VideoInfo) onPlay;
  final int filterMid;
  const SubscriptionScreen({super.key, required this.repo, required this.onPlay, this.filterMid = 0});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<VideoInfo> _timeline = [];
  bool _updating = false;
  int _done = 0;
  int _total = 0;
  int? _updatedAt;

  @override
  void initState() {
    super.initState();
    _timeline = widget.repo.cachedSubscriptionTimeline();
    _updatedAt = widget.repo.subscriptionUpdatedAt;
  }

  Future<void> _update() async {
    if (_updating) return;
    setState(() {
      _updating = true;
      _done = 0;
      _total = 0;
    });
    try {
      final list = await widget.repo.fetchSubscriptionTimeline(onProgress: (d, t) {
        if (mounted) setState(() { _done = d; _total = t; });
      });
      if (mounted) {
        setState(() {
          _timeline = list;
          _updatedAt = widget.repo.subscriptionUpdatedAt;
        });
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  String _updatedText() {
    final ts = _updatedAt;
    if (ts == null) return '尚未更新';
    final t = DateTime.fromMillisecondsSinceEpoch(ts);
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '刚刚更新';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前更新';
    if (diff.inHours < 24) return '${diff.inHours} 小时前更新';
    return '${t.month}月${t.day}日 ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} 更新';
  }

  List<VideoInfo> get _visible => widget.filterMid == 0 ? _timeline : _timeline.where((v) => v.mid == widget.filterMid).toList();

  void _openUp(VideoInfo v) {
    if (v.mid <= 0) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => UpChannelScreen(
      repo: widget.repo,
      mid: v.mid,
      name: v.owner,
      bvid: v.bvid,
      onPlay: widget.onPlay,
    )));
  }

  @override
  Widget build(BuildContext context) {
    return _timelinePage(Theme.of(context).colorScheme);
  }

  Widget _timelinePage(ColorScheme cs) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('订阅时间线', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(_updatedText(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ])),
          FilledButton.tonalIcon(
            onPressed: _updating ? null : _update,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('更新'),
          ),
        ]),
      ),
      if (_updating)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LinearProgressIndicator(value: _total > 0 ? _done / _total : null),
            const SizedBox(height: 4),
            Text('已更新 $_done / $_total 个 UP 主', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
      Expanded(
        child: _visible.isEmpty
            ? Center(child: Text('还没有内容，点右上角「更新」', style: TextStyle(color: cs.onSurfaceVariant)))
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 96),
                itemCount: _visible.length,
                itemBuilder: (context, i) {
                  final v = _visible[i];
                  return VideoCard(
                    video: v,
                    color: VideoCard.toneColor(context, widget.repo.settings.cardTone),
                    outline: widget.repo.settings.cardOutline,
                    onTap: () => widget.onPlay(v),
                    onOwnerTap: () => _openUp(v),
                  );
                },
              ),
      ),
    ]);
  }
}
