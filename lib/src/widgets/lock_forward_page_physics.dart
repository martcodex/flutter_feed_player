import 'package:flutter/widgets.dart';

/// Blocks scrolling to the *next* page while the current clip is still cold.
///
/// Allow swipe back to previous, but not forward until the first frame is
/// ready (unless error / loading prompt is showing).
class LockForwardPagePhysics extends PageScrollPhysics {
  const LockForwardPagePhysics({
    required this.lockForward,
    super.parent,
  });

  final bool lockForward;

  @override
  LockForwardPagePhysics applyTo(ScrollPhysics? ancestor) {
    return LockForwardPagePhysics(
      lockForward: lockForward,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Forward = increasing pixels (next page in vertical PageView).
    if (lockForward && value > position.pixels) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}
