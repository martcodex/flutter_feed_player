import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Seek bar with shimmer loading, progress thumb, and scrub time labels.
class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({
    super.key,
    required this.controller,
    this.onSeekStart,
    this.onSeekEnd,
    this.onScrubbingChanged,
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0x55FFFFFF),
    this.height = 3,
    this.scrubHeight = 8,
    this.thumbRadius = 3,
    this.scrubThumbRadius = 6.5,
  });

  final VideoPlayerController? controller;
  final VoidCallback? onSeekStart;
  final ValueChanged<Duration>? onSeekEnd;
  final ValueChanged<bool>? onScrubbingChanged;
  final Color activeColor;
  final Color inactiveColor;
  final double height;
  final double scrubHeight;
  final double thumbRadius;
  final double scrubThumbRadius;

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar>
    with SingleTickerProviderStateMixin {
  bool _scrubbing = false;
  double _scrubValue = 0;
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  void _setScrubbing(bool value) {
    if (_scrubbing == value) return;
    setState(() => _scrubbing = value);
    widget.onScrubbingChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return _buildLoadingTrack();
    }

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final durationMs = ctrl.value.duration.inMilliseconds;
        final positionMs = ctrl.value.position.inMilliseconds;
        final value = _scrubbing
            ? _scrubValue
            : (durationMs <= 0
                ? 0.0
                : (positionMs / durationMs).clamp(0.0, 1.0));
        final current = Duration(
          milliseconds: _scrubbing
              ? (durationMs * _scrubValue).round()
              : positionMs,
        );
        final total = Duration(milliseconds: durationMs);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _scrubValue = value;
            _setScrubbing(true);
            widget.onSeekStart?.call();
          },
          onHorizontalDragUpdate: (d) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final dx = d.localPosition.dx.clamp(0.0, box.size.width);
            setState(() => _scrubValue = dx / box.size.width);
          },
          onHorizontalDragEnd: (_) {
            final ms = (durationMs * _scrubValue).round();
            final target = Duration(milliseconds: ms);
            ctrl.seekTo(target);
            widget.onSeekEnd?.call(target);
            _setScrubbing(false);
          },
          onTapDown: (d) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null || durationMs <= 0) return;
            final dx = d.localPosition.dx.clamp(0.0, box.size.width);
            final v = dx / box.size.width;
            final target = Duration(milliseconds: (durationMs * v).round());
            ctrl.seekTo(target);
            widget.onSeekEnd?.call(target);
          },
          child: _buildProgressTrack(
            value: value,
            scrubbing: _scrubbing,
            current: current,
            total: total,
          ),
        );
      },
    );
  }

  /// Shared outer slot so loading shimmer and progress share the same position.
  static const double _slotHeight = 24;

  Widget _buildLoadingTrack() {
    return SizedBox(
      height: _slotHeight,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _shimmer,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ShimmerTrackPainter(
                    progress: _shimmer.value,
                    baseColor: widget.inactiveColor,
                    highlightColor: widget.activeColor,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressTrack({
    required double value,
    required bool scrubbing,
    required Duration current,
    required Duration total,
  }) {
    final h = scrubbing ? widget.scrubHeight : widget.height;
    final thumbR = scrubbing ? widget.scrubThumbRadius : widget.thumbRadius;
    final v = value.clamp(0.0, 1.0);

    return SizedBox(
      height: _slotHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (scrubbing)
            Positioned(
              bottom: _slotHeight + 10,
              child: Text(
                '${_formatDuration(current)} / ${_formatDuration(total)}',
                style: TextStyle(
                  color: widget.activeColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  letterSpacing: 0.4,
                  shadows: const [
                    Shadow(
                      color: Color(0x99000000),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final trackW = constraints.maxWidth;
              final thumbX = (trackW * v).clamp(thumbR, trackW - thumbR);
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: SizedBox(
                        height: h,
                        width: trackW,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(color: widget.inactiveColor),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: v,
                              child: ColoredBox(color: widget.activeColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: thumbX - thumbR,
                    top: (_slotHeight - thumbR * 2) / 2,
                    child: Container(
                      width: thumbR * 2,
                      height: thumbR * 2,
                      decoration: BoxDecoration(
                        color: widget.activeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final h = d.inHours.toString().padLeft(2, '0');
      final mm = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      return '$h:$mm:$s';
    }
    return '$m:$s';
  }
}

/// Flowing shimmer (流光) fill across an inactive track.
class _ShimmerTrackPainter extends CustomPainter {
  _ShimmerTrackPainter({
    required this.progress,
    required this.baseColor,
    required this.highlightColor,
  });

  final double progress;
  final Color baseColor;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(99),
    );
    canvas.drawRRect(rrect, Paint()..color = baseColor);

    final bandW = size.width * 0.45;
    final start = -bandW + (size.width + bandW * 2) * progress;
    final rect = Rect.fromLTWH(start, 0, bandW, size.height);
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        highlightColor.withValues(alpha: 0.0),
        highlightColor.withValues(alpha: 0.55),
        highlightColor.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(rect);

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShimmerTrackPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.highlightColor != highlightColor;
  }
}
