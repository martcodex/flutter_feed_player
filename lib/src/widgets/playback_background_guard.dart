import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/playback_pip.dart';

/// Keeps the active page put when the app backgrounds or the window shrinks
/// into picture-in-picture, and asks the OS for a PiP window only while the
/// current video is actually playing.
class PlaybackBackgroundGuard with WidgetsBindingObserver {
  PlaybackBackgroundGuard({
    required this.pipEnabled,
    required this.isPlaying,
    required this.userPaused,
    required this.currentIndex,
    required this.pageController,
    required this.videoSize,
    required this.setSuspendAutoAdvance,
    required this.setInPictureInPicture,
    required this.pauseForBackground,
    required this.resumeFromBackground,
    required this.onUpdate,
  });

  final bool Function() pipEnabled;
  final bool Function() isPlaying;
  final bool Function() userPaused;
  final int Function() currentIndex;
  final PageController? Function() pageController;
  final Size Function() videoSize;
  final void Function(bool suspended) setSuspendAutoAdvance;
  final void Function(bool active) setInPictureInPicture;
  final Future<void> Function() pauseForBackground;
  final Future<void> Function() resumeFromBackground;
  final VoidCallback onUpdate;

  bool holding = false;
  bool metricsPin = false;
  bool programmatic = false;

  bool _attached = false;
  bool _playingSnapshot = false;
  bool _resumeOnForeground = false;
  bool _pinScheduled = false;
  Size? _lastPhysical;
  Timer? _releaseTimer;
  Timer? _fallbackPause;
  Timer? _metricsRelease;

  bool get blockPaging => holding || metricsPin;

  void attach() {
    if (_attached) return;
    _attached = true;
    _lastPhysical = _physicalSize();
    PlaybackPip.addListener(_onNativePip);
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    _releaseTimer?.cancel();
    _fallbackPause?.cancel();
    _metricsRelease?.cancel();
    PlaybackPip.removeListener(_onNativePip);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(PlaybackPip.setEligible(eligible: false, width: 9, height: 16));
  }

  Size? _physicalSize() {
    return WidgetsBinding
        .instance.platformDispatcher.implicitView?.physicalSize;
  }

  /// Refresh the "may enter PiP" bit while the app is in the foreground.
  void onForegroundTick() {
    if (holding) return;
    final playing = PlaybackPip.shouldEnter(
      enabled: true,
      playing: isPlaying(),
      userPaused: userPaused(),
    );
    _playingSnapshot = playing;
    if (!pipEnabled()) return;
    final size = videoSize();
    unawaited(
      PlaybackPip.setEligible(
        eligible: playing,
        width: size.width,
        height: size.height,
      ),
    );
  }

  bool shouldIgnorePageChange() {
    final life = WidgetsBinding.instance.lifecycleState;
    final resumed = life == null || life == AppLifecycleState.resumed;
    return PlaybackPip.shouldIgnorePageChange(
      programmatic: programmatic,
      blockPaging: blockPaging,
      lifecycleResumed: resumed,
    );
  }

  void pinPage() {
    if (_pinScheduled) return;
    _pinScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinScheduled = false;
      _pinNow();
    });
  }

  void _pinNow() {
    final pc = pageController();
    if (pc == null || !pc.hasClients) return;
    final page = pc.page;
    if (page == null) return;
    final target = currentIndex();
    if ((page - target).abs() < 0.02) return;
    try {
      pc.jumpToPage(target);
    } catch (_) {}
  }

  @override
  void didChangeMetrics() {
    final next = _physicalSize();
    final previous = _lastPhysical;
    if (next != null) _lastPhysical = next;
    final big = previous != null &&
        next != null &&
        PlaybackPip.sizeChangeShouldPin(previous, next);
    // Home-gesture scrolling is handled by [holding]. Only a real resize
    // (picture-in-picture) should freeze paging while the app is still resumed,
    // because that resize happens before the inactive callback.
    if (holding || big) pinPage();
    if (!big) return;
    if (!metricsPin) {
      metricsPin = true;
      onUpdate();
    }
    _metricsRelease?.cancel();
    _metricsRelease = Timer(const Duration(milliseconds: 250), () {
      if (!_attached) return;
      metricsPin = false;
      pinPage();
      onUpdate();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _beginBackground();
      case AppLifecycleState.paused:
        _beginBackground();
        _scheduleFallbackPause();
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.detached:
        break;
    }
  }

  void _beginBackground() {
    final first = !holding;
    holding = true;
    setSuspendAutoAdvance(true);
    onUpdate();
    pinPage();
    if (!first) return;
    // Do not call enter() here. `inactive` also fires for the notification
    // shade and Control Center. Android enters from onUserLeaveHint /
    // setAutoEnterEnabled; iOS enters from the armed AVPictureInPicture
    // controller when the app actually backgrounds.
    if (pipEnabled() && !_playingSnapshot) {
      final size = videoSize();
      unawaited(
        PlaybackPip.setEligible(
          eligible: false,
          width: size.width,
          height: size.height,
        ),
      );
    }
  }

  void _scheduleFallbackPause() {
    if (!pipEnabled() || !_playingSnapshot) return;
    _fallbackPause?.cancel();
    _fallbackPause = Timer(const Duration(milliseconds: 600), () async {
      if (!_attached) return;
      final life = WidgetsBinding.instance.lifecycleState;
      if (life == null || life == AppLifecycleState.resumed) return;
      final keep = await PlaybackPip.keepPlaying();
      if (keep || !_attached) return;
      if (!isPlaying()) return;
      _resumeOnForeground = true;
      await pauseForBackground();
    });
  }

  void _onResumed() {
    _fallbackPause?.cancel();
    if (_resumeOnForeground && !PlaybackPip.active) {
      _resumeOnForeground = false;
      unawaited(resumeFromBackground());
    }
    pinPage();
    _releaseTimer?.cancel();
    _releaseTimer = Timer(const Duration(milliseconds: 350), () {
      if (!_attached) return;
      holding = false;
      setSuspendAutoAdvance(false);
      onUpdate();
      onForegroundTick();
    });
  }

  void _onNativePip(bool active) {
    if (active) {
      _fallbackPause?.cancel();
      _resumeOnForeground = false;
    }
    setInPictureInPicture(active);
    onUpdate();
  }
}
