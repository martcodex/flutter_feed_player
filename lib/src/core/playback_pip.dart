import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// System picture-in-picture bridge.
///
/// Android shrinks the current activity. iOS starts `AVPictureInPicture`
/// from the on-screen `AVPlayerLayer` (platform-view player).
class PlaybackPip {
  PlaybackPip._();

  static const MethodChannel _channel =
      MethodChannel('flutter_feed_player/pip');

  static bool active = false;
  static bool _handlerReady = false;
  static final List<void Function(bool active)> _listeners = [];

  static void addListener(void Function(bool active) listener) {
    _listeners.add(listener);
    _ensureHandler();
  }

  static void removeListener(void Function(bool active) listener) {
    _listeners.remove(listener);
  }

  static void _ensureHandler() {
    if (_handlerReady) return;
    _handlerReady = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        _setActive(call.arguments == true);
      }
    });
  }

  static void _setActive(bool value) {
    active = value;
    for (final listener in List<void Function(bool)>.of(_listeners)) {
      listener(value);
    }
  }

  /// Playing, and the user has not paused, and the host turned PiP on.
  static bool shouldEnter({
    required bool enabled,
    required bool playing,
    required bool userPaused,
  }) {
    return enabled && playing && !userPaused;
  }

  /// A real picture-in-picture resize changes the window by a lot. Inset and
  /// status-bar updates stay near 1.0 and must not cancel a swipe.
  static bool sizeChangeShouldPin(Size previous, Size next) {
    if (previous.width <= 0 ||
        previous.height <= 0 ||
        next.width <= 0 ||
        next.height <= 0) {
      return false;
    }
    final widthRatio = next.width / previous.width;
    final heightRatio = next.height / previous.height;
    return widthRatio < 0.85 ||
        widthRatio > 1.15 ||
        heightRatio < 0.85 ||
        heightRatio > 1.15;
  }

  /// Ignore [PageView] settlements while backgrounded or while the window
  /// size is changing. A viewport shrink remaps the old scroll offset onto
  /// a later page.
  static bool shouldIgnorePageChange({
    required bool programmatic,
    required bool blockPaging,
    required bool lifecycleResumed,
  }) {
    if (!lifecycleResumed) return true;
    if (programmatic) return false;
    return blockPaging;
  }

  static Future<void> setEligible({
    required bool eligible,
    required double width,
    required double height,
  }) async {
    _ensureHandler();
    try {
      await _channel.invokeMethod<void>('setEligible', {
        'eligible': eligible,
        'width': width.round().clamp(1, 10000),
        'height': height.round().clamp(1, 10000),
      });
    } on MissingPluginException {
      // Desktop / web / tests.
    } catch (e) {
      if (kDebugMode) debugPrint('[PlaybackPip] setEligible: $e');
    }
  }

  static Future<bool> enter() async {
    _ensureHandler();
    try {
      final entered = await _channel.invokeMethod<bool>('enter');
      return entered ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[PlaybackPip] enter: $e');
      return false;
    }
  }

  /// True when the system window is up, or iOS still has a live player that
  /// can enter it. Used so a late background callback does not pause PiP.
  static Future<bool> keepPlaying() async {
    _ensureHandler();
    try {
      final value = await _channel.invokeMethod<bool>('keepPlaying');
      return value ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[PlaybackPip] keepPlaying: $e');
      return false;
    }
  }

  static Future<bool> refreshActive() async {
    _ensureHandler();
    try {
      final value = await _channel.invokeMethod<bool>('isActive');
      if (value != null) _setActive(value);
      return active;
    } on MissingPluginException {
      return active;
    } catch (e) {
      if (kDebugMode) debugPrint('[PlaybackPip] isActive: $e');
      return active;
    }
  }
}
