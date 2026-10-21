import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../models/playable_models.dart';
import 'hls_quality_url.dart';
import 'playback_audio.dart';

/// Shared [VideoPlayerController] construction for feed / episode players.
class PlayerFactory {
  PlayerFactory._();

  /// Flutter asset scheme used by demos: `asset://assets/videos/foo.mov`
  static const String assetScheme = 'asset://';

  static bool isHlsUrl(String url) => MediaFormat.isHls(url: url);

  static bool isDashUrl(String url) => MediaFormat.isDash(url: url);

  static bool isAssetUrl(String url) {
    final u = url.trim();
    return u.startsWith(assetScheme) || u.startsWith('assets/');
  }

  static String assetPathFromUrl(String url) {
    final u = url.trim();
    if (u.startsWith(assetScheme)) {
      return u.substring(assetScheme.length);
    }
    return u;
  }

  static bool isFileUrl(String url) {
    final u = url.trim().toLowerCase();
    return u.startsWith('file:');
  }

  /// Maps URL / extension to [VideoFormat] hint for [VideoPlayerController].
  ///
  /// DASH / Smooth Streaming hints are only useful on Android (ExoPlayer).
  static VideoFormat formatHintForUrl(String url) {
    final kind = MediaFormat.normalize(null, url);
    final apple = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    return switch (kind) {
      'hls' => VideoFormat.hls,
      'dash' => (kIsWeb || apple) ? VideoFormat.other : VideoFormat.dash,
      'ss' => (kIsWeb || apple) ? VideoFormat.other : VideoFormat.ss,
      _ => VideoFormat.other,
    };
  }

  static bool isOfflineVideoError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('internet connection appears to be offline') ||
        text.contains('notconnectedtointernet') ||
        text.contains('network connection was lost') ||
        text.contains('the internet connection appears to be offline') ||
        text.contains('failed host lookup') ||
        text.contains('socketexception') ||
        text.contains('network is unreachable') ||
        text.contains('errno = 51') ||
        text.contains('errno = 8');
  }

  static Future<void> settleAfterReconnect() =>
      Future<void>.delayed(const Duration(milliseconds: 700));

  /// Fragment is not sent to the CDN; it changes AVURLAsset cache identity
  /// so a previous offline failure does not stick to later players.
  static String bustNativeAssetCache(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return trimmed;
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    final existing = uri.fragment;
    final fragment = (existing.isEmpty || existing.startsWith('np='))
        ? 'np=$nonce'
        : '$existing&np=$nonce';
    return uri.replace(fragment: fragment).toString();
  }

  static Map<String, String> defaultNetworkHeaders({
    required bool isHls,
  }) {
    if (isHls) return const <String, String>{};
    // Empty headers: some CDNs mishandle custom UA + Range together.
    // Host apps can still inject via [HttpHeadersProvider].
    return const <String, String>{};
  }

  /// iOS picture-in-picture needs an [AVPlayerLayer], which [video_player]
  /// only creates for [VideoViewType.platformView]. Android PiP shows the
  /// Flutter texture, so it stays on [VideoViewType.textureView].
  static VideoViewType viewTypeFor({required bool pictureInPicture}) {
    if (!pictureInPicture || kIsWeb) return VideoViewType.textureView;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return VideoViewType.platformView;
    }
    return VideoViewType.textureView;
  }

  /// Creates a controller for network / asset / file URLs.
  static VideoPlayerController create(
    String url, {
    required bool allowBackgroundPlayback,
    bool mixWithOthers = false,
    bool bustAssetCache = false,
    bool preserveHlsVariant = false,
    HttpHeadersProvider? headersProvider,
    UrlTransformer? urlTransformer,
    VideoViewType viewType = VideoViewType.textureView,
  }) {
    final trimmed = (urlTransformer?.call(url.trim()) ?? url).trim();
    if (isAssetUrl(trimmed)) {
      return asset(
        assetPathFromUrl(trimmed),
        allowBackgroundPlayback: allowBackgroundPlayback,
        mixWithOthers: mixWithOthers,
        viewType: viewType,
      );
    }
    if (!kIsWeb && isFileUrl(trimmed)) {
      return localFile(
        File(Uri.parse(trimmed).toFilePath()),
        allowBackgroundPlayback: allowBackgroundPlayback,
        mixWithOthers: mixWithOthers,
        viewType: viewType,
      );
    }
    return network(
      trimmed,
      allowBackgroundPlayback: allowBackgroundPlayback,
      mixWithOthers: mixWithOthers,
      bustAssetCache: bustAssetCache,
      preserveHlsVariant: preserveHlsVariant,
      headersProvider: headersProvider,
      urlTransformer: null, // already applied
      viewType: viewType,
    );
  }

  static VideoPlayerController asset(
    String assetPath, {
    required bool allowBackgroundPlayback,
    bool mixWithOthers = false,
    VideoViewType viewType = VideoViewType.textureView,
    String? package,
  }) {
    return PlaybackAudio.track(
      VideoPlayerController.asset(
        assetPath,
        package: package,
        viewType: viewType,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: mixWithOthers,
          allowBackgroundPlayback: allowBackgroundPlayback,
        ),
      ),
    );
  }

  static VideoPlayerController network(
    String url, {
    required bool allowBackgroundPlayback,
    bool mixWithOthers = false,
    bool bustAssetCache = false,
    bool preserveHlsVariant = false,
    HttpHeadersProvider? headersProvider,
    UrlTransformer? urlTransformer,
    VideoViewType viewType = VideoViewType.textureView,
  }) {
    var trimmed = (urlTransformer?.call(url.trim()) ?? url).trim();
    if (!preserveHlsVariant && HlsQualityUrl.isConvertible(trimmed)) {
      trimmed = HlsQualityUrl.toMaster(trimmed);
    }
    if (bustAssetCache) {
      trimmed = bustNativeAssetCache(trimmed);
    }
    final hls = isHlsUrl(trimmed);
    final headers = headersProvider?.call(url: trimmed, isHls: hls) ??
        defaultNetworkHeaders(isHls: hls);
    return PlaybackAudio.track(
      VideoPlayerController.networkUrl(
        Uri.parse(trimmed),
        formatHint: formatHintForUrl(trimmed),
        httpHeaders: headers,
        viewType: viewType,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: mixWithOthers,
          allowBackgroundPlayback: allowBackgroundPlayback,
        ),
      ),
    );
  }

  static VideoPlayerController localFile(
    File file, {
    required bool allowBackgroundPlayback,
    bool mixWithOthers = false,
    VideoViewType viewType = VideoViewType.textureView,
  }) {
    return PlaybackAudio.track(
      VideoPlayerController.file(
        file,
        viewType: viewType,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: mixWithOthers,
          allowBackgroundPlayback: allowBackgroundPlayback,
        ),
      ),
    );
  }

  static bool sameQuality(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  /// Labels for the quality sheet: `Auto` plus explicit assets, or the HLS
  /// rendition ladder when the URL uses `/master.m3u8` / `/v{n}/index.m3u8`.
  ///
  /// A single progressive file returns an empty list (nothing to switch).
  static List<String> qualityOptionsFor({
    required String playUrl,
    required List<EpisodeAsset> assets,
  }) {
    final labeled = <String>[];
    final seen = <String>{};
    for (final asset in assets) {
      final q = asset.quality.trim();
      if (q.isEmpty || asset.url.trim().isEmpty) continue;
      if (HlsQualityUrl.isAuto(q)) continue;
      if (seen.add(q.toLowerCase())) labeled.add(q);
    }
    labeled.sort((a, b) {
      final ha = HlsQualityUrl.parseHeight(a);
      final hb = HlsQualityUrl.parseHeight(b);
      if (ha != null && hb != null) return hb.compareTo(ha);
      if (ha != null) return -1;
      if (hb != null) return 1;
      return 0;
    });
    if (labeled.length >= 2) {
      return ['Auto', ...labeled];
    }

    var raw = playUrl.trim();
    if (raw.isEmpty) {
      for (final asset in assets) {
        final u = asset.url.trim();
        if (u.isNotEmpty) {
          raw = u;
          break;
        }
      }
    }
    if (raw.isNotEmpty && HlsQualityUrl.isConvertible(raw)) {
      return ['Auto', ...HlsQualityUrl.renditionLadder];
    }
    return const [];
  }

  /// Resolve best playable URL from assets.
  ///
  /// `Auto` prefers [playUrl] and normalizes convertible HLS to `master.m3u8`.
  /// A named quality uses the matching [EpisodeAsset], or rewrites a
  /// convertible HLS URL to `/v{height}/index.m3u8`.
  static String resolvePlayUrl({
    required String playUrl,
    required List<EpisodeAsset> assets,
    String quality = 'Auto',
  }) {
    EpisodeAsset? pickHls() {
      for (final a in assets) {
        final u = a.url.trim();
        if (u.isEmpty) continue;
        if (a.isHls) return a;
      }
      return null;
    }

    EpisodeAsset? pickByQuality(String q) {
      if (HlsQualityUrl.isAuto(q)) return null;
      for (final a in assets) {
        if (a.url.trim().isEmpty) continue;
        if (sameQuality(a.quality, q)) return a;
      }
      return null;
    }

    final matched = pickByQuality(quality);
    if (matched != null) return matched.url.trim();

    final hls = pickHls();
    var raw = playUrl.trim();
    if (raw.isEmpty) {
      raw = hls?.url.trim() ?? '';
    }
    if (raw.isEmpty) {
      for (final a in assets) {
        final u = a.url.trim();
        if (u.isNotEmpty) {
          raw = u;
          break;
        }
      }
    }
    if (raw.isEmpty) return '';
    if (HlsQualityUrl.isConvertible(raw)) {
      raw = HlsQualityUrl.resolve(raw, quality);
    }
    return raw;
  }

  static Future<void> initializeWithTimeout(
    VideoPlayerController controller, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      await controller.initialize().timeout(timeout);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[PlayerFactory] initialize failed: $e\n$st');
      }
      rethrow;
    }
  }
}
