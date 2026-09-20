import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_feed_player/flutter_feed_player.dart';

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

  test('EpisodeItem formatLabel detects HLS', () {
    const hls = EpisodeItem(
      playUrl: 'https://example.com/master.m3u8',
    );
    const mp4 = EpisodeItem(
      playUrl: 'https://example.com/a.mp4',
    );
    expect(hls.isHls, isTrue);
    expect(hls.formatLabel, 'HLS');
    expect(mp4.isHls, isFalse);
    expect(mp4.formatLabel, 'MP4');
  });
}
