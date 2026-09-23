import 'package:flutter/material.dart';
import 'package:flutter_feed_player/flutter_feed_player.dart';

import '../l10n/demo_l10n.dart';
import '../mock/mock_data.dart';
import '../widgets/player_param_panel.dart';

/// Episode demo: [EpisodePlayerView] + composed chrome.
///
/// Pull down on EP.1 to refresh; pull up on the last loaded episode to fetch
/// the next page.
class EpisodeDemoPage extends StatefulWidget {
  const EpisodeDemoPage({
    super.key,
    this.formatFilter = MockFormatFilter.all,
    this.params = const PlayerDemoParams(),
  });

  final MockFormatFilter formatFilter;
  final PlayerDemoParams params;

  @override
  State<EpisodeDemoPage> createState() => _EpisodeDemoPageState();
}

class _EpisodeDemoPageState extends State<EpisodeDemoPage> {
  static const _pageSize = 4;

  late final EpisodePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EpisodePlayerController(
      loader: (page) => MockSeriesData.loadOceanSeriesPage(
        page,
        pageSize: _pageSize,
        filter: widget.formatFilter,
      ),
      pageSize: _pageSize,
      initialEpisodeNo: 1,
      lockForwardWhileCold: widget.params.lockForwardWhileCold,
      autoAdvanceOnEnd: widget.params.autoAdvanceOnEnd,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.params;
    return Scaffold(
      backgroundColor: Colors.black,
      body: EpisodePlayerView(
        controller: _controller,
        enableGestures: p.enableGestures,
        showBufferingIndicator: p.showBufferingIndicator,
        enablePullToRefresh: p.enablePullToRefresh,
        enablePullToLoadMore: p.enablePullToLoadMore,
        overlayBuilder: (context, slot) => _DemoEpisodeChrome(
          slot: slot,
          onBack: () => Navigator.of(context).maybePop(),
          onShare: () {
            final l10n = DemoLocaleScope.l10nOf(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.shareMock)),
            );
          },
        ),
      ),
    );
  }
}

class _DemoEpisodeChrome extends StatefulWidget {
  const _DemoEpisodeChrome({
    required this.slot,
    required this.onBack,
    required this.onShare,
  });

  final EpisodePlayerSlot slot;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  State<_DemoEpisodeChrome> createState() => _DemoEpisodeChromeState();
}

class _DemoEpisodeChromeState extends State<_DemoEpisodeChrome> {
  bool _scrubbing = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.slot.isActive) return const SizedBox.shrink();

    final c = widget.slot.controller;
    final ep = widget.slot.episode;
    final series = widget.slot.series;
    final topPad = MediaQuery.paddingOf(context).top;
    final total = c.episodes.length;
    final pageLabel = total > 0
        ? '${widget.slot.index + 1}/$total${c.hasMore ? '+' : ''}'
        : '';
    final showUi = c.showChrome && !_scrubbing;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!c.showChrome && !_scrubbing && c.showCenterPlay)
          EpisodeCenterControl(
            isPlaying: false,
            onPressed: c.togglePlayPause,
          ),
        AnimatedOpacity(
          opacity: showUi ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !showUi,
            child: Stack(
              children: [
                EpisodeCenterControl(
                  isPlaying: c.isPlaying,
                  onPressed: c.togglePlayPause,
                ),
                EpisodeTopBar(
                  topPad: topPad,
                  label: pageLabel.isNotEmpty
                      ? '${ep.displayLabel} · $pageLabel'
                      : ep.displayLabel,
                  speed: c.playbackSpeed,
                  onBack: widget.onBack,
                  onSpeed: () => showEpisodeSpeedSheet(context, c),
                ),
                EpisodeSideActions(
                  onEpisodes: () => showEpisodeListSheet(context),
                  onShare: widget.onShare,
                ),
              ],
            ),
          ),
        ),
        if (c.showChrome || _scrubbing)
          EpisodeBottomChrome(
            title: series.title,
            episodeTitle: ep.title.isNotEmpty ? ep.title : ep.displayLabel,
            description: ep.description.isNotEmpty
                ? ep.description
                : series.description,
            seekController: widget.slot.player,
            onSeekStart: c.revealChrome,
            onScrubbingChanged: (v) => setState(() => _scrubbing = v),
          ),
        if (c.isBoosting && !_scrubbing) const EpisodeBoostBadge(),
      ],
    );
  }
}
