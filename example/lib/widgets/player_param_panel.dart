import 'package:flutter/material.dart';

import '../l10n/demo_l10n.dart';

/// Demo player flags configured on the home page and passed into player pages.
class PlayerDemoParams {
  const PlayerDemoParams({
    this.enableGestures = true,
    this.showBufferingIndicator = true,
    this.enablePullToRefresh = true,
    this.enablePullToLoadMore = true,
    this.lockForwardWhileCold = false,
    this.loopClips = false,
    this.autoAdvanceOnEnd = true,
  });

  final bool enableGestures;
  final bool showBufferingIndicator;
  final bool enablePullToRefresh;
  final bool enablePullToLoadMore;
  final bool lockForwardWhileCold;
  final bool loopClips;

  /// After a clip / episode ends, slide to and play the next one.
  final bool autoAdvanceOnEnd;

  PlayerDemoParams copyWith({
    bool? enableGestures,
    bool? showBufferingIndicator,
    bool? enablePullToRefresh,
    bool? enablePullToLoadMore,
    bool? lockForwardWhileCold,
    bool? loopClips,
    bool? autoAdvanceOnEnd,
  }) {
    return PlayerDemoParams(
      enableGestures: enableGestures ?? this.enableGestures,
      showBufferingIndicator:
          showBufferingIndicator ?? this.showBufferingIndicator,
      enablePullToRefresh: enablePullToRefresh ?? this.enablePullToRefresh,
      enablePullToLoadMore: enablePullToLoadMore ?? this.enablePullToLoadMore,
      lockForwardWhileCold: lockForwardWhileCold ?? this.lockForwardWhileCold,
      loopClips: loopClips ?? this.loopClips,
      autoAdvanceOnEnd: autoAdvanceOnEnd ?? this.autoAdvanceOnEnd,
    );
  }
}

/// Grouped switch list for demo player view / controller flags.
class PlayerParamPanel extends StatelessWidget {
  const PlayerParamPanel({
    super.key,
    required this.params,
    required this.onChanged,
  });

  final PlayerDemoParams params;
  final ValueChanged<PlayerDemoParams> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = DemoLocaleScope.l10nOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.playerParams,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.playerParamsHint,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            height: 1.4,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        _ParamGroupCard(
          title: l10n.paramGroupInteraction,
          children: [
            _ParamSwitchTile(
              title: l10n.paramGestures,
              subtitle: l10n.paramGesturesHint,
              value: params.enableGestures,
              onChanged: (v) =>
                  onChanged(params.copyWith(enableGestures: v)),
            ),
            _ParamSwitchTile(
              title: l10n.paramBuffering,
              subtitle: l10n.paramBufferingHint,
              value: params.showBufferingIndicator,
              onChanged: (v) =>
                  onChanged(params.copyWith(showBufferingIndicator: v)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ParamGroupCard(
          title: l10n.paramGroupFeed,
          children: [
            _ParamSwitchTile(
              title: l10n.paramPullRefresh,
              subtitle: l10n.paramPullRefreshHint,
              value: params.enablePullToRefresh,
              onChanged: (v) =>
                  onChanged(params.copyWith(enablePullToRefresh: v)),
            ),
            _ParamSwitchTile(
              title: l10n.paramPullMore,
              subtitle: l10n.paramPullMoreHint,
              value: params.enablePullToLoadMore,
              onChanged: (v) =>
                  onChanged(params.copyWith(enablePullToLoadMore: v)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ParamGroupCard(
          title: l10n.paramGroupPlayback,
          children: [
            _ParamSwitchTile(
              title: l10n.paramLockForward,
              subtitle: l10n.paramLockForwardHint,
              value: params.lockForwardWhileCold,
              onChanged: (v) =>
                  onChanged(params.copyWith(lockForwardWhileCold: v)),
            ),
            _ParamSwitchTile(
              title: l10n.paramLoopFeed,
              subtitle: l10n.paramLoopFeedHint,
              value: params.loopClips,
              onChanged: (v) => onChanged(
                params.copyWith(
                  loopClips: v,
                  autoAdvanceOnEnd: v ? false : params.autoAdvanceOnEnd,
                ),
              ),
            ),
            _ParamSwitchTile(
              title: l10n.paramAutoAdvance,
              subtitle: l10n.paramAutoAdvanceHint,
              value: params.autoAdvanceOnEnd,
              onChanged: (v) => onChanged(
                params.copyWith(
                  autoAdvanceOnEnd: v,
                  loopClips: v ? false : params.loopClips,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ParamGroupCard extends StatelessWidget {
  const _ParamGroupCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF17171C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ParamSwitchTile extends StatelessWidget {
  const _ParamSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.42),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
