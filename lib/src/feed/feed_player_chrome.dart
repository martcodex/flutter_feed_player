import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../widgets/player_seek_bar.dart';
import 'feed_player_view.dart';

/// Default feed chrome stack: center play + side actions + bottom meta/seek.
///
/// Compose freely, or pass as [FeedPlayerView.overlayBuilder]:
/// ```dart
/// overlayBuilder: (context, slot) => FeedPlayerChrome(slot: slot, ...)
/// ```
class FeedPlayerChrome extends StatelessWidget {
  const FeedPlayerChrome({
    super.key,
    required this.slot,
    this.bottomInset = 0,
    this.onShare,
    this.onWatchFullSeries,
    this.showCenterPlay = true,
    this.showSideActions = true,
    this.showBottomChrome = true,
  });

  final FeedPlayerSlot slot;
  final double bottomInset;
  final ValueChanged<int>? onShare;
  final ValueChanged<int>? onWatchFullSeries;
  final bool showCenterPlay;
  final bool showSideActions;
  final bool showBottomChrome;

  @override
  Widget build(BuildContext context) {
    if (!slot.isActive) return const SizedBox.shrink();

    final c = slot.controller;
    final item = slot.item;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showCenterPlay && c.showCenterPlay)
          const FeedCenterPlayIcon(),
        if (showSideActions)
          FeedSideActions(
            bottomInset: bottomInset,
            liked: item.isLiked,
            likeCount: item.likeCount,
            onLike: () => c.toggleLike(slot.index),
            onShare: onShare == null ? null : () => onShare!(slot.index),
          ),
        if (showBottomChrome)
          FeedBottomChrome(
            bottomInset: bottomInset,
            title: item.title,
            description: item.description,
            tags: item.tags,
            ctaText: item.ctaText,
            formatLabel: item.formatLabel,
            seekController: slot.player,
            onCta: onWatchFullSeries == null
                ? null
                : () => onWatchFullSeries!(slot.index),
          ),
      ],
    );
  }
}

/// Large center play glyph (non-interactive).
class FeedCenterPlayIcon extends StatelessWidget {
  const FeedCenterPlayIcon({
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

/// Right-side like / share column.
class FeedSideActions extends StatelessWidget {
  const FeedSideActions({
    super.key,
    required this.bottomInset,
    required this.liked,
    required this.likeCount,
    required this.onLike,
    this.onShare,
  });

  final double bottomInset;
  final bool liked;
  final int likeCount;
  final VoidCallback onLike;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 14,
      bottom: bottomInset + 200,
      child: Column(
        children: [
          FeedActionButton(
            icon: liked ? Icons.favorite : Icons.favorite_border,
            color: liked ? Colors.redAccent : Colors.white,
            label: formatCount(likeCount),
            onTap: onLike,
          ),
          const SizedBox(height: 20),
          FeedActionButton(
            icon: Icons.ios_share_rounded,
            label: 'Share',
            onTap: onShare,
          ),
        ],
      ),
    );
  }

  /// Formats like counts as `1.2K` / `3.4M`.
  static String formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

/// Circular icon + label used by [FeedSideActions].
class FeedActionButton extends StatelessWidget {
  const FeedActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.color = Colors.white,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Bottom title / tags / CTA / seek bar.
class FeedBottomChrome extends StatelessWidget {
  const FeedBottomChrome({
    super.key,
    required this.bottomInset,
    required this.title,
    required this.description,
    required this.tags,
    required this.ctaText,
    required this.seekController,
    this.formatLabel,
    this.onCta,
    this.belowMeta,
  });

  final double bottomInset;
  final String title;
  final String description;
  final List<String> tags;
  final String ctaText;
  final VideoPlayerController? seekController;
  final String? formatLabel;
  final VoidCallback? onCta;

  /// Optional content rendered under the item meta (above the seek bar).
  final Widget? belowMeta;

  @override
  Widget build(BuildContext context) {
    final desc = description.length > 72
        ? '${description.substring(0, 72)}…'
        : description;

    // Full-bleed gradient mask; meta text clears side actions; seek is equal-inset.
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 48, 16, 12 + bottomInset),
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
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.only(right: 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (formatLabel != null && formatLabel!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          formatLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: tags
                            .take(3)
                            .map(
                              (t) => Text(
                                '#$t',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        desc,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (ctaText.isNotEmpty) ...[
              const SizedBox(height: 10),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onCta,
                child: Text(ctaText),
              ),
            ],
            if (belowMeta != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 56),
                child: belowMeta!,
              ),
            ],
            const SizedBox(height: 8),
            PlayerSeekBar(controller: seekController),
          ],
        ),
      ),
    );
  }
}
