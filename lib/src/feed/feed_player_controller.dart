import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../core/feed_playback_strategy.dart';
import '../core/playback_audio.dart';
import '../core/player_factory.dart';
import '../models/playable_models.dart';

/// Loads a page of [FeedItem]s. Return empty list when exhausted.
typedef FeedPageLoader = Future<List<FeedItem>> Function(int page);

/// Controller for the vertical recommendation / For You feed player.
class FeedPlayerController extends ChangeNotifier {
  FeedPlayerController({
    required this.loader,
    this.headersProvider,
    this.urlTransformer,
    this.allowBackgroundPlayback = false,
    this.pageSize = 10,
    this.loopClips = true,
    /// When true, blocks swipe-to-next until the first frame is ready.
    /// Default false — HLS cold starts often keep this locked and feel stuck.
    this.lockForwardWhileCold = false,
  });

  final FeedPageLoader loader;
  final HttpHeadersProvider? headersProvider;
  final UrlTransformer? urlTransformer;
  final bool allowBackgroundPlayback;
  final int pageSize;

  /// Short-form feeds usually loop the active clip.
  bool loopClips;

  /// Forward lock while cold-starting; keep off unless host app wants it.
  bool lockForwardWhileCold;

  final List<FeedItem> items = [];
  final LinkedHashMap<String, VideoPlayerController> _parked =
      LinkedHashMap<String, VideoPlayerController>();
  final Set<String> _watchedKeys = <String>{};
  final Map<String, Future<VideoPlayerController?>> _initFutures = {};

  VideoPlayerController? player;
  String? activeKey;
  int currentIndex = 0;
  int page = 0;
  bool hasMore = true;
  bool loading = false;
  bool loadingMore = false;
  bool isPlaying = false;
  bool showCenterPlay = false;
  bool playerReady = false;
  bool videoFrameReady = false;
  bool isBoosting = false;
  double playbackSpeed = 1.0;
  String? errorMessage;

  /// Native / init failure — show retry overlay on the active page.
  bool hasPlaybackError = false;

  /// Prolonged cold start — soft prompt before auto-retry.
  bool showLoadingPrompt = false;

  int parkedVersion = 0;
  int feedRevision = 0;

  int _playSeq = 0;
  int _autoRetryCount = 0;
  bool _disposed = false;
  bool _visible = true;
  VoidCallback? _playerListener;
  Timer? _loadingPromptTimer;
  Timer? _watchdogTimer;

  /// Block swipe to next while cold-loading (allow swipe back).
  bool get locksForwardSwipe {
    if (!lockForwardWhileCold) return false;
    if (hasPlaybackError || showLoadingPrompt) return false;
    if (items.isEmpty) return false;
    if (playerReady && videoFrameReady) return false;
    if (isPlaying) return false;
    final item = items[currentIndex.clamp(0, items.length - 1)];
    if (item.playUrl.isEmpty) return false;
    return true;
  }

  String itemKey(FeedItem item, int index) {
    final id = item.identity;
    if (id.isNotEmpty) return id;
    return 'idx_$index';
  }

  VideoPlayerController? displayPlayerFor(String key) {
    if (activeKey == key && player != null) return player;
    return _parked[key];
  }

  Future<void> init() async {
    PlaybackAudio.surfaceMayPlay = true;
    await refresh();
  }

  Future<void> refresh() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      page = 1;
      final batch = await loader(page);
      _disposeAllPlayers();
      items
        ..clear()
        ..addAll(batch);
      hasMore = batch.length >= pageSize;
      feedRevision++;
      currentIndex = 0;
      loading = false;
      notifyListeners();
      if (items.isNotEmpty) {
        await playAt(0);
      }
    } catch (e) {
      loading = false;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || loadingMore || loading) return;
    loadingMore = true;
    notifyListeners();
    try {
      final next = page + 1;
      final batch = await loader(next);
      if (batch.isEmpty) {
        hasMore = false;
      } else {
        page = next;
        items.addAll(batch);
        hasMore = batch.length >= pageSize;
        feedRevision++;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FeedPlayer] loadMore: $e');
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  void setVisible(bool visible) {
    _visible = visible;
    PlaybackAudio.surfaceMayPlay = visible;
    if (!visible) {
      pause();
      PlaybackAudio.enforceSurface();
    } else if (player != null && isPlaying) {
      unawaited(_kickoffActive());
    }
  }

  Future<void> onPageChanged(int index) async {
    if (index < 0 || index >= items.length) return;
    currentIndex = index;
    showCenterPlay = false;
    errorMessage = null;
    hasPlaybackError = false;
    showLoadingPrompt = false;
    isBoosting = false;
    playbackSpeed = 1.0;
    _autoRetryCount = 0;
    _cancelColdStartTimers();
    notifyListeners();
    await playAt(index, restartFromStart: true);
    if (index >= items.length - 3) {
      unawaited(loadMore());
    }
  }

  /// Eagerly warm the next item when the user starts dragging forward.
  void onForwardSwipeIntent() {
    if (_disposed || items.isEmpty) return;
    final next = currentIndex + 1;
    if (next >= items.length) return;
    _schedulePreload(currentIndex, immediate: true);
  }

  Future<void> playAt(int index, {bool restartFromStart = false}) async {
    if (_disposed || index < 0 || index >= items.length) return;
    final seq = ++_playSeq;
    final item = items[index];
    final key = itemKey(item, index);
    hasPlaybackError = false;
    showLoadingPrompt = false;
    _cancelColdStartTimers();

    _parkCurrentIfNeeded(keepKey: key);

    final promoted = _parked.remove(key);
    if (promoted != null && FeedPlaybackStrategy.isReusablePlayer(promoted)) {
      await _attachActive(promoted, key: key, seq: seq, restartFromStart: restartFromStart);
      _schedulePreload(index);
      return;
    }

    final unwatched = !_watchedKeys.contains(key);
    if (unwatched) {
      await Future<void>.delayed(FeedPlaybackStrategy.flingColdDelay);
      if (seq != _playSeq || _disposed) return;
      final late = _parked.remove(key);
      if (late != null && FeedPlaybackStrategy.isReusablePlayer(late)) {
        await _attachActive(late, key: key, seq: seq, restartFromStart: restartFromStart);
        _schedulePreload(index);
        return;
      }
    }

    final url = PlayerFactory.resolvePlayUrl(
      playUrl: item.episode.playUrl,
      assets: item.episode.assets,
    );
    if (url.isEmpty) {
      errorMessage = 'No playable URL';
      hasPlaybackError = true;
      playerReady = false;
      notifyListeners();
      return;
    }

    _armColdStartWatchdog(seq);

    final existingInit = _initFutures[key];
    VideoPlayerController? ctrl;
    if (existingInit != null) {
      ctrl = await existingInit;
    } else {
      final future = _createAndInit(url, key);
      _initFutures[key] = future;
      ctrl = await future;
      _initFutures.remove(key);
    }
    if (seq != _playSeq || _disposed) {
      if (ctrl != null) {
        _parked[key] = ctrl;
        _trimParked(active: key);
      }
      return;
    }
    if (ctrl == null) {
      hasPlaybackError = true;
      errorMessage = 'Failed to load video';
      playerReady = false;
      videoFrameReady = false;
      _cancelColdStartTimers();
      notifyListeners();
      return;
    }
    await _attachActive(ctrl, key: key, seq: seq, restartFromStart: true);
    _schedulePreload(index);
  }

  /// Rebuild the active decoder after a stall / error.
  Future<void> retryPlayback() async {
    if (_disposed || items.isEmpty) return;
    final index = currentIndex;
    final key = activeKey;
    _cancelColdStartTimers();
    hasPlaybackError = false;
    showLoadingPrompt = false;
    errorMessage = null;
    _detachListener();
    if (player != null) {
      PlaybackAudio.release(player!);
      player!.dispose();
      player = null;
    }
    if (key != null) {
      final parked = _parked.remove(key);
      if (parked != null) {
        PlaybackAudio.release(parked);
        parked.dispose();
      }
      _initFutures.remove(key);
    }
    activeKey = null;
    playerReady = false;
    videoFrameReady = false;
    parkedVersion++;
    notifyListeners();
    await playAt(index, restartFromStart: false);
  }

  Future<VideoPlayerController?> _createAndInit(String url, String key) async {
    final ctrl = PlayerFactory.create(
      url,
      allowBackgroundPlayback: allowBackgroundPlayback,
      headersProvider: headersProvider,
      urlTransformer: urlTransformer,
    );
    try {
      await PlayerFactory.initializeWithTimeout(
        ctrl,
        timeout: FeedPlaybackStrategy.initializeTimeout,
      );
      await ctrl.setLooping(loopClips);
      await ctrl.setVolume(0);
      return ctrl;
    } catch (e) {
      PlaybackAudio.release(ctrl);
      ctrl.dispose();
      if (kDebugMode) debugPrint('[FeedPlayer] init $key: $e');
      return null;
    }
  }

  Future<void> _attachActive(
    VideoPlayerController ctrl, {
    required String key,
    required int seq,
    required bool restartFromStart,
  }) async {
    if (seq != _playSeq || _disposed) {
      _parked[key] = ctrl;
      return;
    }
    _detachListener();
    player = ctrl;
    activeKey = key;
    _watchedKeys.add(key);
    playerReady = ctrl.value.isInitialized && !ctrl.value.hasError;
    videoFrameReady = FeedPlaybackStrategy.hasPaintedSize(ctrl);
    parkedVersion++;
    notifyListeners();

    _playerListener = () {
      if (_disposed || !identical(player, ctrl)) return;
      final v = ctrl.value;
      final ready = v.isInitialized && !v.hasError;
      final painted = FeedPlaybackStrategy.hasPaintedSize(ctrl);
      final playing = v.isPlaying;
      if (v.hasError && !hasPlaybackError) {
        hasPlaybackError = true;
        errorMessage = v.errorDescription ?? 'Playback error';
        isPlaying = false;
        _cancelColdStartTimers();
        notifyListeners();
        return;
      }
      if (ready != playerReady ||
          painted != videoFrameReady ||
          playing != isPlaying) {
        playerReady = ready;
        videoFrameReady = painted;
        isPlaying = playing;
        if (ready && painted) {
          showLoadingPrompt = false;
          _autoRetryCount = 0;
          _cancelColdStartTimers();
        }
        notifyListeners();
      }
    };
    ctrl.addListener(_playerListener!);
    try {
      await ctrl.setLooping(loopClips);
    } catch (_) {}
    if (restartFromStart && ctrl.value.position > Duration.zero) {
      try {
        await ctrl.seekTo(Duration.zero);
      } catch (_) {}
    }
    if (seq != _playSeq) return;
    await _kickoffActive();
    if (playerReady && videoFrameReady) {
      _cancelColdStartTimers();
      showLoadingPrompt = false;
    } else {
      _armColdStartWatchdog(seq);
    }
  }

  void _armColdStartWatchdog(int seq) {
    _cancelColdStartTimers();
    _loadingPromptTimer = Timer(
      FeedPlaybackStrategy.coldStartRetryPrompt,
      () {
        if (_disposed || seq != _playSeq) return;
        if (hasPlaybackError || showCenterPlay) return;
        if (playerReady && videoFrameReady) return;
        showLoadingPrompt = true;
        notifyListeners();
      },
    );
    _watchdogTimer = Timer(
      FeedPlaybackStrategy.coldStartWatchdog,
      () {
        if (_disposed || seq != _playSeq) return;
        if (!_visible || hasPlaybackError || showCenterPlay) return;
        if (playerReady && videoFrameReady && isPlaying) return;
        if (_autoRetryCount >= 1) {
          hasPlaybackError = true;
          errorMessage = 'Playback timed out';
          showLoadingPrompt = true;
          notifyListeners();
          return;
        }
        _autoRetryCount++;
        unawaited(retryPlayback());
      },
    );
  }

  void _cancelColdStartTimers() {
    _loadingPromptTimer?.cancel();
    _loadingPromptTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  Future<void> _kickoffActive() async {
    final ctrl = player;
    if (ctrl == null || !_visible) return;
    try {
      await ctrl.setPlaybackSpeed(isBoosting ? 2.0 : playbackSpeed);
      await PlaybackAudio.unmuteExclusive(ctrl);
      await ctrl.play();
      isPlaying = true;
      showCenterPlay = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[FeedPlayer] kickoff: $e');
    }
  }

  void _detachListener() {
    final ctrl = player;
    final listener = _playerListener;
    if (ctrl != null && listener != null) {
      try {
        ctrl.removeListener(listener);
      } catch (_) {}
    }
    _playerListener = null;
  }

  void _parkCurrentIfNeeded({required String keepKey}) {
    final ctrl = player;
    final key = activeKey;
    if (ctrl == null || key == null) return;
    if (key == keepKey) return;
    _detachListener();
    PlaybackAudio.silence(ctrl);
    // Never seek while parked — blacks iOS HLS texture.
    _parked[key] = ctrl;
    player = null;
    activeKey = null;
    playerReady = false;
    videoFrameReady = false;
    isPlaying = false;
    parkedVersion++;
    _trimParked(active: keepKey);
    notifyListeners();
  }

  void _schedulePreload(int index, {bool immediate = false}) {
    unawaited(() async {
      if (!immediate) {
        await Future<void>.delayed(FeedPlaybackStrategy.preloadStartDelay);
      }
      if (_disposed) return;
      final next = index + FeedPlaybackStrategy.preloadAhead;
      if (next < 0 || next >= items.length) return;
      final item = items[next];
      final key = itemKey(item, next);
      if (key == activeKey || _parked.containsKey(key)) return;
      if (_initFutures.containsKey(key)) return;

      final url = PlayerFactory.resolvePlayUrl(
        playUrl: item.episode.playUrl,
        assets: item.episode.assets,
      );
      if (url.isEmpty) return;

      final future = _createAndInit(url, key);
      _initFutures[key] = future;
      final ctrl = await future;
      _initFutures.remove(key);
      if (_disposed || ctrl == null) return;
      if (activeKey == key) {
        // Already promoted while init ran.
        PlaybackAudio.release(ctrl);
        ctrl.dispose();
        return;
      }
      await FeedPlaybackStrategy.warmFirstSeconds(
        ctrl,
        shouldAbort: () => _disposed || activeKey == key,
      );
      if (_disposed || activeKey == key) {
        if (activeKey != key) {
          PlaybackAudio.release(ctrl);
          ctrl.dispose();
        }
        return;
      }
      _parked[key] = ctrl;
      parkedVersion++;
      _trimParked(active: activeKey);
      notifyListeners();
    }());
  }

  void _trimParked({String? active}) {
    final maxConcurrent = FeedPlaybackStrategy.maxConcurrentPlayers;
    final keepBehind = FeedPlaybackStrategy.keepBehind;

    // Drop unwatched preloads first (LinkedHashMap insertion order).
    for (final k in _parked.keys.toList()) {
      if (_parked.length <= maxConcurrent) break;
      if (!_watchedKeys.contains(k) && k != active) {
        final removed = _parked.remove(k);
        if (removed != null) {
          PlaybackAudio.release(removed);
          removed.dispose();
        }
      }
    }

    while (_parked.length > keepBehind) {
      final oldest = _parked.keys.firstWhere(
        (k) => k != active,
        orElse: () => '',
      );
      if (oldest.isEmpty) break;
      final removed = _parked.remove(oldest);
      if (removed == null) break;
      PlaybackAudio.release(removed);
      removed.dispose();
    }

    while (_parked.length >= maxConcurrent) {
      final oldest = _parked.keys.firstWhere(
        (k) => k != active,
        orElse: () => '',
      );
      if (oldest.isEmpty) break;
      final removed = _parked.remove(oldest);
      if (removed == null) break;
      PlaybackAudio.release(removed);
      removed.dispose();
    }
  }

  Future<void> togglePlayPause() async {
    final ctrl = player;
    if (ctrl == null) return;
    if (ctrl.value.isPlaying) {
      await pause();
      showCenterPlay = true;
    } else {
      await play();
      showCenterPlay = false;
    }
    notifyListeners();
  }

  Future<void> play() async {
    final ctrl = player;
    if (ctrl == null) return;
    await PlaybackAudio.unmuteExclusive(ctrl);
    await ctrl.play();
    isPlaying = true;
    showCenterPlay = false;
    notifyListeners();
  }

  Future<void> pause() async {
    final ctrl = player;
    if (ctrl == null) return;
    await ctrl.pause();
    isPlaying = false;
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    final ctrl = player;
    if (ctrl == null) return;
    await ctrl.seekTo(position);
  }

  void setBoosting(bool boosting) {
    isBoosting = boosting;
    final ctrl = player;
    if (ctrl != null) {
      unawaited(ctrl.setPlaybackSpeed(boosting ? 2.0 : playbackSpeed));
    }
    notifyListeners();
  }

  /// Toggle clip looping on the active player.
  Future<void> setLoopClips(bool value) async {
    if (loopClips == value) return;
    loopClips = value;
    final ctrl = player;
    if (ctrl != null) {
      try {
        await ctrl.setLooping(value);
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Toggle forward-swipe lock while the active clip is still cold-starting.
  void setLockForwardWhileCold(bool value) {
    if (lockForwardWhileCold == value) return;
    lockForwardWhileCold = value;
    notifyListeners();
  }

  void toggleLike(int index) {
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    final liked = !item.isLiked;
    items[index] = item.copyWith(
      isLiked: liked,
      likeCount: liked ? item.likeCount + 1 : (item.likeCount - 1).clamp(0, 1 << 30),
    );
    notifyListeners();
  }

  void _disposeAllPlayers() {
    if (player != null) {
      PlaybackAudio.release(player!);
      player!.dispose();
      player = null;
    }
    for (final c in _parked.values) {
      PlaybackAudio.release(c);
      c.dispose();
    }
    _parked.clear();
    _initFutures.clear();
    activeKey = null;
    playerReady = false;
    videoFrameReady = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _playSeq++;
    _cancelColdStartTimers();
    _disposeAllPlayers();
    PlaybackAudio.surfaceMayPlay = false;
    super.dispose();
  }
}
