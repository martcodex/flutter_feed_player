import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/episode_playback_strategy.dart';
import '../widgets/player_seek_bar.dart';
import 'episode_player_controller.dart';
import 'episode_player_view.dart';

/// Default episode chrome: top bar, side actions, bottom meta/seek, boost badge.
///
/// Respects [EpisodePlayerController.showChrome] with fade animation.
class EpisodePlayerChrome extends StatelessWidget {
  const EpisodePlayerChrome({
    super.key,
    required this.slot,
    this.onBack,
    this.onShare,
    this.onOpenEpisodeList,
    this.showTopBar = true,
    this.showSideActions = true,
    this.showBottomChrome = true,
    this.showCenterPlay = true,
    this.showBoostBadge = true,
  });

  final EpisodePlayerSlot slot;
  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final VoidCallback? onOpenEpisodeList;
  final bool showTopBar;
  final bool showSideActions;
  final bool showBottomChrome;
  final bool showCenterPlay;
  final bool showBoostBadge;

  @override
  Widget build(BuildContext context) {
    if (!slot.isActive) return const SizedBox.shrink();

    final c = slot.controller;
    final ep = slot.episode;
    final series = slot.series;
    final topPad = MediaQuery.paddingOf(context).top;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Paused with chrome hidden — keep a play affordance.
        if (showCenterPlay && !c.showChrome && c.showCenterPlay)
          EpisodeCenterControl(
            isPlaying: false,
            onPressed: c.togglePlayPause,
          ),
        AnimatedOpacity(
          opacity: c.showChrome ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !c.showChrome,
            child: Stack(
              children: [
                if (showCenterPlay)
                  EpisodeCenterControl(
                    isPlaying: c.isPlaying,
                    onPressed: c.togglePlayPause,
                  ),
                if (showTopBar)
                  EpisodeTopBar(
                    topPad: topPad,
                    label: ep.displayLabel,
                    speed: c.playbackSpeed,
                    onBack: onBack ?? () => Navigator.maybePop(context),
                    onSpeed: () => showEpisodeSpeedSheet(context, c),
                  ),
                if (showSideActions)
                  EpisodeSideActions(
                    onEpisodes: onOpenEpisodeList ??
                        () => showEpisodeListSheet(context),
                    onShare: onShare,
                  ),
                if (showBottomChrome)
                  EpisodeBottomChrome(
                    title: series.title,
                    episodeTitle:
                        ep.title.isNotEmpty ? ep.title : ep.displayLabel,
                    description: ep.description.isNotEmpty
                        ? ep.description
                        : series.description,
                    seekController: slot.player,
                    onSeekStart: c.revealChrome,
                  ),
              ],
            ),
          ),
        ),
        if (showBoostBadge && c.isBoosting) const EpisodeBoostBadge(),
      ],
    );
  }
}

/// Large center play / pause control.
class EpisodeCenterControl extends StatelessWidget {
  const EpisodeCenterControl({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.size = 72,
    this.color = Colors.white70,
  });

  final bool isPlaying;
  final VoidCallback onPressed;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        onPressed: onPressed,
        iconSize: size,
        icon: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: color,
        ),
      ),
    );
  }
}

/// Large center play glyph (non-interactive). Prefer [EpisodeCenterControl].
class EpisodeCenterPlayIcon extends StatelessWidget {
  const EpisodeCenterPlayIcon({
    super.key,
    this.size = 72,
    this.color = Colors.white70,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Icon(Icons.play_arrow_rounded, color: color, size: size),
      ),
    );
  }
}

/// "2.0x" badge while long-press boosting.
class EpisodeBoostBadge extends StatelessWidget {
  const EpisodeBoostBadge({
    super.key,
    this.label = '2.0x',
    this.top = 120,
  });

  final String label;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Back / title / speed row.
class EpisodeTopBar extends StatelessWidget {
  const EpisodeTopBar({
    super.key,
    required this.topPad,
    required this.label,
    required this.speed,
    required this.onBack,
    required this.onSpeed,
  });

  final double topPad;
  final String label;
  final double speed;
  final VoidCallback onBack;
  final VoidCallback onSpeed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topPad + 8,
      left: 8,
      right: 8,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSpeed,
            child: Text(
              '${speed}x',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Right-side episode list / share.
class EpisodeSideActions extends StatelessWidget {
  const EpisodeSideActions({
    super.key,
    this.onEpisodes,
    this.onShare,
  });

  final VoidCallback? onEpisodes;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 10,
      bottom: 220,
      child: Column(
        children: [
          EpisodeCircleIcon(icon: Icons.list_rounded, onTap: onEpisodes),
          const SizedBox(height: 18),
          EpisodeCircleIcon(icon: Icons.ios_share_rounded, onTap: onShare),
        ],
      ),
    );
  }
}

/// Circular icon button used by [EpisodeSideActions].
class EpisodeCircleIcon extends StatelessWidget {
  const EpisodeCircleIcon({super.key, required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

/// Bottom series / episode meta + seek bar.
class EpisodeBottomChrome extends StatelessWidget {
  const EpisodeBottomChrome({
    super.key,
    required this.title,
    required this.episodeTitle,
    required this.description,
    required this.seekController,
    this.onSeekStart,
    this.belowMeta,
  });

  final String title;
  final String episodeTitle;
  final String description;
  final VideoPlayerController? seekController;
  final VoidCallback? onSeekStart;

  /// Optional content rendered under the episode meta (above the seek bar).
  final Widget? belowMeta;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final desc = description.length > 90
        ? '${description.substring(0, 90)}…'
        : description;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 40, 16, 14 + bottom),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    episodeTitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (belowMeta != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 48),
                child: belowMeta!,
              ),
            ],
            const SizedBox(height: 10),
            PlayerSeekBar(
              controller: seekController,
              onSeekStart: onSeekStart,
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal speed picker; applies selection via [EpisodePlayerController.setSpeed].
Future<void> showEpisodeSpeedSheet(
  BuildContext context,
  EpisodePlayerController controller,
) async {
  final selected = await showModalBottomSheet<double>(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Playback speed',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            for (final s in EpisodePlaybackStrategy.speedOptions)
              ListTile(
                title: Text(
                  '${s}x',
                  style: TextStyle(
                    color: s == controller.playbackSpeed
                        ? Colors.amber
                        : Colors.white,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      );
    },
  );
  if (selected != null) {
    await controller.setSpeed(selected);
  }
}

/// Modal episode list; jumps via [EpisodePlayerScope.animateToEpisode].
Future<void> showEpisodeListSheet(BuildContext context) async {
  final scope = EpisodePlayerScope.of(context);
  final c = scope.controller;
  final selected = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    isScrollControlled: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (_, scroll) {
          return ListView.builder(
            controller: scroll,
            itemCount: c.episodes.length,
            itemBuilder: (_, i) {
              final ep = c.episodes[i];
              final active = i == c.currentIndex;
              return ListTile(
                title: Text(
                  ep.displayLabel,
                  style: TextStyle(
                    color: active ? Colors.amber : Colors.white,
                  ),
                ),
                subtitle: ep.title.isEmpty
                    ? null
                    : Text(
                        ep.title,
                        style: const TextStyle(color: Colors.white54),
                      ),
                onTap: () => Navigator.pop(ctx, i),
              );
            },
          );
        },
      );
    },
  );
  if (selected != null && selected != c.currentIndex) {
    await scope.animateToEpisode(selected);
  }
}
