import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/video_repository.dart';
import 'video_card.dart';

class CollectionPage extends StatefulWidget {
  final VideoRepository repo;
  final String title;
  final Future<List<VideoInfo>> Function() loader;
  final Future<void> Function(String bvid) onRemove;
  final void Function(VideoInfo) onPlay;
  const CollectionPage({super.key, required this.repo, required this.title, required this.loader, required this.onRemove, required this.onPlay});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  List<VideoInfo> _items = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _selectMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.loader();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) _selected.clear();
    });
  }

  Future<void> _removeSelected() async {
    for (final bvid in _selected.toList()) {
      await widget.onRemove(bvid);
    }
    if (!mounted) return;
    setState(() {
      _items.removeWhere((v) => _selected.contains(v.bvid));
      _selected.clear();
      _selectMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _items.isNotEmpty && _selected.length == _items.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_selectMode) ...[
            TextButton(
              onPressed: _items.isEmpty ? null : () => setState(() {
                _selected.clear();
                if (!allSelected) _selected.addAll(_items.map((e) => e.bvid));
              }),
              child: Text(allSelected ? '取消全选' : '全选'),
            ),
            TextButton(onPressed: _selected.isEmpty ? null : _removeSelected, child: const Text('删除')),
          ],
          IconButton(icon: Icon(_selectMode ? Icons.close : Icons.checklist), tooltip: _selectMode ? '退出多选' : '多选', onPressed: _toggleSelectMode),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('暂无内容'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final v = _items[i];
                    return VideoCard(
                      video: v,
                      color: VideoCard.toneColor(context, widget.repo.settings.cardTone),
                      outline: widget.repo.settings.cardOutline,
                      selected: _selected.contains(v.bvid),
                      editing: _selectMode,
                      onTap: () {
                        if (_selectMode) {
                          setState(() {
                            _selected.contains(v.bvid) ? _selected.remove(v.bvid) : _selected.add(v.bvid);
                          });
                        } else {
                          widget.onPlay(v);
                        }
                      },
                      onLongPress: () => setState(() {
                        _selectMode = true;
                        _selected.add(v.bvid);
                      }),
                    );
                  },
                ),
    );
  }
}
