// Shared playable models for feed and episode players.
// Host apps map their own DTOs into these types. No network client is included.

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

  bool get isHls {
    final t = assetType.toLowerCase();
    if (t == 'hls') return true;
    return url.toLowerCase().contains('.m3u8');
  }
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
    final url = resolvedPlayUrl.toLowerCase();
    if (url.contains('.m3u8')) return true;
    for (final a in assets) {
      if (a.isHls) return true;
    }
    return false;
  }

  /// Short format badge: `HLS` or `MP4`.
  String get formatLabel => isHls ? 'HLS' : 'MP4';

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

/// Optional HTTP headers / URL rewrite hooks for CDN auth.
typedef HttpHeadersProvider = Map<String, String> Function({
  required String url,
  required bool isHls,
});

typedef UrlTransformer = String Function(String url);
