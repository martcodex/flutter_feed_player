import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/playable_models.dart';
import '../widgets/lock_forward_page_physics.dart';
import '../widgets/player_surface.dart';
import '../widgets/vertical_page_refresh.dart';
import 'feed_player_controller.dart';

/// Per-page context for custom overlays on [FeedPlayerView].
class FeedPlayerSlot {
  const FeedPlayerSlot({
    required this.index,
    required this.item,
    required this.itemKey,
    required this.controller,
    required this.player,
    required this.isActive,
  });

  final int index;
  final FeedItem item;
  final String itemKey;
  final FeedPlayerController controller;
  final VideoPlayerController? player;
  final bool isActive;
}

/// Builds chrome / overlays on top of the video surface for one feed page.
typedef FeedPlayerOverlayBuilder = Widget Function(
  BuildContext context,
  FeedPlayerSlot slot,
);

/// Builds the empty / loading / error shell (full screen, no pages yet).
typedef FeedPlayerShellBuilder = Widget Function(
  BuildContext context,
  FeedPlayerController controller,
);

/// Headless vertical feed shell: [PageView] + [PlayerSurface] + gestures.
///
/// UI chrome is **not** baked in — supply [overlayBuilder] (and optionally
/// shell builders) to compose any components you want.
class FeedPlayerView extends StatefulWidget {
  const FeedPlayerView({
    super.key,
    required this.controller,
    this.overlayBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.enableGestures = true,
    this.showBufferingIndicator = true,
    this.autoInit = true,
    this.initialIndex = 0,
    this.enablePullToRefresh = true,
    this.enablePullToLoadMore = true,
  });

  final FeedPlayerController controller;

  /// Stacked above the surface for each page. Return [SizedBox.shrink] to skip.
  final FeedPlayerOverlayBuilder? overlayBuilder;

  /// Shown while [FeedPlayerController.loading] and items are empty.
  final FeedPlayerShellBuilder? loadingBuilder;

  /// Shown when [FeedPlayerController.errorMessage] is set and items are empty.
  final FeedPlayerShellBuilder? errorBuilder;

  /// Tap = play/pause, long-press = 2× boost (active page only).
  final bool enableGestures;

  /// Center spinner while the active page waits for the first frame.
  final bool showBufferingIndicator;

  /// Call [FeedPlayerController.init] on first frame.
  final bool autoInit;

  /// Start page after the first feed load (clamped to item count).
  final int initialIndex;

  /// Pull down on the first page to call [FeedPlayerController.refresh].
  final bool enablePullToRefresh;

  /// Pull up on the last page to call [FeedPlayerController.loadMore].
  final bool enablePullToLoadMore;

  @override
  State<FeedPlayerView> createState() => FeedPlayerViewState();
}

class FeedPlayerViewState extends State<FeedPlayerView> {
  late final PageController pageController;
  bool _started = false;
  bool _didJumpInitial = false;

  FeedPlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    final start = widget.initialIndex < 0 ? 0 : widget.initialIndex;
    pageController = PageController(initialPage: start);
    controller.addListener(_onCtrl);
    if (widget.autoInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_started) return;
        _started = true;
        await controller.init();
        await _jumpToInitialIfNeeded();
      });
    }
  }

  Future<void> _jumpToInitialIfNeeded() async {
    if (_didJumpInitial || !mounted) return;
    final target = widget.initialIndex;
    if (target <= 0) {
      _didJumpInitial = true;
      return;
    }
    if (controller.items.isEmpty) return;
    final index = target.clamp(0, controller.items.length - 1);
    _didJumpInitial = true;
    if (index == 0) return;
    if (pageController.hasClients) {
      pageController.jumpToPage(index);
    }
    await controller.onPageChanged(index);
  }

  void _onCtrl() {
    if (mounted) setState(() {});
    if (!_didJumpInitial && controller.items.isNotEmpty) {
      unawaited(_jumpToInitialIfNeeded());
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onCtrl);
    pageController.dispose();
    super.dispose();
  }

  /// Programmatic page jump (e.g. from a custom overlay).
  Future<void> animateToPage(
    int index, {
    Duration duration = const Duration(milliseconds: 280),
    Curve curve = Curves.easeOut,
  }) {
    if (!pageController.hasClients) return Future.value();
    return pageController.animateToPage(
      index,
      duration: duration,
      curve: curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;

    if (c.loading && c.items.isEmpty) {
      return widget.loadingBuilder?.call(context, c) ??
          const _DefaultLoadingShell();
    }
    if (c.errorMessage != null && c.items.isEmpty) {
      return widget.errorBuilder?.call(context, c) ??
          _DefaultErrorShell(
            message: c.errorMessage!,
            onRetry: c.refresh,
          );
    }

    final refreshing = c.loading && c.items.isNotEmpty;

    return ColoredBox(
      color: Colors.black,
      child: FeedPlayerScope(
        viewState: this,
        child: VerticalPageRefresh(
          currentIndex: c.currentIndex,
          itemCount: c.items.length,
          enableRefresh: widget.enablePullToRefresh,
          enableLoadMore: widget.enablePullToLoadMore,
          isRefreshing: refreshing,
          isLoadingMore: c.loadingMore,
          hasMore: c.hasMore,
          onRefresh: () async {
            await c.refresh();
            if (!mounted) return;
            if (pageController.hasClients) {
              pageController.jumpToPage(0);
            }
          },
          onLoadMore: c.loadMore,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollUpdateNotification &&
                  n.metrics.axis == Axis.vertical &&
                  n.scrollDelta != null &&
                  n.scrollDelta! > 0) {
                c.onForwardSwipeIntent();
              }
              return false;
            },
            child: PageView.builder(
              controller: pageController,
              scrollDirection: Axis.vertical,
              allowImplicitScrolling: true,
              physics: _feedScrollPhysics(c.locksForwardSwipe),
              itemCount: c.items.length,
              onPageChanged: c.onPageChanged,
              itemBuilder: (context, index) {
                final item = c.items[index];
                final key = c.itemKey(item, index);
                final isActive = index == c.currentIndex;
                final display = c.displayPlayerFor(key);
                final slot = FeedPlayerSlot(
                  index: index,
                  item: item,
                  itemKey: key,
                  controller: c,
                  player: display,
                  isActive: isActive,
                );

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    PlayerSurface(
                      key: ValueKey('feed_surface_$key-${c.parkedVersion}'),
                      controller: display,
                    ),
                    if (isActive &&
                        widget.showBufferingIndicator &&
                        !c.videoFrameReady &&
                        !c.hasPlaybackError)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.white54),
                      ),
                    if (isActive &&
                        (c.hasPlaybackError || c.showLoadingPrompt))
                      _PlaybackRetryOverlay(
                        message: c.hasPlaybackError
                            ? (c.errorMessage ?? 'Playback failed')
                            : 'Taking longer than usual…',
                        onRetry: c.retryPlayback,
                      ),
                    if (isActive && widget.enableGestures)
                      const Positioned.fill(child: _FeedGestureLayer()),
                    if (widget.overlayBuilder != null)
                      widget.overlayBuilder!(context, slot),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

ScrollPhysics _feedScrollPhysics(bool lockForward) {
  final page = lockForward
      ? const LockForwardPagePhysics(lockForward: true)
      : const PageScrollPhysics();
  // Bouncing edges so pull-to-refresh / load-more overscroll works on Android too.
  return BouncingScrollPhysics(parent: page);
}

/// Access [FeedPlayerViewState] / controller from descendant overlays.
class FeedPlayerScope extends InheritedWidget {
  const FeedPlayerScope({
    super.key,
    required this.viewState,
    required super.child,
  });

  final FeedPlayerViewState viewState;

  FeedPlayerController get controller => viewState.controller;

  static FeedPlayerScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<FeedPlayerScope>();
    assert(scope != null, 'FeedPlayerScope not found in context');
    return scope!;
  }

  static FeedPlayerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FeedPlayerScope>();
  }

  @override
  bool updateShouldNotify(FeedPlayerScope oldWidget) =>
      viewState != oldWidget.viewState;
}

class _FeedGestureLayer extends StatelessWidget {
  const _FeedGestureLayer();

  @override
  Widget build(BuildContext context) {
    final c = FeedPlayerScope.of(context).controller;
    // translucent: let vertical drags reach PageView for page switching.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: c.togglePlayPause,
      onLongPressStart: (_) => c.setBoosting(true),
      onLongPressEnd: (_) => c.setBoosting(false),
      child: const SizedBox.expand(),
    );
  }
}

class _DefaultLoadingShell extends StatelessWidget {
  const _DefaultLoadingShell();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

class _DefaultErrorShell extends StatelessWidget {
  const _DefaultErrorShell({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaybackRetryOverlay extends StatelessWidget {
  const _PlaybackRetryOverlay({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black45,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
