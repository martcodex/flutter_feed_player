import 'package:flutter/material.dart';

import '../mock/mock_data.dart';

/// Supported demo languages.
enum DemoLang {
  zh,
  en,
  ja;

  String get label => switch (this) {
        DemoLang.zh => '中',
        DemoLang.en => 'EN',
        DemoLang.ja => '日',
      };

  Locale get locale => switch (this) {
        DemoLang.zh => const Locale('zh'),
        DemoLang.en => const Locale('en'),
        DemoLang.ja => const Locale('ja'),
      };
}

/// Holds the active [DemoLang] and notifies listeners on change.
class DemoLocaleController extends ChangeNotifier {
  DemoLocaleController([this._lang = DemoLang.zh]);

  DemoLang _lang;

  DemoLang get lang => _lang;

  DemoL10n get l10n => DemoL10n(_lang);

  void setLang(DemoLang lang) {
    if (_lang == lang) return;
    _lang = lang;
    notifyListeners();
  }
}

/// Access [DemoLocaleController] / [DemoL10n] from the widget tree.
class DemoLocaleScope extends InheritedNotifier<DemoLocaleController> {
  const DemoLocaleScope({
    super.key,
    required DemoLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static DemoLocaleController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<DemoLocaleScope>();
    assert(scope != null, 'DemoLocaleScope not found');
    return scope!.notifier!;
  }

  static DemoL10n l10nOf(BuildContext context) => of(context).l10n;
}

/// Demo UI strings for [DemoLang].
class DemoL10n {
  const DemoL10n(this.lang);

  final DemoLang lang;

  String get appTitle => 'flutter_feed_player demo';

  String get brandName => 'flutter_feed_player';

  String get tagline => switch (lang) {
        DemoLang.zh =>
          '按平台展示可播格式：MP4 / HLS / MOV / M4V（WebM·DASH 仅 Android）。',
        DemoLang.en =>
          'Platform-aware demos: MP4 / HLS / MOV / M4V (WebM·DASH on Android).',
        DemoLang.ja =>
          '対応形式：MP4 / HLS / MOV / M4V（WebM·DASH は Android）。',
      };

  String get selectVideoType => switch (lang) {
        DemoLang.zh => '选择视频类型',
        DemoLang.en => 'Select video type',
        DemoLang.ja => '動画タイプを選択',
      };

  String get introHint => switch (lang) {
        DemoLang.zh =>
          '先选中一种格式，再进入推荐流或剧集。'
              '列表已按当前系统过滤不支持的格式。',
        DemoLang.en =>
          'Pick a format, then open feed or episodes. '
              'Unsupported formats for this OS are hidden.',
        DemoLang.ja =>
          '形式を選んでからフィード / エピソードを開きます。'
              '現在の OS で非対応の形式は非表示です。',
      };

  String videoTypeTitle(MockFormatFilter filter) => switch (filter) {
        MockFormatFilter.mp4 => 'MP4',
        MockFormatFilter.hls => 'M3U8 / HLS',
        MockFormatFilter.webm => 'WebM',
        MockFormatFilter.mov => 'MOV',
        MockFormatFilter.m4v => 'M4V',
        MockFormatFilter.dash => 'DASH (.mpd)',
        MockFormatFilter.all => switch (lang) {
            DemoLang.zh => '混合（本机可播）',
            DemoLang.en => 'Mixed (supported here)',
            DemoLang.ja => '混合（対応分）',
          },
      };

  String videoTypeSubtitle(MockFormatFilter filter, int count) {
    final n = switch (lang) {
      DemoLang.zh => '$count 个样例',
      DemoLang.en => '$count samples',
      DemoLang.ja => '$count サンプル',
    };
    final hint = switch (filter) {
      MockFormatFilter.mp4 => switch (lang) {
          DemoLang.zh => '网络渐进式 · Flutter / MDN',
          DemoLang.en => 'Network progressive · Flutter / MDN',
          DemoLang.ja => 'ネットワーク · Flutter / MDN',
        },
      MockFormatFilter.hls => switch (lang) {
          DemoLang.zh => '自适应流 · Mux / Apple / Unified',
          DemoLang.en => 'Adaptive · Mux / Apple / Unified',
          DemoLang.ja => 'アダプティブ · Mux / Apple / Unified',
        },
      MockFormatFilter.webm => switch (lang) {
          DemoLang.zh => '本地 asset · 仅 Android / Web',
          DemoLang.en => 'Bundled asset · Android / Web only',
          DemoLang.ja => '同梱 asset · Android / Web のみ',
        },
      MockFormatFilter.mov => switch (lang) {
          DemoLang.zh => '网络 · SampleFile / TrueFileSize',
          DemoLang.en => 'Network · SampleFile / TrueFileSize',
          DemoLang.ja => 'ネットワーク · SampleFile / TrueFileSize',
        },
      MockFormatFilter.m4v => switch (lang) {
          DemoLang.zh => '网络 · SampleFile',
          DemoLang.en => 'Network · SampleFile',
          DemoLang.ja => 'ネットワーク · SampleFile',
        },
      MockFormatFilter.dash => switch (lang) {
          DemoLang.zh => '网络 · 仅 Android ExoPlayer',
          DemoLang.en => 'Network · Android ExoPlayer only',
          DemoLang.ja => 'ネットワーク · Android ExoPlayer のみ',
        },
      MockFormatFilter.all => switch (lang) {
          DemoLang.zh => '当前平台可播格式混排',
          DemoLang.en => 'All formats playable on this OS',
          DemoLang.ja => 'この OS で再生できる形式を混合',
        },
    };
    return '$n · $hint';
  }

  String selectedTypeHint(String title, int count) => switch (lang) {
        DemoLang.zh => '当前：$title（$count 个案例）— 点击下方进入演示',
        DemoLang.en => 'Selected: $title ($count cases) — open a demo below',
        DemoLang.ja => '選択中：$title（$count 件）— 下のボタンで開始',
      };

  String get playFeed => switch (lang) {
        DemoLang.zh => '推荐流播放',
        DemoLang.en => 'Play feed',
        DemoLang.ja => 'フィード再生',
      };

  String get playEpisodes => switch (lang) {
        DemoLang.zh => '剧集播放',
        DemoLang.en => 'Play episodes',
        DemoLang.ja => 'エピソード再生',
      };

  String get sourcesFooter => switch (lang) {
        DemoLang.zh =>
          'MP4/HLS：公开 CDN。MOV：SampleFile / TrueFileSize。'
              'M4V：SampleFile。WebM：本地 asset（仅 Android/Web）。'
              'DASH：Akamai / Unified（仅 Android）。',
        DemoLang.en =>
          'MP4/HLS: public CDNs. MOV: SampleFile / TrueFileSize. '
              'M4V: SampleFile. WebM: bundled asset (Android/Web). '
              'DASH: Akamai / Unified (Android).',
        DemoLang.ja =>
          'MP4/HLS：公開 CDN。MOV：SampleFile / TrueFileSize。'
              'M4V：SampleFile。WebM：同梱 asset（Android/Web）。'
              'DASH：Akamai / Unified（Android）。',
      };

  String get language => switch (lang) {
        DemoLang.zh => '语言',
        DemoLang.en => 'Language',
        DemoLang.ja => '言語',
      };

  String get playerParams => switch (lang) {
        DemoLang.zh => '播放器参数',
        DemoLang.en => 'Player parameters',
        DemoLang.ja => 'プレーヤー設定',
      };

  String get playerParamsHint => switch (lang) {
        DemoLang.zh => '进入推荐流 / 剧集时生效',
        DemoLang.en => 'Applied when opening feed / episodes',
        DemoLang.ja => 'フィード / エピソード開始時に適用',
      };

  String get paramGestures => switch (lang) {
        DemoLang.zh => '手势',
        DemoLang.en => 'Gestures',
        DemoLang.ja => 'ジェスチャー',
      };

  String get paramBuffering => switch (lang) {
        DemoLang.zh => '缓冲圈',
        DemoLang.en => 'Buffering',
        DemoLang.ja => 'バッファ表示',
      };

  String get paramPullRefresh => switch (lang) {
        DemoLang.zh => '下拉刷新',
        DemoLang.en => 'Pull refresh',
        DemoLang.ja => '引いて更新',
      };

  String get paramPullMore => switch (lang) {
        DemoLang.zh => '上拉更多',
        DemoLang.en => 'Pull more',
        DemoLang.ja => '引いて追加',
      };

  String get paramLockForward => switch (lang) {
        DemoLang.zh => '冷启锁滑',
        DemoLang.en => 'Lock swipe',
        DemoLang.ja => '起動時ロック',
      };

  String get paramLoopFeed => switch (lang) {
        DemoLang.zh => '循环(Feed)',
        DemoLang.en => 'Loop (Feed)',
        DemoLang.ja => 'ループ(Feed)',
      };

  String get shareMock => switch (lang) {
        DemoLang.zh => '分享（模拟）',
        DemoLang.en => 'Share (mock)',
        DemoLang.ja => '共有（モック）',
      };
}
