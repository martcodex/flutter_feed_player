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
