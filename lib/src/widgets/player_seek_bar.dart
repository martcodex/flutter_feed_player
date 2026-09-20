import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Minimal seek bar with scrub drag support.
class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({
    super.key,
    required this.controller,
    this.onSeekStart,
    this.onSeekEnd,
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0x55FFFFFF),
    this.height = 6,
    this.scrubHeight = 15,
  });

  final VideoPlayerController? controller;
  final VoidCallback? onSeekStart;
  final ValueChanged<Duration>? onSeekEnd;
  final Color activeColor;
  final Color inactiveColor;
  final double height;
  final double scrubHeight;

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  bool _scrubbing = false;
  double _scrubValue = 0;

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return _track(0, loading: true);
    }

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final duration = ctrl.value.duration.inMilliseconds;
        final position = ctrl.value.position.inMilliseconds;
        final value = _scrubbing
            ? _scrubValue
            : (duration <= 0 ? 0.0 : (position / duration).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _scrubbing = true;
            widget.onSeekStart?.call();
          },
          onHorizontalDragUpdate: (d) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final dx = d.localPosition.dx.clamp(0.0, box.size.width);
            setState(() => _scrubValue = dx / box.size.width);
          },
          onHorizontalDragEnd: (_) {
            final ms = (duration * _scrubValue).round();
            final target = Duration(milliseconds: ms);
            ctrl.seekTo(target);
            widget.onSeekEnd?.call(target);
            setState(() => _scrubbing = false);
          },
          onTapDown: (d) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null || duration <= 0) return;
            final dx = d.localPosition.dx.clamp(0.0, box.size.width);
            final v = dx / box.size.width;
            final target = Duration(milliseconds: (duration * v).round());
            ctrl.seekTo(target);
            widget.onSeekEnd?.call(target);
          },
          child: _track(value, scrubbing: _scrubbing),
        );
      },
    );
  }

  Widget _track(double value, {bool scrubbing = false, bool loading = false}) {
    final h = scrubbing ? widget.scrubHeight : widget.height;
    return SizedBox(
      height: 24,
      child: Center(
        child: loading
            ? LinearProgressIndicator(
                minHeight: widget.height,
                backgroundColor: widget.inactiveColor,
                color: widget.activeColor.withValues(alpha: 0.45),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: h,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: widget.inactiveColor),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value.clamp(0.0, 1.0),
                        child: ColoredBox(color: widget.activeColor),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
