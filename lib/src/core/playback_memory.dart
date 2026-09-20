import 'dart:io';

import 'package:flutter/foundation.dart';

/// Device RAM / heap budget for player parking and caches.
class PlaybackMemory {
  PlaybackMemory._();

  static const int _lowRamMb = 3072;
  static const int _midRamMb = 5632;

  static int _totalRamMb = 8192;
  static bool _ready = false;

  static bool get isReady => _ready;
  static bool get isLow => _totalRamMb < _lowRamMb;
  static bool get isHigh => _totalRamMb >= _midRamMb;

  static Future<void> init() async {
    if (_ready) return;
    if (kIsWeb) {
      _ready = true;
      return;
    }
    if (Platform.isAndroid) {
      _totalRamMb = await _androidMemTotalMb() ?? 4096;
    } else {
      _totalRamMb = 8192;
    }
    _ready = true;
    debugPrint(
      '[PlaybackMemory] ram=${_totalRamMb}MB '
      'tier=${isLow ? 'low' : isHigh ? 'high' : 'mid'}',
    );
  }

  static Future<int?> _androidMemTotalMb() async {
    try {
      final lines = await File('/proc/meminfo').readAsLines();
      for (final line in lines) {
        if (!line.startsWith('MemTotal:')) continue;
        final kb = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
        if (kb == null || kb <= 0) return null;
        return kb ~/ 1024;
      }
    } catch (e) {
      debugPrint('[PlaybackMemory] meminfo: $e');
    }
    return null;
  }

  static int get feedKeepBehind {
    if (isLow) return 8;
    if (isHigh) return 16;
    return 12;
  }

  static int get feedMaxHistoryParked => feedKeepBehind;

  static int get feedMaxConcurrentPlayers {
    if (isLow) return 6;
    if (isHigh) return 10;
    return 8;
  }

  static int get episodePreloadAhead => 2;

  static int get episodeMaxParked {
    if (isLow) return 5;
    if (isHigh) return 8;
    return 6;
  }
}
