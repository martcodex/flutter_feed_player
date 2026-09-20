import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pull-to-refresh / pull-up load-more for a vertical full-screen [PageView].
///
/// Detects overscroll on the first page (refresh) and last page (load more).
class VerticalPageRefresh extends StatefulWidget {
  const VerticalPageRefresh({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.itemCount,
    this.enableRefresh = true,
    this.enableLoadMore = true,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.onRefresh,
    this.onLoadMore,
    this.refreshTriggerExtent = 72,
    this.loadMoreTriggerExtent = 56,
  });

  final Widget child;
  final int currentIndex;
  final int itemCount;
  final bool enableRefresh;
  final bool enableLoadMore;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasMore;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onLoadMore;
  final double refreshTriggerExtent;
  final double loadMoreTriggerExtent;

  @override
  State<VerticalPageRefresh> createState() => _VerticalPageRefreshState();
}

class _VerticalPageRefreshState extends State<VerticalPageRefresh> {
  double _pullDown = 0;
  double _pullUp = 0;
  bool _refreshArmed = false;
  bool _loadMoreArmed = false;
  bool _refreshing = false;

  bool get _atFirst => widget.currentIndex <= 0;
  bool get _atLast =>
      widget.itemCount > 0 && widget.currentIndex >= widget.itemCount - 1;

  void _resetDrag() {
    if (_pullDown == 0 &&
        _pullUp == 0 &&
        !_refreshArmed &&
        !_loadMoreArmed) {
      return;
    }
    setState(() {
      _pullDown = 0;
      _pullUp = 0;
      _refreshArmed = false;
      _loadMoreArmed = false;
    });
  }

  Future<void> _triggerRefresh() async {
    final cb = widget.onRefresh;
    if (cb == null || _refreshing || widget.isRefreshing) {
      _resetDrag();
      return;
    }
    setState(() {
      _refreshing = true;
      _pullDown = widget.refreshTriggerExtent;
      _refreshArmed = false;
    });
    try {
      await cb();
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
        _resetDrag();
      }
    }
  }

  Future<void> _triggerLoadMore() async {
    final cb = widget.onLoadMore;
    if (cb == null ||
        widget.isLoadingMore ||
        widget.isRefreshing ||
        _refreshing ||
        !widget.hasMore) {
      _resetDrag();
      return;
    }
    setState(() {
      _pullUp = 0;
      _loadMoreArmed = false;
    });
    await cb();
    if (mounted) _resetDrag();
  }

  void _applyPullDown(double extent) {
    if (!widget.enableRefresh || !_atFirst || widget.isRefreshing || _refreshing) {
      return;
    }
    final next = math.min(widget.refreshTriggerExtent * 1.4, extent);
    setState(() {
      _pullDown = next;
      _refreshArmed = next >= widget.refreshTriggerExtent;
      _pullUp = 0;
      _loadMoreArmed = false;
    });
  }

  void _applyPullUp(double extent) {
    if (!widget.enableLoadMore ||
        !_atLast ||
        !widget.hasMore ||
        widget.isLoadingMore ||
        widget.isRefreshing ||
        _refreshing) {
      return;
    }
    final next = math.min(widget.loadMoreTriggerExtent * 1.4, extent);
    setState(() {
      _pullUp = next;
      _loadMoreArmed = next >= widget.loadMoreTriggerExtent;
      _pullDown = 0;
      _refreshArmed = false;
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;

    if (n is ScrollUpdateNotification) {
      final m = n.metrics;
      // Bouncing physics (iOS): pixels go past extents.
      if (m.pixels < m.minScrollExtent) {
        _applyPullDown(m.minScrollExtent - m.pixels);
      } else if (m.pixels > m.maxScrollExtent) {
        _applyPullUp(m.pixels - m.maxScrollExtent);
      } else if (n.dragDetails == null &&
          (_pullDown > 0 || _pullUp > 0) &&
          !widget.isRefreshing &&
          !_refreshing) {
        // Settling back without release trigger.
      }
    } else if (n is OverscrollNotification) {
      // Clamping physics (Android): overscroll deltas at edges.
      if (n.overscroll < 0) {
        _applyPullDown(_pullDown + (-n.overscroll));
      } else if (n.overscroll > 0) {
        _applyPullUp(_pullUp + n.overscroll);
      }
    } else if (n is ScrollEndNotification) {
      if (_refreshArmed && !widget.isRefreshing && !_refreshing) {
        unawaited(_triggerRefresh());
      } else if (_loadMoreArmed && !widget.isLoadingMore) {
        unawaited(_triggerLoadMore());
      } else if (!widget.isRefreshing && !_refreshing) {
        _resetDrag();
      }
    }
    return false;
  }

  @override
  void didUpdateWidget(covariant VerticalPageRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex ||
        oldWidget.itemCount != widget.itemCount) {
      _resetDrag();
    }
    if (oldWidget.isRefreshing && !widget.isRefreshing) {
      _resetDrag();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final activeRefresh = widget.isRefreshing || _refreshing;
    final showRefresh = activeRefresh || _pullDown > 8;
    final showLoadMore =
        widget.isLoadingMore || (_pullUp > 8 && widget.hasMore);

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (showRefresh)
            Positioned(
              top: topPad + 12,
              left: 0,
              right: 0,
              child: _EdgeIndicator(
                progress: activeRefresh
                    ? null
                    : (_pullDown / widget.refreshTriggerExtent).clamp(0.0, 1.0),
                armed: _refreshArmed || activeRefresh,
                label: activeRefresh
                    ? '刷新中…'
                    : (_refreshArmed ? '松开刷新' : '下拉刷新'),
              ),
            ),
          if (showLoadMore)
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 24,
              left: 0,
              right: 0,
              child: _EdgeIndicator(
                progress: widget.isLoadingMore
                    ? null
                    : (_pullUp / widget.loadMoreTriggerExtent).clamp(0.0, 1.0),
                armed: _loadMoreArmed || widget.isLoadingMore,
                label: widget.isLoadingMore
                    ? '加载中…'
                    : (_loadMoreArmed ? '松开加载更多' : '上拉加载更多'),
              ),
            ),
        ],
      ),
    );
  }
}

class _EdgeIndicator extends StatelessWidget {
  const _EdgeIndicator({
    required this.progress,
    required this.armed,
    required this.label,
  });

  /// `null` → indeterminate spinner (active refresh / load).
  final double? progress;
  final bool armed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: progress == null
                ? const CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  )
                : CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.4,
                    color: armed ? Colors.white : Colors.white54,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: armed ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
