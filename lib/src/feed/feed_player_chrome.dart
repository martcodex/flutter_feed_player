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
class FeedPlayerChrome extends StatefulWidget {
  const FeedPlayerChrome({
    super.key,
    required this.slot,
    this.bottomInset = 0,
    this.onShare,
    this.onMore,
    this.onWatchFullSeries,
    this.showCenterPlay = true,
    this.showSideActions = true,
    this.showBottomChrome = true,
  });

  final FeedPlayerSlot slot;
  final double bottomInset;
  final ValueChanged<int>? onShare;
  final ValueChanged<int>? onMore;
  final ValueChanged<int>? onWatchFullSeries;
  final bool showCenterPlay;
  final bool showSideActions;
  final bool showBottomChrome;

  @override
  State<FeedPlayerChrome> createState() => _FeedPlayerChromeState();
}

class _FeedPlayerChromeState extends State<FeedPlayerChrome> {
  bool _scrubbing = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.slot.isActive) return const SizedBox.shrink();

    final slot = widget.slot;
    final c = slot.controller;
    final item = slot.item;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_scrubbing && widget.showCenterPlay && c.showCenterPlay)
          const FeedCenterPlayIcon(),
        if (!_scrubbing && widget.showSideActions)
          FeedSideActions(
            bottomInset: widget.bottomInset,
            liked: item.isLiked,
            likeCount: item.likeCount,
            onLike: () => c.toggleLike(slot.index),
            onShare: widget.onShare == null
                ? null
                : () => widget.onShare!(slot.index),
            onMore: widget.onMore == null
                ? null
                : () => widget.onMore!(slot.index),
          ),
        if (widget.showBottomChrome)
          FeedBottomChrome(
            bottomInset: widget.bottomInset,
            title: item.title,
            description: item.description,
            tags: item.tags,
            ctaText: item.ctaText,
            formatLabel: item.formatLabel,
            seekController: slot.player,
            onCta: widget.onWatchFullSeries == null
                ? null
                : () => widget.onWatchFullSeries!(slot.index),
            onScrubbingChanged: (v) => setState(() => _scrubbing = v),
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

/// Right-side like / share / more column.
class FeedSideActions extends StatelessWidget {
  const FeedSideActions({
    super.key,
    required this.bottomInset,
    required this.liked,
    required this.likeCount,
    required this.onLike,
    this.onShare,
    this.onMore,
  });

  final double bottomInset;
  final bool liked;
  final int likeCount;
  final VoidCallback onLike;
  final VoidCallback? onShare;
  final VoidCallback? onMore;

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
          const SizedBox(height: 20),
          FeedActionButton(
            icon: Icons.more_horiz_rounded,
            label: 'More',
            onTap: onMore,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 2),
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
///
/// While scrubbing, meta / CTA are hidden so only the seek bar + time remain.
class FeedBottomChrome extends StatefulWidget {
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
    this.onScrubbingChanged,
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
  final ValueChanged<bool>? onScrubbingChanged;

  @override
  State<FeedBottomChrome> createState() => _FeedBottomChromeState();
}

class _FeedBottomChromeState extends State<FeedBottomChrome> {
  bool _scrubbing = false;

  @override
  Widget build(BuildContext context) {
    final desc = widget.description.length > 72
        ? '${widget.description.substring(0, 72)}…'
        : widget.description;

    // Full-bleed gradient mask; meta text clears side actions; seek is equal-inset.
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          _scrubbing ? 16 : 48,
          16,
          12 + widget.bottomInset,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black87.withValues(alpha: _scrubbing ? 0.55 : 1),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_scrubbing) ...[
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(right: 56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.formatLabel != null &&
                          widget.formatLabel!.isNotEmpty) ...[
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
                            widget.formatLabel!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (widget.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: widget.tags
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
              if (widget.ctaText.isNotEmpty) ...[
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
                  onPressed: widget.onCta,
                  child: Text(widget.ctaText),
                ),
              ],
              if (widget.belowMeta != null) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 56),
                  child: widget.belowMeta!,
                ),
              ],
              const SizedBox(height: 8),
            ],
            PlayerSeekBar(
              controller: widget.seekController,
              onScrubbingChanged: (v) {
                setState(() => _scrubbing = v);
                widget.onScrubbingChanged?.call(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
