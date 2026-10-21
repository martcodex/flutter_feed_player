import 'package:flutter/widgets.dart';
import 'package:flutter_feed_player/src/widgets/playback_background_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('going inactive snaps a drifted page back', (tester) async {
    final page = PageController();
    addTearDown(page.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PageView(
          controller: page,
          children: const [
            SizedBox.expand(),
            SizedBox.expand(),
            SizedBox.expand(),
          ],
        ),
      ),
    );

    var index = 0;
    var suspended = false;
    final guard = PlaybackBackgroundGuard(
      pipEnabled: () => true,
      isPlaying: () => true,
      userPaused: () => false,
      currentIndex: () => index,
      pageController: () => page,
      videoSize: () => const Size(9, 16),
      setSuspendAutoAdvance: (value) => suspended = value,
      setInPictureInPicture: (_) {},
      pauseForBackground: () async {},
      resumeFromBackground: () async {},
      onUpdate: () {},
    );
    guard.attach();
    addTearDown(() {
      guard.detach();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    guard.onForegroundTick();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(guard.holding, isTrue);
    expect(suspended, isTrue);
    expect(guard.shouldIgnorePageChange(), isTrue);

    page.jumpToPage(1);
    await tester.pump();
    expect(page.page, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 400));
    expect(guard.holding, isFalse);
    expect(suspended, isFalse);

    index = 1;
    page.jumpToPage(1);
    await tester.pump();
    expect(guard.shouldIgnorePageChange(), isFalse);
    expect(page.page, 1);
  });

  testWidgets('a paused video still pins the page in the background', (
    tester,
  ) async {
    final guard = PlaybackBackgroundGuard(
      pipEnabled: () => true,
      isPlaying: () => false,
      userPaused: () => true,
      currentIndex: () => 0,
      pageController: () => null,
      videoSize: () => const Size(9, 16),
      setSuspendAutoAdvance: (_) {},
      setInPictureInPicture: (_) {},
      pauseForBackground: () async {},
      resumeFromBackground: () async {},
      onUpdate: () {},
    );
    guard.attach();
    addTearDown(() {
      guard.detach();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    guard.onForegroundTick();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(guard.holding, isTrue);
    expect(guard.shouldIgnorePageChange(), isTrue);
  });
}
