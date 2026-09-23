import 'package:flutter/material.dart';
import 'package:flutter_feed_player/flutter_feed_player.dart';

import '../l10n/demo_l10n.dart';
import '../mock/mock_data.dart';
import '../widgets/player_param_panel.dart';

/// Feed demo: vertical PageView — swipe up/down to switch clips.
///
/// Pull down on the first page to refresh; pull up on the last page (or near
/// the end) to load more.
class FeedDemoPage extends StatefulWidget {
  const FeedDemoPage({
    super.key,
    this.formatFilter = MockFormatFilter.all,
    this.initialIndex = 0,
    this.params = const PlayerDemoParams(),
  });

  final MockFormatFilter formatFilter;
  final int initialIndex;
  final PlayerDemoParams params;

  @override
  State<FeedDemoPage> createState() => _FeedDemoPageState();
}

class _FeedDemoPageState extends State<FeedDemoPage> {
  static const _pageSize = 4;

  late final FeedPlayerController _controller;

  @override
  void initState() {
    super.initState();
    final p = widget.params;
    _controller = FeedPlayerController(
      loader: (page) => MockFeedData.loadPage(
        page,
        pageSize: _pageSize,
        filter: widget.formatFilter,
      ),
      pageSize: _pageSize,
      loopClips: p.loopClips,
      lockForwardWhileCold: p.lockForwardWhileCold,
      autoAdvanceOnEnd: p.autoAdvanceOnEnd,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final p = widget.params;
    return Scaffold(
      backgroundColor: Colors.black,
      body: FeedPlayerView(
        controller: _controller,
        initialIndex: widget.initialIndex,
        enableGestures: p.enableGestures,
        showBufferingIndicator: p.showBufferingIndicator,
        enablePullToRefresh: p.enablePullToRefresh,
        enablePullToLoadMore: p.enablePullToLoadMore,
        overlayBuilder: (context, slot) => _DemoFeedChrome(
          slot: slot,
          bottomInset: bottom + 8,
          onClose: () => Navigator.of(context).maybePop(),
          onShare: () {
            final l10n = DemoLocaleScope.l10nOf(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.shareMock)),
            );
          },
          onMore: () {
            final l10n = DemoLocaleScope.l10nOf(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.moreMock)),
            );
          },
        ),
      ),
    );
  }
}

class _DemoFeedChrome extends StatefulWidget {
  const _DemoFeedChrome({
    required this.slot,
    required this.bottomInset,
    required this.onClose,
    required this.onShare,
    required this.onMore,
  });

  final FeedPlayerSlot slot;
  final double bottomInset;
  final VoidCallback onClose;
  final VoidCallback onShare;
  final VoidCallback onMore;

  @override
  State<_DemoFeedChrome> createState() => _DemoFeedChromeState();
}

class _DemoFeedChromeState extends State<_DemoFeedChrome> {
  bool _scrubbing = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.slot.isActive) return const SizedBox.shrink();

    final c = widget.slot.controller;
    final item = widget.slot.item;
    final top = MediaQuery.paddingOf(context).top;
    final total = c.items.length;
    final pageLabel = total > 0
        ? '${widget.slot.index + 1}/$total${c.hasMore ? '+' : ''}'
        : '';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_scrubbing && c.showCenterPlay) const FeedCenterPlayIcon(),
        if (!_scrubbing)
          Positioned(
            top: top + 4,
            left: 4,
            child: IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        if (!_scrubbing && pageLabel.isNotEmpty)
          Positioned(
            top: top + 14,
            right: 16,
            child: IgnorePointer(
              child: Text(
                pageLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (!_scrubbing)
          FeedSideActions(
            bottomInset: widget.bottomInset,
            liked: item.isLiked,
            likeCount: item.likeCount,
            onLike: () => c.toggleLike(widget.slot.index),
            onShare: widget.onShare,
            onMore: widget.onMore,
          ),
        FeedBottomChrome(
          bottomInset: widget.bottomInset,
          title: item.title,
          description: item.description,
          tags: item.tags,
          ctaText: '',
          formatLabel: item.formatLabel,
          seekController: widget.slot.player,
          onScrubbingChanged: (v) => setState(() => _scrubbing = v),
        ),
      ],
    );
  }
}
