import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/feed_playback_strategy.dart';
import 'player_seek_bar.dart';
import 'player_surface.dart';

/// Geometry for 16:9 and other landscape clips inside a portrait feed.
class LandscapeVideoLayout {
  const LandscapeVideoLayout._();

  /// 16:9 (with a little tolerance) or any clip wider than it is tall.
  static bool isWide(Size? size) {
    if (size == null || size.width <= 0 || size.height <= 0) return false;
    final ratio = size.width / size.height;
    if ((ratio - 16 / 9).abs() <= 0.04) return true;
    return size.width > size.height;
  }

  /// Letterboxed video rect, centered in the viewport.
  static Rect frame({
    required Size viewport,
    required double aspectRatio,
    required EdgeInsets padding,
  }) {
    final ratio = aspectRatio <= 0 ? 16 / 9 : aspectRatio;
    var width = viewport.width;
    var height = width / ratio;
    final maxHeight = viewport.height - padding.vertical - 16;
    if (maxHeight > 0 && height > maxHeight) {
      height = maxHeight;
      width = height * ratio;
    }
    final left = (viewport.width - width) / 2;
    var top = (viewport.height - height) / 2;
    if (top < padding.top) top = padding.top;
    return Rect.fromLTWH(left, top, width, height);
  }

  /// Video layer plus an optional fullscreen chip above the feed chrome.
  static LandscapeSurfaceLayers layers({
    required Key surfaceKey,
    required VideoPlayerController? player,
    required bool enabled,
    required bool isActive,
    required bool fullscreenOpen,
    required Size viewport,
    required EdgeInsets padding,
    required String fullscreenLabel,
    required VoidCallback onFullscreen,
  }) {
    final shown = fullscreenOpen && isActive ? null : player;
    final size = player?.value.size;
    final wide = enabled &&
        isWide(size) &&
        player != null &&
        viewport.width > 0 &&
        viewport.height > 0;
    if (!wide) {
      return LandscapeSurfaceLayers(
        behind: [
          PlayerSurface(key: surfaceKey, controller: shown),
        ],
      );
    }
    final rect = frame(
      viewport: viewport,
      aspectRatio: size!.width / size.height,
      padding: padding,
    );
    return LandscapeSurfaceLayers(
      behind: [
        Positioned.fromRect(
          rect: rect,
          child: PlayerSurface(
            key: surfaceKey,
            controller: shown,
            letterbox: true,
          ),
        ),
      ],
      above: [
        if (isActive && !fullscreenOpen)
          Positioned(
            left: 0,
            right: 0,
            top: rect.bottom + 10,
            child: Center(
              child: LandscapeFullscreenButton(
                label: fullscreenLabel,
                onPressed: onFullscreen,
              ),
            ),
          ),
      ],
    );
  }
}

/// Split stack children so the fullscreen chip can sit above gestures.
class LandscapeSurfaceLayers {
  const LandscapeSurfaceLayers({
    required this.behind,
    this.above = const [],
  });

  final List<Widget> behind;
  final List<Widget> above;
}

/// Pill button used under a landscape clip and inside the fullscreen stage.
class LandscapeFullscreenButton extends StatelessWidget {
  const LandscapeFullscreenButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.fullscreen,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Landscape playback that fills the screen.
///
/// The host app stays portrait-locked. The stage itself is rotated so turning
/// the phone sideways makes the picture upright. [onExit] returns to the
/// small player.
class LandscapeFullscreenStage extends StatefulWidget {
  const LandscapeFullscreenStage({
    super.key,
    required this.controller,
    required this.onExit,
    required this.exitLabel,
    this.onTap,
    this.onPlaybackEnded,
  });

  final VideoPlayerController? controller;
  final VoidCallback onExit;
  final String exitLabel;

  /// Toggles play and pause when the screen is tapped.
  final VoidCallback? onTap;

  /// Fired once when the current clip reaches the end, so the host can leave
  /// fullscreen instead of staying on the finished frame.
  final VoidCallback? onPlaybackEnded;

  @override
  State<LandscapeFullscreenStage> createState() =>
      _LandscapeFullscreenStageState();
}

class _LandscapeFullscreenStageState extends State<LandscapeFullscreenStage> {
  bool _endedNotified = false;
  VideoPlayerController? _listened;

  @override
  void initState() {
    super.initState();
    _bind(widget.controller);
  }

  @override
  void didUpdateWidget(LandscapeFullscreenStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _endedNotified = false;
      _unbind();
      _bind(widget.controller);
    }
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  void _bind(VideoPlayerController? controller) {
    _listened = controller;
    controller?.addListener(_onPlayer);
  }

  void _unbind() {
    _listened?.removeListener(_onPlayer);
    _listened = null;
  }

  void _onPlayer() {
    final ctrl = _listened;
    if (!_endedNotified &&
        ctrl != null &&
        FeedPlaybackStrategy.isPlaybackEnded(ctrl.value)) {
      _endedNotified = true;
      widget.onPlaybackEnded?.call();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final landscape = size.width > size.height;
    final playing = widget.controller?.value.isPlaying ?? false;

    final stage = Stack(
      fit: StackFit.expand,
      children: [
        PlayerSurface(
          controller: widget.controller,
          letterbox: true,
        ),
        if (widget.onTap != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onTap,
            ),
          ),
        if (!playing && widget.onTap != null)
          const IgnorePointer(
            child: Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 64,
              ),
            ),
          ),
        Positioned(
          left: landscape ? padding.left + 72 : 80,
          right: landscape ? padding.right + 72 : 80,
          bottom: landscape ? padding.bottom + 2 : 4,
          child: Row(
            children: [
              Expanded(child: PlayerSeekBar(controller: widget.controller)),
              IconButton(
                onPressed: widget.onExit,
                tooltip: widget.exitLabel,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.fullscreen_exit,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return ColoredBox(
      color: Colors.black,
      child: landscape
          ? stage
          : RotatedBox(
              quarterTurns: 1,
              child: SizedBox(
                width: size.height,
                height: size.width,
                child: stage,
              ),
            ),
    );
  }
}
