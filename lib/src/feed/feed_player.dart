import 'package:flutter/material.dart';

import 'feed_player_chrome.dart';
import 'feed_player_controller.dart';
import 'feed_player_view.dart';

/// Batteries-included feed player: [FeedPlayerView] + [FeedPlayerChrome].
///
/// For a fully custom UI, use [FeedPlayerView] directly and supply your own
/// [FeedPlayerView.overlayBuilder].
class FeedPlayer extends StatelessWidget {
  const FeedPlayer({
    super.key,
    required this.controller,
    this.onWatchFullSeries,
    this.onShare,
    this.bottomInset = 0,
    this.overlayBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.enableGestures = true,
    this.showBufferingIndicator = true,
    this.autoInit = true,
    this.enablePullToRefresh = true,
    this.enablePullToLoadMore = true,
  });

  final FeedPlayerController controller;
  final ValueChanged<int>? onWatchFullSeries;
  final ValueChanged<int>? onShare;
  final double bottomInset;

  /// When set, replaces the default [FeedPlayerChrome] entirely.
  final FeedPlayerOverlayBuilder? overlayBuilder;

  final FeedPlayerShellBuilder? loadingBuilder;
  final FeedPlayerShellBuilder? errorBuilder;
  final bool enableGestures;
  final bool showBufferingIndicator;
  final bool autoInit;
  final bool enablePullToRefresh;
  final bool enablePullToLoadMore;

  @override
  Widget build(BuildContext context) {
    return FeedPlayerView(
      controller: controller,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      enableGestures: enableGestures,
      showBufferingIndicator: showBufferingIndicator,
      autoInit: autoInit,
      enablePullToRefresh: enablePullToRefresh,
      enablePullToLoadMore: enablePullToLoadMore,
      overlayBuilder: overlayBuilder ??
          (context, slot) => FeedPlayerChrome(
                slot: slot,
                bottomInset: bottomInset,
                onShare: onShare,
                onWatchFullSeries: onWatchFullSeries,
              ),
    );
  }
}
