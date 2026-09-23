import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/playable_models.dart';
import '../widgets/lock_forward_page_physics.dart';
import '../widgets/player_surface.dart';
import '../widgets/vertical_page_refresh.dart';
import 'episode_player_controller.dart';

/// Per-page context for custom overlays on [EpisodePlayerView].
class EpisodePlayerSlot {
  const EpisodePlayerSlot({
    required this.index,
    required this.episode,
    required this.episodeId,
    required this.controller,
    required this.player,
    required this.isActive,
    required this.series,
  });

  final int index;
  final EpisodeItem episode;
  final String episodeId;
  final EpisodePlayerController controller;
  final VideoPlayerController? player;
  final bool isActive;
  final SeriesInfo series;
}

/// Builds chrome / overlays on top of the video surface for one episode page.
typedef EpisodePlayerOverlayBuilder = Widget Function(
  BuildContext context,
  EpisodePlayerSlot slot,
);

/// Builds the empty / loading / error shell (full screen, no pages yet).
typedef EpisodePlayerShellBuilder = Widget Function(
  BuildContext context,
  EpisodePlayerController controller,
);

/// Headless vertical episode shell: [PageView] + [PlayerSurface] + gestures.
///
/// UI chrome is **not** baked in — supply [overlayBuilder] to compose any
/// components. Use [EpisodePlayerScope] from overlays to jump pages.
class EpisodePlayerView extends StatefulWidget {
  const EpisodePlayerView({
    super.key,
    required this.controller,
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
  final EpisodePlayerOverlayBuilder? overlayBuilder;
  final EpisodePlayerShellBuilder? loadingBuilder;
  final EpisodePlayerShellBuilder? errorBuilder;
  final bool enableGestures;
  final bool showBufferingIndicator;
  final bool autoInit;

  /// Pull down on the first episode to call [EpisodePlayerController.refresh].
  final bool enablePullToRefresh;

  /// Pull up on the last episode to call [EpisodePlayerController.loadMore].
  final bool enablePullToLoadMore;

  @override
  State<EpisodePlayerView> createState() => EpisodePlayerViewState();
}

class EpisodePlayerViewState extends State<EpisodePlayerView> {
  PageController? pageController;
  bool _started = false;
  int _boundRevision = -1;

  EpisodePlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.animateToIndex = (index) => animateToEpisode(index);
    controller.addListener(_onCtrl);
    if (widget.autoInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_started) return;
        _started = true;
        await controller.init();
        if (!mounted) return;
        _ensurePageController(force: true);
      });
    }
  }

  void _ensurePageController({bool force = false}) {
    final c = controller;
    if (c.episodes.isEmpty) return;
    final revision = c.episodeRevision;
    if (!force &&
        pageController != null &&
        _boundRevision == revision) {
      return;
    }
    pageController?.dispose();
    pageController = PageController(initialPage: c.currentIndex);
    _boundRevision = revision;
    setState(() {});
  }

  void _onCtrl() {
    if (!mounted) return;
    final c = controller;
    if (pageController == null && c.episodes.isNotEmpty && !c.loading) {
      _ensurePageController(force: true);
      return;
    }
    // After refresh, rebuild PageController at the new start index.
    if (pageController != null &&
        c.episodeRevision != _boundRevision &&
        !c.loading &&
        c.episodes.isNotEmpty) {
      _ensurePageController(force: true);
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    controller.animateToIndex = null;
    controller.removeListener(_onCtrl);
    pageController?.dispose();
    super.dispose();
  }

  /// Programmatic episode jump (e.g. from a custom episode list sheet).
  Future<void> animateToEpisode(
    int index, {
    Duration duration = const Duration(milliseconds: 280),
    Curve curve = Curves.easeOut,
  }) async {
    var pc = pageController;
    if (pc == null) return;
    if (!pc.hasClients) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      pc = pageController;
      if (pc == null || !pc.hasClients) return;
    }
    await pc.animateToPage(index, duration: duration, curve: curve);
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;

    if ((c.loading && c.episodes.isEmpty) || pageController == null) {
      return widget.loadingBuilder?.call(context, c) ??
          const _DefaultLoadingShell();
    }
    if (c.errorMessage != null && c.episodes.isEmpty) {
      return widget.errorBuilder?.call(context, c) ??
          _DefaultErrorShell(
            message: c.errorMessage!,
            onRetry: c.refresh,
          );
    }

    final series = c.series!;
    final refreshing = c.loading && c.episodes.isNotEmpty;

    return ColoredBox(
      color: Colors.black,
      child: EpisodePlayerScope(
        viewState: this,
        child: VerticalPageRefresh(
          currentIndex: c.currentIndex,
          itemCount: c.episodes.length,
          enableRefresh: widget.enablePullToRefresh,
          enableLoadMore: widget.enablePullToLoadMore,
          isRefreshing: refreshing,
          isLoadingMore: c.loadingMore,
          hasMore: c.hasMore,
          onRefresh: () async {
            await c.refresh();
            if (!mounted) return;
            _ensurePageController(force: true);
          },
          onLoadMore: c.loadMore,
          child: PageView.builder(
            controller: pageController,
            scrollDirection: Axis.vertical,
            allowImplicitScrolling: true,
            physics: _episodeScrollPhysics(c.locksForwardSwipe),
            itemCount: c.episodes.length,
            onPageChanged: c.onEpisodePageChanged,
            itemBuilder: (context, index) {
              final ep = c.episodes[index];
              final episodeId =
                  ep.episodeId.isNotEmpty ? ep.episodeId : 'ep_$index';
              final isActive = index == c.currentIndex;
              final display = c.displayPlayerFor(episodeId);
              final slot = EpisodePlayerSlot(
                index: index,
                episode: ep,
                episodeId: episodeId,
                controller: c,
                player: display,
                isActive: isActive,
                series: series,
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  PlayerSurface(
                    key: ValueKey(
                      'ep_surface_$episodeId-${c.parkedVersion}',
                    ),
                    controller: display,
                  ),
                  if (isActive &&
                      widget.showBufferingIndicator &&
                      !c.videoFrameReady &&
                      !c.hasPlaybackError)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: Colors.white54,
                          ),
                          if (c.showLoadingPrompt) ...[
                            const SizedBox(height: 14),
                            const Text(
                              'Taking longer than usual…',
                              style: TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (isActive && c.hasPlaybackError)
                    _EpisodeRetryOverlay(
                      message: c.errorMessage ?? 'Playback failed',
                      onRetry: c.retryPlayback,
                    ),
                  if (isActive && widget.enableGestures)
                    const Positioned.fill(child: _EpisodeGestureLayer()),
                  if (widget.overlayBuilder != null)
                    widget.overlayBuilder!(context, slot),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

ScrollPhysics _episodeScrollPhysics(bool lockForward) {
  final page = lockForward
      ? const LockForwardPagePhysics(lockForward: true)
      : const PageScrollPhysics();
  return BouncingScrollPhysics(parent: page);
}

/// Access [EpisodePlayerViewState] / controller from descendant overlays.
class EpisodePlayerScope extends InheritedWidget {
  const EpisodePlayerScope({
    super.key,
    required this.viewState,
    required super.child,
  });

  final EpisodePlayerViewState viewState;

  EpisodePlayerController get controller => viewState.controller;

  Future<void> animateToEpisode(int index) =>
      viewState.animateToEpisode(index);

  static EpisodePlayerScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<EpisodePlayerScope>();
    assert(scope != null, 'EpisodePlayerScope not found in context');
    return scope!;
  }

  static EpisodePlayerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<EpisodePlayerScope>();
  }

  @override
  bool updateShouldNotify(EpisodePlayerScope oldWidget) =>
      viewState != oldWidget.viewState;
}

class _EpisodeGestureLayer extends StatelessWidget {
  const _EpisodeGestureLayer();

  @override
  Widget build(BuildContext context) {
    final c = EpisodePlayerScope.of(context).controller;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Tap reveals / hides chrome (incl. center play/pause).
        c.toggleChrome();
      },
      onDoubleTapDown: (d) {
        final w = MediaQuery.sizeOf(context).width;
        if (d.localPosition.dx < w / 2) {
          c.seekBy(const Duration(seconds: -10));
        } else {
          c.seekBy(const Duration(seconds: 10));
        }
        c.revealChrome();
      },
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

class _EpisodeRetryOverlay extends StatelessWidget {
  const _EpisodeRetryOverlay({
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
