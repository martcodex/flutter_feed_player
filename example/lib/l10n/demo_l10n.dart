import 'package:flutter/material.dart';

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
        DemoLang.zh => '使用免费公开 MP4 / M3U8 样例的演示。',
        DemoLang.en => 'Demo with free public MP4 / M3U8 samples.',
        DemoLang.ja => '無料の公開 MP4 / M3U8 サンプルによるデモ。',
      };

  String get introHint => switch (lang) {
        DemoLang.zh =>
          '按格式分组进入推荐流或剧集播放器。上下滑切换；'
              '首页下拉刷新，末页上拉加载更多。',
        DemoLang.en =>
          'Enter feed or episode player by format. Swipe up/down to switch; '
              'pull down to refresh, pull up near the end to load more.',
        DemoLang.ja =>
          '形式ごとにフィードまたはエピソードプレーヤーを開きます。上下スワイプで切替、'
              '先頭で下に引いて更新、末尾付近で上に引いて追加読み込み。',
      };

  String mp4Subtitle(int count) => switch (lang) {
        DemoLang.zh => '$count 个片段 · Flutter 文档',
        DemoLang.en => '$count clips · Flutter docs',
        DemoLang.ja => '$count クリップ · Flutter docs',
      };

  String hlsSubtitle(int count) => switch (lang) {
        DemoLang.zh => '$count 路流 · Mux / Apple / Unified',
        DemoLang.en => '$count streams · Mux / Apple / Unified',
        DemoLang.ja => '$count ストリーム · Mux / Apple / Unified',
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

  String get mixedFeed => switch (lang) {
        DemoLang.zh => '混合格式推荐流（MP4 + HLS）',
        DemoLang.en => 'Mixed feed (MP4 + HLS)',
        DemoLang.ja => '混合フィード（MP4 + HLS）',
      };

  String get mixedEpisodes => switch (lang) {
        DemoLang.zh => '混合格式剧集连播',
        DemoLang.en => 'Mixed episode playlist',
        DemoLang.ja => '混合エピソード連続再生',
      };

  String get sourcesFooter => switch (lang) {
        DemoLang.zh =>
          'HLS 来源：Mux test-streams、Apple HLS examples、'
              'Unified Streaming。MP4：Flutter 文档。',
        DemoLang.en =>
          'HLS sources: Mux test-streams, Apple HLS examples, '
              'Unified Streaming. MP4: Flutter docs.',
        DemoLang.ja =>
          'HLS ソース：Mux test-streams、Apple HLS examples、'
              'Unified Streaming。MP4：Flutter docs。',
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
