import 'package:flutter/material.dart';
import '../core/format.dart';
import '../data/models.dart';
import 'video_thumb.dart';

class VideoCard extends StatelessWidget {
  final VideoInfo video;
  final Color color;
  final bool outline;
  final bool selected;
  final bool editing;
  final bool fading;
  final Duration animDuration;
  final Duration cardDuration;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onOwnerTap;
  const VideoCard({
    super.key,
    required this.video,
    required this.color,
    this.outline = false,
    this.selected = false,
    this.editing = false,
    this.fading = false,
    this.animDuration = Duration.zero,
    this.cardDuration = Duration.zero,
    this.onTap,
    this.onLongPress,
    this.onOwnerTap,
  });

  static Color toneColor(BuildContext context, String tone) {
    final cs = Theme.of(context).colorScheme;
    return switch (tone) {
      'low' => cs.surfaceContainerLow,
      'medium' => cs.surfaceContainer,
      'highest' => cs.surfaceContainerHighest,
      _ => cs.surfaceContainerHigh,
    };
  }

  String? _meta(VideoInfo v) {
    final parts = <String>[
      if (v.pubdate > 0) formatDate(v.pubdate),
      if (v.duration > 0) formatDuration(v.duration),
      if (v.view > 0) '${formatCount(v.view)} 播放',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final meta = _meta(video);
    return AnimatedSize(
      duration: animDuration,
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        duration: animDuration,
        opacity: fading ? 0 : 1,
        child: AnimatedContainer(
          duration: cardDuration,
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(4),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : color,
            borderRadius: BorderRadius.circular(12),
            border: outline
                ? Border.all(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 1.5 : 1)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VideoThumb(url: video.pic),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurface)),
                            const SizedBox(height: 4),
                            if (video.owner.isNotEmpty)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onOwnerTap,
                                child: Text(video.owner, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                              ),
                            if (meta != null)
                              Text(meta, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                    if (editing)
                      Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? cs.primary : cs.outline),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
