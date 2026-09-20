import 'package:video_player/video_player.dart';

import 'feed_playback_strategy.dart';
import 'playback_memory.dart';

/// Series episode binge playback strategy.
class EpisodePlaybackStrategy {
  EpisodePlaybackStrategy._();

  static int get preloadAhead => PlaybackMemory.episodePreloadAhead;
  static const int preloadBehind = 1;

  static const Duration warmBufferTarget =
      FeedPlaybackStrategy.warmBufferTarget;
  static const Duration warmBufferTimeout =
      FeedPlaybackStrategy.warmBufferTimeout;
  static const Duration preloadStartDelay = Duration(milliseconds: 400);
  static const Duration initializeTimeout = Duration(seconds: 12);

  static const double preferredForwardBufferSeconds = 12;
  static const double qualitySwitchForwardBufferSeconds = 1.5;
  static const Duration qualitySwitchBufferRestoreDelay = Duration(seconds: 2);

  static const List<double> speedOptions = [3, 2, 1.5, 1.25, 1, 0.75];

  static Duration maxBuffered(VideoPlayerValue value) =>
      FeedPlaybackStrategy.maxBuffered(value);

  static bool needsWarm(VideoPlayerController ctrl) {
    if (!ctrl.value.isInitialized) return true;
    return maxBuffered(ctrl.value) < warmBufferTarget;
  }

  static Future<void> warmFirstSeconds(
    VideoPlayerController ctrl, {
    Duration target = warmBufferTarget,
    Duration timeout = warmBufferTimeout,
    bool Function()? shouldAbort,
  }) {
    return FeedPlaybackStrategy.warmFirstSeconds(
      ctrl,
      target: target,
      timeout: timeout,
      shouldAbort: shouldAbort,
    );
  }
}
