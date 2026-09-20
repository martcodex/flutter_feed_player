import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feed_player/flutter_feed_player.dart';

import 'l10n/demo_l10n.dart';
import 'mock/mock_data.dart';
import 'pages/episode_demo_page.dart';
import 'pages/feed_demo_page.dart';
import 'widgets/player_param_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await PlaybackMemory.init();
  runApp(const FeedPlayerDemoApp());
}

class FeedPlayerDemoApp extends StatefulWidget {
  const FeedPlayerDemoApp({super.key});

  @override
  State<FeedPlayerDemoApp> createState() => _FeedPlayerDemoAppState();
}

class _FeedPlayerDemoAppState extends State<FeedPlayerDemoApp> {
  final DemoLocaleController _locale = DemoLocaleController();

  @override
  void dispose() {
    _locale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoLocaleScope(
      controller: _locale,
      child: ListenableBuilder(
        listenable: _locale,
        builder: (context, _) {
          return MaterialApp(
            title: _locale.l10n.appTitle,
            locale: _locale.lang.locale,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0F766E),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFF0B0B0F),
            ),
            home: const DemoHomePage(),
          );
        },
      ),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  PlayerDemoParams _params = const PlayerDemoParams();

  @override
  Widget build(BuildContext context) {
    final l10n = DemoLocaleScope.l10nOf(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            const _LanguageSwitcher(),
            const SizedBox(height: 16),
            Text(
              l10n.brandName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tagline,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.introHint,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                height: 1.4,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _FormatGroupCard(
              title: 'MP4',
              subtitle: l10n.mp4Subtitle(MockVideos.mp4Samples.length),
              color: const Color(0xFF38BDF8),
              playFeedLabel: l10n.playFeed,
              playEpisodesLabel: l10n.playEpisodes,
              onPlayFeed: () => _openFeed(MockFormatFilter.mp4),
              onPlayEpisodes: () => _openEpisodes(MockFormatFilter.mp4),
            ),
            const SizedBox(height: 16),
            _FormatGroupCard(
              title: 'M3U8 / HLS',
              subtitle: l10n.hlsSubtitle(MockVideos.hlsSamples.length),
              color: const Color(0xFF34D399),
              playFeedLabel: l10n.playFeed,
              playEpisodesLabel: l10n.playEpisodes,
              onPlayFeed: () => _openFeed(MockFormatFilter.hls),
              onPlayEpisodes: () => _openEpisodes(MockFormatFilter.hls),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _openFeed(MockFormatFilter.all),
              icon: const Icon(Icons.swipe_vertical),
              label: Text(l10n.mixedFeed),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openEpisodes(MockFormatFilter.all),
              icon: const Icon(Icons.play_circle_outline),
              label: Text(l10n.mixedEpisodes),
            ),
            const SizedBox(height: 24),
            PlayerParamPanel(
              params: _params,
              onChanged: (p) => setState(() => _params = p),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.sourcesFooter,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFeed(MockFormatFilter filter) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeedDemoPage(
          formatFilter: filter,
          params: _params,
        ),
      ),
    );
  }

  void _openEpisodes(MockFormatFilter filter) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EpisodeDemoPage(
          formatFilter: filter,
          params: _params,
        ),
      ),
    );
  }
}

class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher();

  @override
  Widget build(BuildContext context) {
    final localeCtrl = DemoLocaleScope.of(context);
    final l10n = localeCtrl.l10n;
    return Row(
      children: [
        Icon(
          Icons.language,
          size: 18,
          color: Colors.white.withValues(alpha: 0.55),
        ),
        const SizedBox(width: 8),
        Text(
          l10n.language,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
        const Spacer(),
        SegmentedButton<DemoLang>(
          segments: [
            for (final lang in DemoLang.values)
              ButtonSegment<DemoLang>(
                value: lang,
                label: Text(
                  lang.label,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
          selected: {localeCtrl.lang},
          onSelectionChanged: (set) {
            if (set.isEmpty) return;
            localeCtrl.setLang(set.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.black;
              }
              return Colors.white70;
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return Colors.white.withValues(alpha: 0.08);
            }),
          ),
          showSelectedIcon: false,
        ),
      ],
    );
  }
}

class _FormatGroupCard extends StatelessWidget {
  const _FormatGroupCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.playFeedLabel,
    required this.playEpisodesLabel,
    required this.onPlayFeed,
    required this.onPlayEpisodes,
  });

  final String title;
  final String subtitle;
  final Color color;
  final String playFeedLabel;
  final String playEpisodesLabel;
  final VoidCallback onPlayFeed;
  final VoidCallback onPlayEpisodes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF17171C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onPlayFeed,
                  child: Text(playFeedLabel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onPlayEpisodes,
                  child: Text(playEpisodesLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
