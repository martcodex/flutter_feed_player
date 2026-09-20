import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/feed_playback_strategy.dart';

/// Stable video surface that keeps the same [VideoPlayer] instance when
/// promoting a parked controller (avoids black flash / remount).
class PlayerSurface extends StatelessWidget {
  const PlayerSurface({
    super.key,
    required this.controller,
    this.fit = BoxFit.cover,
    this.minLogicalSize = const Size(720, 1280),
  });

  final VideoPlayerController? controller;
  final BoxFit fit;

  /// Logical floor so platform ABR does not pick a soft low rung.
  final Size minLogicalSize;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    if (ctrl == null || !FeedPlaybackStrategy.isReusablePlayer(ctrl)) {
      return const ColoredBox(color: Colors.black);
    }
    final size = ctrl.value.size;
    final w = size.width > 0 ? size.width : minLogicalSize.width;
    final h = size.height > 0 ? size.height : minLogicalSize.height;

    return ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: w < minLogicalSize.width ? minLogicalSize.width : w,
          height: h < minLogicalSize.height ? minLogicalSize.height : h,
          child: VideoPlayer(ctrl),
        ),
      ),
    );
  }
}
