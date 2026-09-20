import 'package:video_player/video_player.dart';

import 'playback_memory.dart';

/// Feed (For You) playback strategy — TikTok-style short clip switching.
class FeedPlaybackStrategy {
  FeedPlaybackStrategy._();

  static const int preloadAhead = 1;
  static int get keepBehind => PlaybackMemory.feedKeepBehind;
  static int get maxHistoryParked => PlaybackMemory.feedMaxHistoryParked;
  static int get maxConcurrentPlayers =>
      PlaybackMemory.feedMaxConcurrentPlayers;

  static const Duration warmBufferTarget = Duration(seconds: 2);
  static const Duration warmBufferTimeout = Duration(seconds: 5);
  static const Duration preloadStartDelay = Duration(milliseconds: 200);
  static const Duration initializeTimeout = Duration(seconds: 12);
  static const Duration flingColdDelay = Duration(milliseconds: 90);
  static const Duration coldStartRetryPrompt = Duration(milliseconds: 3000);
  static const Duration coldStartWatchdog = Duration(seconds: 8);

  static const String qualityAuto = 'Auto';
  static const String qualityHd = '720p';
  static const String qualitySd = '480p';

  static String initialQuality({required bool wifiLike}) =>
      wifiLike ? qualityHd : qualitySd;

  static String nextAbrQuality({
    required String current,
    required bool wifiLike,
    required bool isBuffering,
    required int bufferingHits,
    required int healthyTicks,
  }) {
    if (isBuffering || bufferingHits >= 2) return qualitySd;
    if (wifiLike && healthyTicks >= 2) return qualityHd;
    if (!wifiLike) return qualitySd;
    return current;
  }

  static bool isReusablePlayer(VideoPlayerController? ctrl) {
    if (ctrl == null) return false;
    try {
      final v = ctrl.value;
      return v.isInitialized && !v.hasError;
    } catch (_) {
      return false;
    }
  }

  static bool hasPaintedSize(VideoPlayerController? ctrl) {
    if (ctrl == null) return false;
    try {
      final s = ctrl.value.size;
      return ctrl.value.isInitialized && s.width > 0 && s.height > 0;
    } catch (_) {
      return false;
    }
  }

  static Duration maxBuffered(VideoPlayerValue value) {
    var max = Duration.zero;
    for (final range in value.buffered) {
      if (range.end > max) max = range.end;
    }
    return max;
  }

  /// Mute-play until ~[target] buffered, then pause at head for instant promote.
  static Future<void> warmFirstSeconds(
    VideoPlayerController ctrl, {
    Duration target = warmBufferTarget,
    Duration timeout = warmBufferTimeout,
    bool Function()? shouldAbort,
  }) async {
    try {
      if (!isReusablePlayer(ctrl)) return;
      if (shouldAbort?.call() == true) return;

      await ctrl.setVolume(0);
      if (shouldAbort?.call() == true) return;
      await ctrl.setLooping(false);
      if (shouldAbort?.call() == true) return;

      if (maxBuffered(ctrl.value) >= target) {
        if (shouldAbort?.call() == true) return;
        await ctrl.pause();
        if (shouldAbort?.call() == true) return;
        if (ctrl.value.position > const Duration(milliseconds: 80)) {
          await ctrl.seekTo(Duration.zero);
        }
        return;
      }

      await ctrl.play();
      if (shouldAbort?.call() == true) return;

      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        if (shouldAbort?.call() == true) return;
        final v = ctrl.value;
        if (!v.isInitialized || v.hasError) break;
        if (maxBuffered(v) >= target || v.position >= target) break;
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }

      if (shouldAbort?.call() == true) return;

      await ctrl.pause();
      if (shouldAbort?.call() == true) return;
      if (ctrl.value.position > const Duration(milliseconds: 80)) {
        await ctrl.seekTo(Duration.zero);
      }
      if (shouldAbort?.call() == true) return;
      await ctrl.setVolume(0);
      await ctrl.setLooping(false);
    } catch (_) {
      if (shouldAbort?.call() == true) return;
      try {
        await ctrl.pause();
      } catch (_) {}
    }
  }
}
