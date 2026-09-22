import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../core/episode_playback_strategy.dart';
import '../core/feed_playback_strategy.dart';
import '../core/playback_audio.dart';
import '../core/player_cache.dart';
import '../core/player_factory.dart';
import '../models/playable_models.dart';

/// Supplies series + a page of episodes. Page starts at 1.
///
/// Page 1 must include series metadata. Later pages only need [SeriesInfo.episodes]
/// (other fields are ignored when appending). Return an empty episode list when
/// exhausted.
typedef SeriesLoader = Future<SeriesInfo> Function(int page);

/// Controller for the vertical series episode binge player.
class EpisodePlayerController extends ChangeNotifier {
  EpisodePlayerController({
    required this.loader,
    this.initialEpisodeId,
    this.initialEpisodeNo,
    this.headersProvider,
    this.urlTransformer,
    this.allowBackgroundPlayback = false,
    this.lockForwardWhileCold = false,
    this.pageSize = 10,
  });

  final SeriesLoader loader;
  final String? initialEpisodeId;
  final int? initialEpisodeNo;
  final HttpHeadersProvider? headersProvider;
  final UrlTransformer? urlTransformer;
  final bool allowBackgroundPlayback;
  bool lockForwardWhileCold;
  final int pageSize;

  SeriesInfo? series;
  VideoPlayerController? player;
  String? activeEpisodeId;
  int currentIndex = 0;
  int page = 0;
  bool hasMore = true;
  bool loading = false;
  bool loadingMore = false;
  bool isPlaying = false;
  bool showChrome = true;
  bool showCenterPlay = false;
  bool playerReady = false;
  bool videoFrameReady = false;
  bool isBoosting = false;
  double playbackSpeed = 1.0;
  String quality = '720p';
  String? errorMessage;
  bool hasPlaybackError = false;
  bool showLoadingPrompt = false;
  int parkedVersion = 0;
  int switchSeq = 0;
  int episodeRevision = 0;

  VoidCallback? _playerListener;
  Timer? _hideChromeTimer;
  Timer? _loadingPromptTimer;
  Timer? _watchdogTimer;
  int _autoRetryCount = 0;
  bool _disposed = false;
  bool _visible = true;

  List<EpisodeItem> get episodes => series?.episodes ?? const [];

  bool get locksForwardSwipe {
    if (!lockForwardWhileCold) return false;
    if (hasPlaybackError || showLoadingPrompt) return false;
    if (episodes.isEmpty) return false;
    if (playerReady && videoFrameReady) return false;
    if (isPlaying) return false;
    return episodes[currentIndex].resolvedPlayUrl.isNotEmpty;
  }

  VideoPlayerController? displayPlayerFor(String episodeId) {
    if (activeEpisodeId == episodeId && player != null) return player;
    return PlayerCache.peek(episodeId);
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
      final data = await loader(page);
      _evictPlayers();
      series = data;
      if (data.episodes.isEmpty) {
        errorMessage = 'No episodes';
        hasMore = false;
        loading = false;
        episodeRevision++;
        notifyListeners();
        return;
      }
      hasMore = data.episodes.length >= pageSize;
      currentIndex = _resolveStartIndex(data.episodes);
      episodeRevision++;
      loading = false;
      notifyListeners();
      await switchEpisode(currentIndex);
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
      final data = await loader(next);
      final batch = data.episodes;
      if (batch.isEmpty) {
        hasMore = false;
      } else {
        page = next;
        final current = series;
        if (current == null) {
          series = data;
        } else {
          series = SeriesInfo(
            seriesId: current.seriesId,
            title: current.title,
            coverUrl: current.coverUrl,
            description: current.description,
            episodes: [...current.episodes, ...batch],
          );
        }
        hasMore = batch.length >= pageSize;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[EpisodePlayer] loadMore: $e');
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  int _resolveStartIndex(List<EpisodeItem> list) {
    final id = initialEpisodeId?.trim() ?? '';
    if (id.isNotEmpty) {
      final i = list.indexWhere((e) => e.episodeId == id);
      if (i >= 0) return i;
    }
    final no = initialEpisodeNo;
    if (no != null && no > 0) {
      final i = list.indexWhere((e) => e.episodeNo == no);
      if (i >= 0) return i;
    }
    return 0;
  }

  void setVisible(bool visible) {
    _visible = visible;
    PlaybackAudio.surfaceMayPlay = visible;
    if (!visible) {
      pause();
      _parkActive();
      PlayerCache.silenceAll();
      PlaybackAudio.enforceSurface();
    }
  }

  Future<void> onEpisodePageChanged(int index) async {
    if (index < 0 || index >= episodes.length) return;
    await switchEpisode(index, restartFromStart: true);
    if (index >= episodes.length - 3) {
      unawaited(loadMore());
    }
  }

  void _evictPlayers() {
    _cancelColdStartTimers();
    _detachListener();
    final ids = <String>{
      if (activeEpisodeId != null) activeEpisodeId!,
      for (var i = 0; i < episodes.length; i++)
        episodes[i].episodeId.isNotEmpty
            ? episodes[i].episodeId
            : 'ep_$i',
    };
    if (player != null) {
      PlaybackAudio.release(player!);
      player!.dispose();
      player = null;
    }
    for (final id in ids) {
      final taken = PlayerCache.take(id);
      if (taken != null) {
        PlaybackAudio.release(taken);
        taken.dispose();
      }
    }
    activeEpisodeId = null;
    playerReady = false;
    videoFrameReady = false;
    isPlaying = false;
    parkedVersion++;
  }

  Future<void> switchEpisode(
    int index, {
    bool restartFromStart = false,
  }) async {
    if (_disposed || index < 0 || index >= episodes.length) return;
    final seq = ++switchSeq;
    final ep = episodes[index];
    final episodeId = ep.episodeId.isNotEmpty ? ep.episodeId : 'ep_$index';

    currentIndex = index;
    showCenterPlay = false;
    errorMessage = null;
    hasPlaybackError = false;
    showLoadingPrompt = false;
    isBoosting = false;
    _autoRetryCount = 0;
    _cancelColdStartTimers();
    notifyListeners();

    _parkActive(exceptId: episodeId);

    // Try promote from process cache.
    final cached = PlayerCache.takeEntry(episodeId);
    if (cached != null &&
        FeedPlaybackStrategy.isReusablePlayer(cached.controller)) {
      await _attachActive(
        cached.controller,
        episodeId: episodeId,
        url: cached.url,
        quality: cached.quality,
        seq: seq,
        restartFromStart: restartFromStart,
        resume: restartFromStart ? null : ep.startPosition,
      );
      _scheduleAdjacentPreload(index);
      return;
    }

    final url = PlayerFactory.resolvePlayUrl(
      playUrl: ep.playUrl,
      assets: ep.assets,
      quality: quality,
    );
    if (url.isEmpty) {
      errorMessage = 'No playable URL';
      hasPlaybackError = true;
      playerReady = false;
      notifyListeners();
      return;
    }

    _armColdStartWatchdog(seq);

    final ctrl = PlayerFactory.create(
      url,
      allowBackgroundPlayback: allowBackgroundPlayback,
      headersProvider: headersProvider,
      urlTransformer: urlTransformer,
    );
    try {
      await PlayerFactory.initializeWithTimeout(
        ctrl,
        timeout: EpisodePlaybackStrategy.initializeTimeout,
      );
    } catch (e) {
      PlaybackAudio.release(ctrl);
      ctrl.dispose();
      if (seq != switchSeq) return;
      errorMessage = e.toString();
      hasPlaybackError = true;
      _cancelColdStartTimers();
      notifyListeners();
      return;
    }
    if (seq != switchSeq || _disposed) {
      PlayerCache.put(
        episodeId: episodeId,
        url: url,
        quality: quality,
        controller: ctrl,
      );
      return;
    }
    await _attachActive(
      ctrl,
      episodeId: episodeId,
      url: url,
      quality: quality,
      seq: seq,
      restartFromStart: restartFromStart,
      resume: restartFromStart ? null : ep.startPosition,
    );
    _scheduleAdjacentPreload(index);
  }

  Future<void> _attachActive(
    VideoPlayerController ctrl, {
    required String episodeId,
    required String url,
    required String quality,
    required int seq,
    required bool restartFromStart,
    Duration? resume,
  }) async {
    if (seq != switchSeq || _disposed) {
      PlayerCache.put(
        episodeId: episodeId,
        url: url,
        quality: quality,
        controller: ctrl,
      );
      return;
    }

    _detachListener();
    player = ctrl;
    activeEpisodeId = episodeId;
    playerReady = ctrl.value.isInitialized && !ctrl.value.hasError;
    videoFrameReady = FeedPlaybackStrategy.hasPaintedSize(ctrl);
    parkedVersion++;

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
    notifyListeners();

    try {
      if (restartFromStart) {
        if (ctrl.value.position > Duration.zero) {
          await ctrl.seekTo(Duration.zero);
        }
      } else if (resume != null && resume > Duration.zero) {
        await ctrl.seekTo(resume);
      }
      await ctrl.setLooping(false);
      await ctrl.setPlaybackSpeed(isBoosting ? 2.0 : playbackSpeed);
    } catch (_) {}

    if (seq != switchSeq) return;
    await _kickoff();
    _armChromeHide();
    if (playerReady && videoFrameReady) {
      _cancelColdStartTimers();
      showLoadingPrompt = false;
    } else {
      _armColdStartWatchdog(seq);
    }
  }

  Future<void> retryPlayback() async {
    if (_disposed || episodes.isEmpty) return;
    final index = currentIndex;
    final id = activeEpisodeId;
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
    if (id != null) {
      final taken = PlayerCache.take(id);
      if (taken != null) {
        PlaybackAudio.release(taken);
        taken.dispose();
      }
    }
    activeEpisodeId = null;
    playerReady = false;
    videoFrameReady = false;
    parkedVersion++;
    notifyListeners();
    await switchEpisode(index, restartFromStart: false);
  }

  void _armColdStartWatchdog(int seq) {
    _cancelColdStartTimers();
    _loadingPromptTimer = Timer(
      FeedPlaybackStrategy.coldStartRetryPrompt,
      () {
        if (_disposed || seq != switchSeq) return;
        if (hasPlaybackError || showCenterPlay) return;
        if (playerReady && videoFrameReady) return;
        showLoadingPrompt = true;
        notifyListeners();
      },
    );
    _watchdogTimer = Timer(
      FeedPlaybackStrategy.coldStartWatchdog,
      () {
        if (_disposed || seq != switchSeq) return;
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

  Future<void> _kickoff() async {
    final ctrl = player;
    if (ctrl == null || !_visible) return;
    try {
      await PlaybackAudio.unmuteExclusive(ctrl);
      await ctrl.play();
      isPlaying = true;
      showCenterPlay = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[EpisodePlayer] kickoff: $e');
    }
  }

  void _parkActive({String? exceptId}) {
    final ctrl = player;
    final id = activeEpisodeId;
    if (ctrl == null || id == null) return;
    if (exceptId != null && id == exceptId) return;
    _detachListener();

    String url = '';
    for (var i = 0; i < episodes.length; i++) {
      final ep = episodes[i];
      final epId = ep.episodeId.isNotEmpty ? ep.episodeId : 'ep_$i';
      if (epId == id) {
        url = PlayerFactory.resolvePlayUrl(
          playUrl: ep.playUrl,
          assets: ep.assets,
          quality: quality,
        );
        break;
      }
    }
    PlayerCache.put(
      episodeId: id,
      url: url,
      quality: quality,
      controller: ctrl,
    );
    player = null;
    activeEpisodeId = null;
    playerReady = false;
    videoFrameReady = false;
    isPlaying = false;
    parkedVersion++;
    notifyListeners();
  }

  void _scheduleAdjacentPreload(int index) {
    unawaited(() async {
      await Future<void>.delayed(EpisodePlaybackStrategy.preloadStartDelay);
      if (_disposed) return;
      final targets = <int>[];
      for (var i = 1; i <= EpisodePlaybackStrategy.preloadAhead; i++) {
        targets.add(index + i);
      }
      for (var i = 1; i <= EpisodePlaybackStrategy.preloadBehind; i++) {
        targets.add(index - i);
      }
      for (final i in targets) {
        if (i < 0 || i >= episodes.length) continue;
        final ep = episodes[i];
        final episodeId = ep.episodeId.isNotEmpty ? ep.episodeId : 'ep_$i';
        if (episodeId == activeEpisodeId) continue;
        if (PlayerCache.peek(episodeId) != null) continue;

        final url = PlayerFactory.resolvePlayUrl(
          playUrl: ep.playUrl,
          assets: ep.assets,
          quality: quality,
        );
        if (url.isEmpty) continue;

        final ctrl = PlayerFactory.create(
          url,
          allowBackgroundPlayback: allowBackgroundPlayback,
          headersProvider: headersProvider,
          urlTransformer: urlTransformer,
        );
        try {
          await PlayerFactory.initializeWithTimeout(
            ctrl,
            timeout: EpisodePlaybackStrategy.initializeTimeout,
          );
          await FeedPlaybackStrategy.warmFirstSeconds(
            ctrl,
            shouldAbort: () => _disposed || activeEpisodeId == episodeId,
          );
          if (_disposed || activeEpisodeId == episodeId) {
            PlaybackAudio.release(ctrl);
            ctrl.dispose();
            continue;
          }
          PlayerCache.put(
            episodeId: episodeId,
            url: url,
            quality: quality,
            controller: ctrl,
          );
          parkedVersion++;
          notifyListeners();
        } catch (_) {
          PlaybackAudio.release(ctrl);
          ctrl.dispose();
        }
      }
    }());
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

  Future<void> togglePlayPause() async {
    final ctrl = player;
    if (ctrl == null) return;
    if (ctrl.value.isPlaying) {
      await pause();
      showCenterPlay = true;
      showChrome = true;
      _hideChromeTimer?.cancel();
    } else {
      await play();
      showCenterPlay = false;
      _armChromeHide();
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

  Future<void> seekBy(Duration delta) async {
    final ctrl = player;
    if (ctrl == null) return;
    final next = ctrl.value.position + delta;
    final dur = ctrl.value.duration;
    final clamped = next < Duration.zero
        ? Duration.zero
        : (dur > Duration.zero && next > dur ? dur : next);
    await ctrl.seekTo(clamped);
  }

  void setBoosting(bool boosting) {
    isBoosting = boosting;
    final ctrl = player;
    if (ctrl != null) {
      unawaited(ctrl.setPlaybackSpeed(boosting ? 2.0 : playbackSpeed));
    }
    notifyListeners();
  }

  Future<void> setSpeed(double speed) async {
    playbackSpeed = speed;
    isBoosting = false;
    final ctrl = player;
    if (ctrl != null) {
      await ctrl.setPlaybackSpeed(speed);
    }
    notifyListeners();
  }

  /// Toggle forward-swipe lock while the active episode is still cold-starting.
  void setLockForwardWhileCold(bool value) {
    if (lockForwardWhileCold == value) return;
    lockForwardWhileCold = value;
    notifyListeners();
  }

  void toggleChrome() {
    showChrome = !showChrome;
    if (showChrome) {
      _armChromeHide();
    } else {
      _hideChromeTimer?.cancel();
    }
    notifyListeners();
  }

  void revealChrome() {
    showChrome = true;
    _armChromeHide();
    notifyListeners();
  }

  void _armChromeHide() {
    _hideChromeTimer?.cancel();
    _hideChromeTimer = Timer(const Duration(seconds: 4), () {
      if (_disposed || !isPlaying || isBoosting) return;
      showChrome = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    switchSeq++;
    _hideChromeTimer?.cancel();
    _cancelColdStartTimers();
    _parkActive();
    PlayerCache.silenceAll();
    PlaybackAudio.surfaceMayPlay = false;
    super.dispose();
  }
}
