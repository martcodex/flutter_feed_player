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
  MockFormatFilter _selected = MockFormatFilter.mp4;

  @override
  Widget build(BuildContext context) {
    final l10n = DemoLocaleScope.l10nOf(context);
    final selectedCount = MockVideos.clipsFor(_selected).length;
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
              l10n.selectVideoType,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.introHint,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                height: 1.4,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            _VideoTypeList(
              selected: _selected,
              onSelected: (f) => setState(() => _selected = f),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.selectedTypeHint(
                l10n.videoTypeTitle(_selected),
                selectedCount,
              ),
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _openFeed(_selected),
                    child: Text(l10n.playFeed),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _openEpisodes(_selected),
                    child: Text(l10n.playEpisodes),
                  ),
                ),
              ],
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

class _VideoTypeList extends StatelessWidget {
  const _VideoTypeList({
    required this.selected,
    required this.onSelected,
  });

  final MockFormatFilter selected;
  final ValueChanged<MockFormatFilter> onSelected;

  static Color _color(MockFormatFilter f) => switch (f) {
        MockFormatFilter.mp4 => const Color(0xFF38BDF8),
        MockFormatFilter.hls => const Color(0xFF34D399),
        MockFormatFilter.webm => const Color(0xFFFBBF24),
        MockFormatFilter.mov => const Color(0xFFF472B6),
        MockFormatFilter.m4v => const Color(0xFFA78BFA),
        MockFormatFilter.dash => const Color(0xFFFB923C),
        MockFormatFilter.all => const Color(0xFFE2E8F0),
      };

  static IconData _icon(MockFormatFilter f) => switch (f) {
        MockFormatFilter.mp4 => Icons.movie_outlined,
        MockFormatFilter.hls => Icons.playlist_play,
        MockFormatFilter.webm => Icons.web_asset,
        MockFormatFilter.mov => Icons.videocam_outlined,
        MockFormatFilter.m4v => Icons.video_file_outlined,
        MockFormatFilter.dash => Icons.stream,
        MockFormatFilter.all => Icons.library_books_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = DemoLocaleScope.l10nOf(context);
    final order = MockVideos.availableFilters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MockVideos.platformHint(),
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF17171C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < order.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                _VideoTypeTile(
                  title: l10n.videoTypeTitle(order[i]),
                  subtitle: l10n.videoTypeSubtitle(
                    order[i],
                    MockVideos.clipsFor(order[i]).length,
                  ),
                  color: _color(order[i]),
                  icon: _icon(order[i]),
                  selected: selected == order[i],
                  onTap: () => onSelected(order[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoTypeTile extends StatelessWidget {
  const _VideoTypeTile({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: selected ? 0.28 : 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? color : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color: selected
                    ? color
                    : Colors.white.withValues(alpha: 0.35),
              ),
            ],
          ),
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
