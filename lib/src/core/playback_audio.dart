import 'dart:async';

import 'package:video_player/video_player.dart';

/// Process-wide exclusive audio for [VideoPlayerController]s.
///
/// Only one controller may be unmuted at a time. Host apps should set
/// [surfaceMayPlay] when a player surface is visible.
class PlaybackAudio {
  PlaybackAudio._();

  static final Set<VideoPlayerController> _live = <VideoPlayerController>{};
  static VideoPlayerController? _audible;

  /// When false, [unmuteExclusive] refuses and [enforceSurface] silences all.
  static bool surfaceMayPlay = true;

  static bool get mayPlayAudio => surfaceMayPlay;

  static VideoPlayerController track(VideoPlayerController controller) {
    _live.add(controller);
    return controller;
  }

  static void forget(VideoPlayerController controller) {
    _live.remove(controller);
    if (identical(_audible, controller)) _audible = null;
  }

  /// Drop tracking immediately, then best-effort pause+mute.
  ///
  /// Call before [VideoPlayerController.dispose].
  static void release(VideoPlayerController controller) {
    forget(controller);
    unawaited(_quietDetached(controller));
  }

  static void silence(VideoPlayerController controller) {
    unawaited(_silence(controller));
  }

  static Future<void> _silence(VideoPlayerController controller) async {
    if (!_live.contains(controller)) return;
    final ok = await _quietDetached(controller);
    if (!ok) {
      forget(controller);
      return;
    }
    if (identical(_audible, controller)) _audible = null;
  }

  static Future<bool> _quietDetached(VideoPlayerController controller) async {
    try {
      await controller.pause();
    } catch (_) {
      return false;
    }
    try {
      await controller.setVolume(0);
      return true;
    } catch (_) {
      return false;
    }
  }

  static void silenceAll({VideoPlayerController? except}) {
    unawaited(silenceAllAsync(except: except));
  }

  static Future<void> silenceAllAsync({VideoPlayerController? except}) async {
    final pending = <Future<void>>[];
    for (final ctrl in List<VideoPlayerController>.from(_live)) {
      if (except != null && identical(ctrl, except)) continue;
      pending.add(_silence(ctrl));
    }
    if (pending.isEmpty) return;
    await Future.wait(pending);
  }

  static void enforceSurface() {
    if (mayPlayAudio) return;
    silenceAll();
  }

  /// Pause + mute every other live player, then unmute [controller] if allowed.
  static Future<bool> unmuteExclusive(VideoPlayerController controller) async {
    if (!mayPlayAudio) {
      await _silence(controller);
      return false;
    }
    await silenceAllAsync(except: controller);
    if (!_live.contains(controller)) return false;
    try {
      await controller.setVolume(0.99);
      await controller.setVolume(1);
      _audible = controller;
      return true;
    } catch (_) {
      forget(controller);
      return false;
    }
  }
}
