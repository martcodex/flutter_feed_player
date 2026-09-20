import 'package:flutter_feed_player/flutter_feed_player.dart';

/// Catalog entry for the format showcase (MP4 / HLS groups).
class SampleClip {
  const SampleClip({
    required this.id,
    required this.title,
    required this.url,
    required this.format,
    required this.source,
    required this.description,
  });

  final String id;
  final String title;
  final String url;

  /// `mp4` or `hls`
  final String format;
  final String source;
  final String description;

  bool get isHls => format == 'hls' || url.toLowerCase().contains('.m3u8');

  String get formatLabel => isHls ? 'M3U8 / HLS' : 'MP4';
}

/// Open sample streams for demos — probed reachable (HTTP 200) where possible.
///
/// MP4: Flutter docs assets.
/// HLS: Mux test-streams + Apple developer HLS examples + Unified Streaming.
class MockVideos {
  static const bee =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
  static const butterfly =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

  /// Mux Big Buck Bunny adaptive HLS
  static const muxBunny =
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

  /// Mux Tears of Steel (ISMC)
  static const muxTears =
      'https://test-streams.mux.dev/tos_ismc/main.m3u8';

  /// Mux short test stream
  static const muxTest001 =
      'https://test-streams.mux.dev/test_001/stream.m3u8';

  /// Apple fMP4 advanced example
  static const appleFmp4 =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8';

  /// Apple TS advanced example
  static const appleTs =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

  /// Apple bipbop 16:9 variant playlist
  static const appleBipbop =
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8';

  /// Unified Streaming — Tears of Steel
  static const unifiedTears =
      'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8';

  static const covers = <String>[
    'https://picsum.photos/seed/feed1/720/1280',
    'https://picsum.photos/seed/feed2/720/1280',
    'https://picsum.photos/seed/feed3/720/1280',
    'https://picsum.photos/seed/feed4/720/1280',
    'https://picsum.photos/seed/feed5/720/1280',
    'https://picsum.photos/seed/feed6/720/1280',
    'https://picsum.photos/seed/feed7/720/1280',
    'https://picsum.photos/seed/feed8/720/1280',
    'https://picsum.photos/seed/series/720/1280',
  ];

  static const mp4Samples = <SampleClip>[
    SampleClip(
      id: 'mp4_bee',
      title: 'Bee',
      url: bee,
      format: 'mp4',
      source: 'Flutter docs',
      description: 'Short progressive MP4 from flutter.github.io.',
    ),
    SampleClip(
      id: 'mp4_butterfly',
      title: 'Butterfly',
      url: butterfly,
      format: 'mp4',
      source: 'Flutter docs',
      description: 'Short progressive MP4 — good for feed swipe demos.',
    ),
  ];

  static const hlsSamples = <SampleClip>[
    SampleClip(
      id: 'hls_mux_bunny',
      title: 'Big Buck Bunny',
      url: muxBunny,
      format: 'hls',
      source: 'Mux test-streams',
      description: 'Adaptive HLS (x36xhzz) hosted by Mux.',
    ),
    SampleClip(
      id: 'hls_mux_test',
      title: 'Mux Test 001',
      url: muxTest001,
      format: 'hls',
      source: 'Mux test-streams',
      description: 'Compact Mux HLS test playlist.',
    ),
    SampleClip(
      id: 'hls_mux_tears',
      title: 'Tears of Steel (Mux)',
      url: muxTears,
      format: 'hls',
      source: 'Mux test-streams',
      description: 'Open movie via Mux ISMC HLS.',
    ),
    SampleClip(
      id: 'hls_apple_fmp4',
      title: 'Apple BipBop fMP4',
      url: appleFmp4,
      format: 'hls',
      source: 'Apple HLS examples',
      description: 'Official Apple advanced fMP4 master playlist.',
    ),
    SampleClip(
      id: 'hls_apple_ts',
      title: 'Apple BipBop TS',
      url: appleTs,
      format: 'hls',
      source: 'Apple HLS examples',
      description: 'Official Apple advanced MPEG-TS master playlist.',
    ),
    SampleClip(
      id: 'hls_apple_bipbop',
      title: 'Apple BipBop 16:9',
      url: appleBipbop,
      format: 'hls',
      source: 'Apple HLS examples',
      description: 'Classic bipbop_16x9 variant playlist.',
    ),
    SampleClip(
      id: 'hls_unified_tears',
      title: 'Tears of Steel (Unified)',
      url: unifiedTears,
      format: 'hls',
      source: 'Unified Streaming',
      description: 'Public demo .ism/.m3u8 (open movie).',
    ),
  ];

  static List<SampleClip> get allSamples => [...mp4Samples, ...hlsSamples];
}

FeedItem _clipToFeedItem(SampleClip clip, int index) {
  final assetType = clip.isHls ? 'hls' : 'mp4';
  return FeedItem(
    id: '${clip.id}_$index',
    seriesId: 'demo_${clip.format}',
    title: clip.title,
    coverUrl: MockVideos.covers[index % MockVideos.covers.length],
    description: '${clip.description}\n${clip.source}',
    tags: [clip.formatLabel, clip.source],
    likeCount: 800 + index * 97,
    isLiked: false,
    ctaText: 'Watch full series',
    episode: EpisodeItem(
      episodeId: 'ep_${clip.id}_$index',
      episodeNo: 1,
      episodeLabel: clip.formatLabel,
      title: clip.title,
      coverUrl: MockVideos.covers[index % MockVideos.covers.length],
      description: clip.description,
      playUrl: clip.url,
      assets: [
        EpisodeAsset(
          assetType: assetType,
          quality: '720p',
          url: clip.url,
        ),
      ],
    ),
  );
}

/// Format filter for feed / episode mock loaders.
enum MockFormatFilter { all, mp4, hls }

/// Mock recommendation feed pages.
class MockFeedData {
  static List<SampleClip> clipsFor(MockFormatFilter filter) {
    switch (filter) {
      case MockFormatFilter.mp4:
        return MockVideos.mp4Samples;
      case MockFormatFilter.hls:
        return MockVideos.hlsSamples;
      case MockFormatFilter.all:
        return MockVideos.allSamples;
    }
  }

  static Future<List<FeedItem>> loadPage(
    int page, {
    int pageSize = 6,
    MockFormatFilter filter = MockFormatFilter.all,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final clips = clipsFor(filter);
  // Repeat short catalogs so swipe + pagination demos stay interesting.
    final expanded = <SampleClip>[
      for (var r = 0; r < 4; r++) ...clips,
    ];
    final start = (page - 1) * pageSize;
    if (start >= expanded.length) return const [];
    final end = (start + pageSize).clamp(0, expanded.length);
    final slice = expanded.sublist(start, end);
    return [
      for (var i = 0; i < slice.length; i++)
        _clipToFeedItem(slice[i], start + i),
    ];
  }

  static Future<List<FeedItem>> loadClips(List<SampleClip> clips) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return [
      for (var i = 0; i < clips.length; i++) _clipToFeedItem(clips[i], i),
    ];
  }
}

/// Mock series — mixes formats when [filter] is [MockFormatFilter.all].
class MockSeriesData {
  static List<EpisodeItem> _buildEpisodes(
    List<SampleClip> pool, {
    int repeat = 3,
  }) {
    final expanded = <SampleClip>[
      for (var r = 0; r < repeat; r++) ...pool,
    ];
    return [
      for (var i = 0; i < expanded.length; i++)
        EpisodeItem(
          episodeId: 'ocean_${expanded[i].id}_$i',
          episodeNo: i + 1,
          episodeLabel: 'EP.${i + 1} · ${expanded[i].formatLabel}',
          title: expanded[i].title,
          coverUrl: MockVideos.covers[i % MockVideos.covers.length],
          description: expanded[i].description,
          playUrl: expanded[i].url,
          assets: [
            EpisodeAsset(
              assetType: expanded[i].isHls ? 'hls' : 'mp4',
              quality: '720p',
              url: expanded[i].url,
            ),
          ],
        ),
    ];
  }

  static SeriesInfo _meta(MockFormatFilter filter) {
    return SeriesInfo(
      seriesId: 'mock_ocean_${filter.name}',
      title: switch (filter) {
        MockFormatFilter.mp4 => 'Ocean Notes (MP4)',
        MockFormatFilter.hls => 'Ocean Notes (HLS)',
        MockFormatFilter.all => 'Ocean Notes (Mixed)',
      },
      coverUrl: MockVideos.covers.last,
      description:
          'Mock series using free public sample streams. '
          'Swipe vertically between episodes. Pull down to refresh, '
          'pull up on the last episode to load more.',
    );
  }

  /// Full series (all pages). Prefer [loadOceanSeriesPage] for pagination demos.
  static Future<SeriesInfo> loadOceanSeries({
    MockFormatFilter filter = MockFormatFilter.all,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final clips = MockFeedData.clipsFor(filter);
    final pool = clips.isEmpty ? MockVideos.mp4Samples : clips;
    final meta = _meta(filter);
    return SeriesInfo(
      seriesId: meta.seriesId,
      title: meta.title,
      coverUrl: meta.coverUrl,
      description: meta.description,
      episodes: _buildEpisodes(pool),
    );
  }

  /// Paginated series loader — page starts at 1.
  static Future<SeriesInfo> loadOceanSeriesPage(
    int page, {
    int pageSize = 4,
    MockFormatFilter filter = MockFormatFilter.all,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final clips = MockFeedData.clipsFor(filter);
    final pool = clips.isEmpty ? MockVideos.mp4Samples : clips;
    final all = _buildEpisodes(pool);
    final start = (page - 1) * pageSize;
    final meta = _meta(filter);
    if (start >= all.length) {
      return SeriesInfo(
        seriesId: meta.seriesId,
        title: meta.title,
        coverUrl: meta.coverUrl,
        description: meta.description,
      );
    }
    final end = (start + pageSize).clamp(0, all.length);
    return SeriesInfo(
      seriesId: meta.seriesId,
      title: meta.title,
      coverUrl: meta.coverUrl,
      description: meta.description,
      episodes: all.sublist(start, end),
    );
  }
}
