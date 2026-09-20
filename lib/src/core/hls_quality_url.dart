/// HLS playlist URL helpers.
///
/// Prefer `.../master.m3u8` as the only playback entry when CDN uses
/// variant paths like `.../v720/index.m3u8`.
class HlsQualityUrl {
  HlsQualityUrl._();

  static final RegExp _masterSuffix = RegExp(
    r'/master\.m3u8(?=[?#]|$)',
    caseSensitive: false,
  );
  static final RegExp _variantSuffix = RegExp(
    r'/v\d+/index\.m3u8(?=[?#]|$)',
    caseSensitive: false,
  );
  static final RegExp _heightInQuality = RegExp(r'(\d{3,4})');

  static String resolve(String url, String quality) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    return toMaster(trimmed);
  }

  static bool isAuto(String quality) {
    final q = quality.trim().toLowerCase();
    return q.isEmpty || q == 'auto';
  }

  static int? parseHeight(String quality) {
    if (isAuto(quality)) return null;
    final match = _heightInQuality.firstMatch(quality.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Square side length for preferred maximum resolution (portrait-safe).
  static double? preferredMaximumSideFor(String quality) {
    final height = parseHeight(quality);
    if (height == null) return null;
    if (height <= 360) return 640;
    if (height <= 480) return 854;
    if (height <= 720) return 1280;
    return 1920;
  }

  static String toVariant(String url, int height) {
    if (height <= 0) return url;
    final target = '/v$height/index.m3u8';
    if (_masterSuffix.hasMatch(url)) {
      return url.replaceFirst(_masterSuffix, target);
    }
    if (_variantSuffix.hasMatch(url)) {
      return url.replaceFirst(_variantSuffix, target);
    }
    return url;
  }

  static String toMaster(String url) {
    if (_variantSuffix.hasMatch(url)) {
      return url.replaceFirst(_variantSuffix, '/master.m3u8');
    }
    return url;
  }

  static bool isConvertible(String url) {
    return _masterSuffix.hasMatch(url) || _variantSuffix.hasMatch(url);
  }

  static bool isHlsPlaylist(String url) {
    return url.toLowerCase().contains('.m3u8');
  }
}
