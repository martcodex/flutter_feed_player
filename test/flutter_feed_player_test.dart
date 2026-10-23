import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_feed_player/flutter_feed_player.dart';
import 'package:flutter_feed_player/src/core/playback_pip.dart';
import 'package:video_player/video_player.dart';

void main() {
  test('picture in picture only while playback is running', () {
    expect(
      PlaybackPip.shouldEnter(enabled: true, playing: true, userPaused: false),
      isTrue,
    );
    expect(
      PlaybackPip.shouldEnter(enabled: true, playing: false, userPaused: true),
      isFalse,
    );
    expect(
      PlaybackPip.shouldEnter(enabled: true, playing: true, userPaused: true),
      isFalse,
    );
    expect(
      PlaybackPip.shouldEnter(
        enabled: false,
        playing: true,
        userPaused: false,
      ),
      isFalse,
    );
  });

  test('only a large window resize pins the page', () {
    expect(
      PlaybackPip.sizeChangeShouldPin(
        const Size(1080, 2400),
        const Size(1080, 2400),
      ),
      isFalse,
    );
    expect(
      PlaybackPip.sizeChangeShouldPin(
        const Size(1080, 2400),
        const Size(1080, 2300),
      ),
      isFalse,
    );
    expect(
      PlaybackPip.sizeChangeShouldPin(
        const Size(1080, 2400),
        const Size(480, 640),
      ),
      isTrue,
    );
    expect(
      PlaybackPip.sizeChangeShouldPin(Size.zero, const Size(1080, 2400)),
      isFalse,
    );
  });

  test('background page changes are ignored', () {
    expect(
      PlaybackPip.shouldIgnorePageChange(
        programmatic: false,
        blockPaging: false,
        lifecycleResumed: false,
      ),
      isTrue,
    );
    expect(
      PlaybackPip.shouldIgnorePageChange(
        programmatic: true,
        blockPaging: true,
        lifecycleResumed: false,
      ),
      isTrue,
    );
    expect(
      PlaybackPip.shouldIgnorePageChange(
        programmatic: true,
        blockPaging: true,
        lifecycleResumed: true,
      ),
      isFalse,
    );
    expect(
      PlaybackPip.shouldIgnorePageChange(
        programmatic: false,
        blockPaging: true,
        lifecycleResumed: true,
      ),
      isTrue,
    );
  });

  test('FeedItem identity prefers id', () {
    const item = FeedItem(
      id: 'a',
      seriesId: 's1',
      episode: EpisodeItem(episodeId: 'e1'),
    );
    expect(item.identity, 'a');
  });

  test('EpisodeItem resolvedPlayUrl falls back to assets', () {
    const ep = EpisodeItem(
      assets: [
        EpisodeAsset(url: 'https://example.com/a.mp4', assetType: 'mp4'),
      ],
    );
    expect(ep.resolvedPlayUrl, 'https://example.com/a.mp4');
  });

  test('HlsQualityUrl toMaster', () {
    expect(
      HlsQualityUrl.toMaster('https://cdn.example/v720/index.m3u8'),
      'https://cdn.example/master.m3u8',
    );
  });

  test('resolvePlayUrl honors quality assets and HLS variants', () {
    const assets = [
      EpisodeAsset(
        quality: '720p',
        url: 'https://cdn.example/720.mp4',
        assetType: 'mp4',
      ),
      EpisodeAsset(
        quality: '480p',
        url: 'https://cdn.example/480.mp4',
        assetType: 'mp4',
      ),
    ];
    expect(
      PlayerFactory.resolvePlayUrl(
        playUrl: 'https://cdn.example/master.mp4',
        assets: assets,
        quality: '480p',
      ),
      'https://cdn.example/480.mp4',
    );
    expect(
      PlayerFactory.resolvePlayUrl(
        playUrl: 'https://cdn.example/v720/index.m3u8',
        assets: const [],
        quality: 'Auto',
      ),
      'https://cdn.example/master.m3u8',
    );
    expect(
      PlayerFactory.resolvePlayUrl(
        playUrl: 'https://cdn.example/master.m3u8',
        assets: const [],
        quality: '480p',
      ),
      'https://cdn.example/v480/index.m3u8',
    );
    expect(
      PlayerFactory.qualityOptionsFor(
        playUrl: 'https://cdn.example/a.mp4',
        assets: assets,
      ),
      ['Auto', '720p', '480p'],
    );
    expect(
      PlayerFactory.qualityOptionsFor(
        playUrl: 'https://cdn.example/a.mp4',
        assets: const [
          EpisodeAsset(quality: '720p', url: 'https://cdn.example/a.mp4'),
        ],
      ),
      isEmpty,
    );
    expect(
      PlayerFactory.qualityOptionsFor(
        playUrl: 'https://cdn.example/master.m3u8',
        assets: const [],
      ),
      ['Auto', ...HlsQualityUrl.renditionLadder],
    );
  });

  test('EpisodeItem formatLabel detects common formats', () {
    const hls = EpisodeItem(
      playUrl: 'https://example.com/master.m3u8',
    );
    const mp4 = EpisodeItem(
      playUrl: 'https://example.com/a.mp4',
    );
    const webm = EpisodeItem(
      playUrl: 'https://example.com/a.webm',
    );
    const dash = EpisodeItem(
      playUrl: 'https://example.com/manifest.mpd',
    );
    const mov = EpisodeItem(
      playUrl: 'https://example.com/clip.mov',
    );
    expect(hls.isHls, isTrue);
    expect(hls.formatLabel, 'HLS');
    expect(mp4.isHls, isFalse);
    expect(mp4.formatLabel, 'MP4');
    expect(webm.formatLabel, 'WebM');
    expect(dash.isDash, isTrue);
    expect(dash.formatLabel, 'DASH');
    expect(mov.formatLabel, 'MOV');
  });

  test('PlayerFactory formatHintForUrl', () {
    expect(
      PlayerFactory.formatHintForUrl('https://x/a.m3u8'),
      VideoFormat.hls,
    );
    expect(
      PlayerFactory.formatHintForUrl('https://x/a.mp4'),
      VideoFormat.other,
    );
  });

  test('PlayerFactory asset URL helpers', () {
    expect(PlayerFactory.isAssetUrl('asset://assets/videos/a.mov'), isTrue);
    expect(
      PlayerFactory.assetPathFromUrl('asset://assets/videos/a.mov'),
      'assets/videos/a.mov',
    );
    expect(PlayerFactory.isAssetUrl('https://x/a.mp4'), isFalse);
  });

  test('landscape layout is 16:9 or wider than tall', () {
    expect(LandscapeVideoLayout.isWide(const Size(1920, 1080)), isTrue);
    expect(LandscapeVideoLayout.isWide(const Size(16, 9)), isTrue);
    expect(LandscapeVideoLayout.isWide(const Size(4, 3)), isTrue);
    expect(LandscapeVideoLayout.isWide(const Size(1080, 1920)), isFalse);
    expect(LandscapeVideoLayout.isWide(const Size(9, 16)), isFalse);
    expect(LandscapeVideoLayout.isWide(const Size(1000, 1000)), isFalse);
    expect(LandscapeVideoLayout.isWide(Size.zero), isFalse);

    final rect = LandscapeVideoLayout.frame(
      viewport: const Size(390, 844),
      aspectRatio: 16 / 9,
      padding: const EdgeInsets.only(top: 47),
    );
    expect(rect.width / rect.height, closeTo(16 / 9, 0.02));
    expect(rect.center.dy, closeTo(422, 1));
    expect(rect.center.dx, closeTo(195, 1));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(390));
  });

  test('MediaFormat platform support', () {
    expect(MediaFormat.isKindSupportedOnCurrentPlatform('mp4'), isTrue);
    expect(MediaFormat.isKindSupportedOnCurrentPlatform('hls'), isTrue);
  });
}
