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
    this.loopClips = true,
  });

  final bool enableGestures;
  final bool showBufferingIndicator;
  final bool enablePullToRefresh;
  final bool enablePullToLoadMore;
  final bool lockForwardWhileCold;
  final bool loopClips;

  PlayerDemoParams copyWith({
    bool? enableGestures,
    bool? showBufferingIndicator,
    bool? enablePullToRefresh,
    bool? enablePullToLoadMore,
    bool? lockForwardWhileCold,
    bool? loopClips,
  }) {
    return PlayerDemoParams(
      enableGestures: enableGestures ?? this.enableGestures,
      showBufferingIndicator:
          showBufferingIndicator ?? this.showBufferingIndicator,
      enablePullToRefresh: enablePullToRefresh ?? this.enablePullToRefresh,
      enablePullToLoadMore: enablePullToLoadMore ?? this.enablePullToLoadMore,
      lockForwardWhileCold: lockForwardWhileCold ?? this.lockForwardWhileCold,
      loopClips: loopClips ?? this.loopClips,
    );
  }
}

/// Compact toggles for demo player view / controller flags.
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF17171C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.playerParams,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.playerParamsHint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ParamChip(
                label: l10n.paramGestures,
                value: params.enableGestures,
                onChanged: (v) =>
                    onChanged(params.copyWith(enableGestures: v)),
              ),
              _ParamChip(
                label: l10n.paramBuffering,
                value: params.showBufferingIndicator,
                onChanged: (v) =>
                    onChanged(params.copyWith(showBufferingIndicator: v)),
              ),
              _ParamChip(
                label: l10n.paramPullRefresh,
                value: params.enablePullToRefresh,
                onChanged: (v) =>
                    onChanged(params.copyWith(enablePullToRefresh: v)),
              ),
              _ParamChip(
                label: l10n.paramPullMore,
                value: params.enablePullToLoadMore,
                onChanged: (v) =>
                    onChanged(params.copyWith(enablePullToLoadMore: v)),
              ),
              _ParamChip(
                label: l10n.paramLockForward,
                value: params.lockForwardWhileCold,
                onChanged: (v) =>
                    onChanged(params.copyWith(lockForwardWhileCold: v)),
              ),
              _ParamChip(
                label: l10n.paramLoopFeed,
                value: params.loopClips,
                onChanged: (v) => onChanged(params.copyWith(loopClips: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParamChip extends StatelessWidget {
  const _ParamChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: value ? Colors.black : Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: value,
      onSelected: onChanged,
      selectedColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      checkmarkColor: Colors.black,
      side: BorderSide(color: Colors.white.withValues(alpha: value ? 0 : 0.2)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}
