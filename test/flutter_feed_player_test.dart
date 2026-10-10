import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_feed_player/flutter_feed_player.dart';
import 'package:video_player/video_player.dart';

void main() {
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

  test('MediaFormat platform support', () {
    expect(MediaFormat.isKindSupportedOnCurrentPlatform('mp4'), isTrue);
    expect(MediaFormat.isKindSupportedOnCurrentPlatform('hls'), isTrue);
  });
}
