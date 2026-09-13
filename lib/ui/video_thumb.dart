import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class VideoThumb extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final double radius;
  const VideoThumb({super.key, required this.url, this.width = 128, this.height = 76, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        memCacheWidth: (width * 2).round(),
        errorWidget: (_, __, ___) => Container(
          width: width,
          height: height,
          color: cs.surfaceContainerHighest,
          child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
