import 'dart:collection';

import 'package:video_player/video_player.dart';

import 'feed_playback_strategy.dart';
import 'playback_audio.dart';
import 'playback_memory.dart';

/// Cached parked player entry for episode binge.
class CachedPlayer {
  final String episodeId;
  final String url;
  final String quality;
  final VideoPlayerController controller;

  CachedPlayer({
    required this.episodeId,
    required this.url,
    required this.quality,
    required this.controller,
  });
}

/// Process-level episode player cache (survives leaving the page briefly).
class PlayerCache {
  PlayerCache._();

  static final LinkedHashMap<String, CachedPlayer> _players =
      LinkedHashMap<String, CachedPlayer>();

  static int get maxParked => PlaybackMemory.episodeMaxParked;

  static VideoPlayerController? peek(String episodeId) {
    return _players[episodeId]?.controller;
  }

  static CachedPlayer? peekEntry(String episodeId) => _players[episodeId];

  /// Claim a parked controller for active playback (removes from cache).
  static VideoPlayerController? take(String episodeId) {
    final entry = _players.remove(episodeId);
    return entry?.controller;
  }

  static CachedPlayer? takeEntry(String episodeId) =>
      _players.remove(episodeId);

  /// Park without seeking — seeking parked HLS on iOS blacks the texture.
  static void put({
    required String episodeId,
    required String url,
    required String quality,
    required VideoPlayerController controller,
  }) {
    final existing = _players.remove(episodeId);
    if (existing != null && !identical(existing.controller, controller)) {
      PlaybackAudio.release(existing.controller);
      existing.controller.dispose();
    }
    PlaybackAudio.silence(controller);
    _players[episodeId] = CachedPlayer(
      episodeId: episodeId,
      url: url,
      quality: quality,
      controller: controller,
    );
    _trim();
  }

  static void silenceAll() {
    for (final e in _players.values) {
      PlaybackAudio.silence(e.controller);
    }
  }

  static void clear() {
    for (final e in List<CachedPlayer>.from(_players.values)) {
      PlaybackAudio.release(e.controller);
      e.controller.dispose();
    }
    _players.clear();
  }

  static void _trim() {
    while (_players.length > maxParked) {
      final oldestKey = _players.keys.first;
      final removed = _players.remove(oldestKey);
      if (removed == null) break;
      PlaybackAudio.release(removed.controller);
      removed.controller.dispose();
    }
  }

  /// Feed-style in-memory park map helpers.
  static bool isReusable(VideoPlayerController? ctrl) =>
      FeedPlaybackStrategy.isReusablePlayer(ctrl);

  static bool hasPaintedSize(VideoPlayerController? ctrl) =>
      FeedPlaybackStrategy.hasPaintedSize(ctrl);
}
