String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String formatCount(int c) => c >= 10000 ? '${(c / 10000).toStringAsFixed(1)}万' : '$c';

String formatDate(int ts) {
  if (ts <= 0) return '';
  final t = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  final now = DateTime.now();
  return t.year == now.year ? '${t.month}月${t.day}日' : '${t.year}年${t.month}月${t.day}日';
}
