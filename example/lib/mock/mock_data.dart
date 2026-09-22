import 'package:flutter/foundation.dart';
import 'package:flutter_feed_player/flutter_feed_player.dart';

/// Catalog entry for the format showcase.
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

  /// `mp4` | `hls` | `webm` | `mov` | `m4v` | `dash`
  final String format;
  final String source;
  final String description;

  bool get isHls =>
      format == 'hls' || url.toLowerCase().contains('.m3u8');

  String get formatLabel => MediaFormat.labelFor(
        url: url,
        assetType: format,
      );

  bool get isSupportedHere => MediaFormat.isKindSupportedOnCurrentPlatform(
        format,
      );
}

/// Format filter for feed / episode mock loaders and the home type list.
enum MockFormatFilter {
  mp4,
  hls,
  webm,
  mov,
  m4v,
  dash,
  all,
}

/// Demo catalog.
///
/// Network samples must support HTTP Range (AVPlayer requirement).
/// WebM stays as a bundled asset (Android / Web only).
class MockVideos {
  static const bee =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
  static const butterfly =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
  static const mdnFlowerMp4 =
      'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4';

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

  /// Unified Streaming — Tears of Steel HLS
  static const unifiedTears =
      'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8';

  /// SampleFile — H.264 yuv420p MOV with HTTP Range (AVPlayer-safe).
  static const samplefileMovH264 =
      'https://samplefile.com/samples/download/video/mov/mov_h264_aac_edit_sample.mov';

  /// TrueFileSize — H.264 baseline MOV, Accept-Ranges: bytes.
  static const truefilesizeMov5mb =
      'https://cdn.truefilesize.com/mov/sample-5mb.mov';

  /// SampleFile — public M4V samples (Range OK).
  static const samplefileM4v200 =
      'https://samplefile.com/samples/download/video/m4v/m4v_sample_file_200KB.m4v';
  static const samplefileM4v500 =
      'https://samplefile.com/samples/download/video/m4v/m4v_sample_file_500KB.m4v';

  /// Bundled WebM for Android / Web demos (AVPlayer cannot decode WebM).
  static const assetWebm = 'asset://assets/videos/flower.webm';

  static const dashEnvivio =
      'https://dash.akamaized.net/envivio/EnvivioDash3/manifest.mpd';
  static const dashBbb =
      'https://dash.akamaized.net/akamai/bbb_30fps/bbb_30fps.mpd';
  static const dashUnifiedTears =
      'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.mpd';

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
    SampleClip(
      id: 'mp4_mdn_flower',
      title: 'MDN Flower',
      url: mdnFlowerMp4,
      format: 'mp4',
      source: 'MDN',
      description: 'CC0 flower clip (progressive MP4, Range OK).',
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

  static const webmSamples = <SampleClip>[
    SampleClip(
      id: 'webm_flower_asset',
      title: 'Flower WebM (asset)',
      url: assetWebm,
      format: 'webm',
      source: 'Bundled asset',
      description: 'Local WebM — Android / Web only (AVPlayer cannot decode).',
    ),
  ];

  static const movSamples = <SampleClip>[
    SampleClip(
      id: 'mov_samplefile_h264',
      title: 'SampleFile H.264 MOV',
      url: samplefileMovH264,
      format: 'mov',
      source: 'SampleFile',
      description: 'Public QuickTime MOV (H.264 yuv420p, HTTP Range OK).',
    ),
    SampleClip(
      id: 'mov_truefilesize_5mb',
      title: 'TrueFileSize 5MB MOV',
      url: truefilesizeMov5mb,
      format: 'mov',
      source: 'TrueFileSize',
      description: 'Public H.264 baseline MOV (~5MB) with Accept-Ranges.',
    ),
  ];

  static const m4vSamples = <SampleClip>[
    SampleClip(
      id: 'm4v_samplefile_200',
      title: 'SampleFile M4V 200KB',
      url: samplefileM4v200,
      format: 'm4v',
      source: 'SampleFile',
      description: 'Public M4V sample with HTTP Range support.',
    ),
    SampleClip(
      id: 'm4v_samplefile_500',
      title: 'SampleFile M4V 500KB',
      url: samplefileM4v500,
      format: 'm4v',
      source: 'SampleFile',
      description: 'Public M4V sample (~500KB), Range OK.',
    ),
  ];

  static const dashSamples = <SampleClip>[
    SampleClip(
      id: 'dash_envivio',
      title: 'Envivio DASH',
      url: dashEnvivio,
      format: 'dash',
      source: 'Akamai DASH',
      description: 'Public Envivio DASH manifest — Android ExoPlayer.',
    ),
    SampleClip(
      id: 'dash_bbb',
      title: 'Big Buck Bunny DASH',
      url: dashBbb,
      format: 'dash',
      source: 'Akamai DASH',
      description: 'BBB 30fps multi-bitrate DASH — Android only.',
    ),
    SampleClip(
      id: 'dash_unified_tears',
      title: 'Tears of Steel (DASH)',
      url: dashUnifiedTears,
      format: 'dash',
      source: 'Unified Streaming',
      description: 'MPEG-DASH .mpd — Android only.',
    ),
  ];

  static List<SampleClip> get allCatalog => [
        ...mp4Samples,
        ...hlsSamples,
        ...movSamples,
        ...m4vSamples,
        ...webmSamples,
        ...dashSamples,
      ];

  /// Filters shown on the home list for the current platform.
  static List<MockFormatFilter> get availableFilters {
    final list = <MockFormatFilter>[
      MockFormatFilter.mp4,
      MockFormatFilter.hls,
      MockFormatFilter.mov,
      MockFormatFilter.m4v,
    ];
    if (MediaFormat.isKindSupportedOnCurrentPlatform('webm')) {
      list.add(MockFormatFilter.webm);
    }
    if (MediaFormat.isKindSupportedOnCurrentPlatform('dash')) {
      list.add(MockFormatFilter.dash);
    }
    list.add(MockFormatFilter.all);
    return list;
  }

  static List<SampleClip> clipsFor(MockFormatFilter filter) {
    final raw = switch (filter) {
      MockFormatFilter.mp4 => mp4Samples,
      MockFormatFilter.hls => hlsSamples,
      MockFormatFilter.webm => webmSamples,
      MockFormatFilter.mov => movSamples,
      MockFormatFilter.m4v => m4vSamples,
      MockFormatFilter.dash => dashSamples,
      MockFormatFilter.all => allCatalog,
    };
    return [
      for (final c in raw)
        if (c.isSupportedHere) c,
    ];
  }

  static String platformHint() {
    if (kIsWeb) {
      return 'Web: MP4 / HLS / WebM. DASH is not available via video_player.';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'iOS/macOS (AVPlayer): MP4 / HLS / MOV / M4V. '
            'WebM / DASH need Android.';
      case TargetPlatform.android:
        return 'Android (ExoPlayer): MP4 / HLS / MOV / M4V / WebM / DASH.';
      default:
        return 'Supported formats depend on the platform media engine.';
    }
  }
}

FeedItem _clipToFeedItem(SampleClip clip, int index) {
  final assetType = clip.format;
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

/// Mock recommendation feed pages.
class MockFeedData {
  static List<SampleClip> clipsFor(MockFormatFilter filter) =>
      MockVideos.clipsFor(filter);

  static Future<List<FeedItem>> loadPage(
    int page, {
    int pageSize = 6,
    MockFormatFilter filter = MockFormatFilter.all,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final clips = clipsFor(filter);
    if (clips.isEmpty) return const [];
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
              assetType: expanded[i].format,
              quality: '720p',
              url: expanded[i].url,
            ),
          ],
        ),
    ];
  }

  static SeriesInfo _meta(MockFormatFilter filter) {
    final label = switch (filter) {
      MockFormatFilter.mp4 => 'MP4',
      MockFormatFilter.hls => 'HLS',
      MockFormatFilter.webm => 'WebM',
      MockFormatFilter.mov => 'MOV',
      MockFormatFilter.m4v => 'M4V',
      MockFormatFilter.dash => 'DASH',
      MockFormatFilter.all => 'Mixed',
    };
    return SeriesInfo(
      seriesId: 'mock_ocean_${filter.name}',
      title: 'Ocean Notes ($label)',
      coverUrl: MockVideos.covers.last,
      description:
          'Mock series using free public / bundled sample streams. '
          'Swipe vertically between episodes. Pull down to refresh, '
          'pull up on the last episode to load more.',
    );
  }

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
