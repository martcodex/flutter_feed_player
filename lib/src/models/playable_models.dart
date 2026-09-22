// Shared playable models for feed and episode players.
// Host apps map their own DTOs into these types. No network client is included.

import 'package:flutter/foundation.dart';

/// Detects common stream / file formats from URL extension or asset type.
class MediaFormat {
  MediaFormat._();

  static String normalize(String? assetType, String url) {
    final type = (assetType ?? '').trim().toLowerCase();
    if (type == 'hls' || type == 'm3u8') return 'hls';
    if (type == 'dash' || type == 'mpd') return 'dash';
    if (type == 'webm' ||
        type == 'mov' ||
        type == 'm4v' ||
        type == 'mp4' ||
        type == 'ss') {
      return type;
    }
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return 'hls';
    if (lower.contains('.mpd')) return 'dash';
    if (lower.contains('.webm')) return 'webm';
    if (lower.contains('.mov')) return 'mov';
    if (lower.contains('.m4v')) return 'm4v';
    if (lower.contains('.mp4')) return 'mp4';
    if (type.isNotEmpty) return type;
    return 'other';
  }

  /// Short badge for chrome: `HLS`, `DASH`, `WebM`, `MOV`, `M4V`, `MP4`, …
  static String labelFor({String? assetType, required String url}) {
    return switch (normalize(assetType, url)) {
      'hls' => 'HLS',
      'dash' => 'DASH',
      'webm' => 'WebM',
      'mov' => 'MOV',
      'm4v' => 'M4V',
      'mp4' => 'MP4',
      'ss' => 'SS',
      'other' => 'Video',
      final other => other.toUpperCase(),
    };
  }

  static bool isHls({String? assetType, required String url}) =>
      normalize(assetType, url) == 'hls';

  static bool isDash({String? assetType, required String url}) =>
      normalize(assetType, url) == 'dash';

  static bool get _isAppleAvPlayer {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Whether [video_player] can typically decode this format on the current OS.
  ///
  /// iOS / macOS use AVPlayer (no WebM / DASH). Android uses ExoPlayer.
  /// Web depends on the browser; DASH is treated as unsupported there.
  static bool isSupportedOnCurrentPlatform({
    String? assetType,
    required String url,
  }) {
    return isKindSupportedOnCurrentPlatform(normalize(assetType, url));
  }

  static bool isKindSupportedOnCurrentPlatform(String kind) {
    switch (kind) {
      case 'hls':
      case 'mp4':
      case 'mov':
      case 'm4v':
      case 'other':
        return true;
      case 'webm':
        if (_isAppleAvPlayer) return false;
        return true;
      case 'dash':
      case 'ss':
        if (kIsWeb || _isAppleAvPlayer) return false;
        return true;
      default:
        return true;
    }
  }

  /// Human-readable reason when [isSupportedOnCurrentPlatform] is false.
  static String unsupportedReason({
    String? assetType,
    required String url,
  }) {
    final label = labelFor(assetType: assetType, url: url);
    if (kIsWeb) {
      return '$label is not supported in this browser via video_player.';
    }
    if (_isAppleAvPlayer) {
      return '$label is not supported on iOS/macOS (AVPlayer). Try Android.';
    }
    return '$label is not supported on this platform.';
  }
}

/// A single CDN / file asset for an episode clip.
class EpisodeAsset {
  final String assetType;
  final String quality;
  final String locale;
  final String url;

  const EpisodeAsset({
    this.assetType = 'hls',
    this.quality = '',
    this.locale = '',
    this.url = '',
  });

  bool get isHls => MediaFormat.isHls(assetType: assetType, url: url);

  bool get isDash => MediaFormat.isDash(assetType: assetType, url: url);

  String get formatLabel => MediaFormat.labelFor(assetType: assetType, url: url);
}

/// One episode within a series (or a feed clip that points at a series).
class EpisodeItem {
  final String episodeId;
  final int episodeNo;
  final String episodeLabel;
  final String title;
  final String coverUrl;
  final String description;
  final int durationSeconds;
  final List<EpisodeAsset> assets;
  final String playUrl;
  final Duration? startPosition;

  const EpisodeItem({
    this.episodeId = '',
    this.episodeNo = 0,
    this.episodeLabel = '',
    this.title = '',
    this.coverUrl = '',
    this.description = '',
    this.durationSeconds = 0,
    this.assets = const [],
    this.playUrl = '',
    this.startPosition,
  });

  String get resolvedPlayUrl {
    final explicit = playUrl.trim();
    if (explicit.isNotEmpty) return explicit;
    for (final a in assets) {
      if (a.url.trim().isNotEmpty) return a.url.trim();
    }
    return '';
  }

  /// True when the resolved URL / assets look like HLS.
  bool get isHls {
    if (MediaFormat.isHls(url: resolvedPlayUrl)) return true;
    for (final a in assets) {
      if (a.isHls) return true;
    }
    return false;
  }

  /// True when the resolved URL / assets look like MPEG-DASH.
  bool get isDash {
    if (MediaFormat.isDash(url: resolvedPlayUrl)) return true;
    for (final a in assets) {
      if (a.isDash) return true;
    }
    return false;
  }

  /// Short format badge: `HLS`, `DASH`, `WebM`, `MOV`, `MP4`, …
  String get formatLabel {
    final url = resolvedPlayUrl;
    if (url.isNotEmpty) {
      return MediaFormat.labelFor(url: url);
    }
    for (final a in assets) {
      if (a.url.trim().isNotEmpty) return a.formatLabel;
    }
    return 'Video';
  }

  String get displayLabel {
    final label = episodeLabel.trim();
    if (label.isNotEmpty) return label;
    if (episodeNo > 0) return 'EP.$episodeNo';
    return title;
  }

  EpisodeItem copyWith({
    String? episodeId,
    int? episodeNo,
    String? episodeLabel,
    String? title,
    String? coverUrl,
    String? description,
    int? durationSeconds,
    List<EpisodeAsset>? assets,
    String? playUrl,
    Duration? startPosition,
  }) {
    return EpisodeItem(
      episodeId: episodeId ?? this.episodeId,
      episodeNo: episodeNo ?? this.episodeNo,
      episodeLabel: episodeLabel ?? this.episodeLabel,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      assets: assets ?? this.assets,
      playUrl: playUrl ?? this.playUrl,
      startPosition: startPosition ?? this.startPosition,
    );
  }
}

/// Series metadata for the episode binge player.
class SeriesInfo {
  final String seriesId;
  final String title;
  final String coverUrl;
  final String description;
  final List<EpisodeItem> episodes;

  const SeriesInfo({
    this.seriesId = '',
    this.title = '',
    this.coverUrl = '',
    this.description = '',
    this.episodes = const [],
  });
}

/// One card in a vertical recommendation / For You feed.
class FeedItem {
  final String id;
  final String seriesId;
  final String title;
  final String coverUrl;
  final String description;
  final List<String> tags;
  final int likeCount;
  final bool isLiked;
  final EpisodeItem episode;
  final String ctaText;

  const FeedItem({
    this.id = '',
    this.seriesId = '',
    this.title = '',
    this.coverUrl = '',
    this.description = '',
    this.tags = const [],
    this.likeCount = 0,
    this.isLiked = false,
    this.episode = const EpisodeItem(),
    this.ctaText = 'Watch full series',
  });

  String get identity {
    if (id.isNotEmpty) return id;
    final ep = episode.episodeId;
    if (seriesId.isNotEmpty && ep.isNotEmpty) return '${seriesId}_$ep';
    if (seriesId.isNotEmpty && episode.episodeNo > 0) {
      return '${seriesId}_ep_${episode.episodeNo}';
    }
    return '';
  }

  String get playUrl => episode.resolvedPlayUrl;

  bool get isHls => episode.isHls;

  bool get isDash => episode.isDash;

  String get formatLabel => episode.formatLabel;

  FeedItem copyWith({
    String? id,
    String? seriesId,
    String? title,
    String? coverUrl,
    String? description,
    List<String>? tags,
    int? likeCount,
    bool? isLiked,
    EpisodeItem? episode,
    String? ctaText,
  }) {
    return FeedItem(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      episode: episode ?? this.episode,
      ctaText: ctaText ?? this.ctaText,
    );
  }
}

/// Optional hooks for authenticated / regional CDNs.
typedef HttpHeadersProvider = Map<String, String> Function({
  required String url,
  required bool isHls,
});

typedef UrlTransformer = String Function(String url);
