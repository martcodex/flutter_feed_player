import 'package:flutter/material.dart';

import 'episode_player_chrome.dart';
import 'episode_player_controller.dart';
import 'episode_player_view.dart';

/// Batteries-included episode player: [EpisodePlayerView] + [EpisodePlayerChrome].
///
/// For a fully custom UI, use [EpisodePlayerView] directly and supply your own
/// [EpisodePlayerView.overlayBuilder].
class EpisodePlayer extends StatelessWidget {
  const EpisodePlayer({
    super.key,
    required this.controller,
    this.onBack,
    this.onShare,
    this.onOpenEpisodeList,
    this.overlayBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.enableGestures = true,
    this.showBufferingIndicator = true,
    this.autoInit = true,
    this.enablePullToRefresh = true,
    this.enablePullToLoadMore = true,
  });

  final EpisodePlayerController controller;
  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final VoidCallback? onOpenEpisodeList;

  /// When set, replaces the default [EpisodePlayerChrome] entirely.
  final EpisodePlayerOverlayBuilder? overlayBuilder;

  final EpisodePlayerShellBuilder? loadingBuilder;
  final EpisodePlayerShellBuilder? errorBuilder;
  final bool enableGestures;
  final bool showBufferingIndicator;
  final bool autoInit;
  final bool enablePullToRefresh;
  final bool enablePullToLoadMore;

  @override
  Widget build(BuildContext context) {
    return EpisodePlayerView(
      controller: controller,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      enableGestures: enableGestures,
      showBufferingIndicator: showBufferingIndicator,
      autoInit: autoInit,
      enablePullToRefresh: enablePullToRefresh,
      enablePullToLoadMore: enablePullToLoadMore,
      overlayBuilder: overlayBuilder ??
          (context, slot) => EpisodePlayerChrome(
                slot: slot,
                onBack: onBack,
                onShare: onShare,
                onOpenEpisodeList: onOpenEpisodeList,
              ),
    );
  }
}
