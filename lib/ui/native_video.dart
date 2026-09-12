import 'package:flutter/material.dart';
import '../data/native_player.dart';

class NativeVideo extends StatelessWidget {
  final NativePlayer player;
  const NativeVideo({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final id = player.textureId;
    if (id == null) return const SizedBox.shrink();
    return AspectRatio(
      aspectRatio: player.aspectRatio,
      child: Texture(textureId: id),
    );
  }
}
