## 0.1.4

* Add `autoAdvanceOnEnd` on `FeedPlayerController` / `EpisodePlayerController`
  (default `true`): when a clip ends, animate to the next item (load-more if
  needed). Effective looping is `loopClips && !autoAdvanceOnEnd`.
* Add `setAutoAdvanceOnEnd` / keep `setLoopClips`; feed exposes
  `effectiveLoopClips`.
* Detect end-of-playback via `VideoPlayerValue.isCompleted` (plus near-end
  fallback) so auto-advance is not missed while `isPlaying` is briefly true.
* Soft cold-start hint (`showLoadingPrompt`) no longer opens the retry page;
  it only shows under the buffering spinner. Retry overlay is for hard errors
  / timeout only. Soft prompt arms after attach to avoid flashing on slow HLS.
* Seek UX: `PlayerSeekBar` shimmer, thumb, scrub time label; chrome hides
  meta / side actions while scrubbing (`onScrubbingChanged` on seek bar and
  bottom chrome).
* Feed chrome: optional `onMore` on `FeedPlayer` / `FeedPlayerChrome` /
  `FeedSideActions`.
* Example: grouped player param panel with loop ↔ auto-advance mutual
  exclusion and related l10n.

## 0.1.3

* Add `MediaFormat` for URL / `assetType` detection, chrome badges, and
  platform support checks (`isSupportedOnCurrentPlatform`, `unsupportedReason`).
* Expand format labels beyond HLS/MP4: WebM, MOV, M4V, DASH (and SS).
* `PlayerFactory.create` plays network, Flutter asset (`asset://…` / `assets/…`),
  and local `file:` URLs; adds `formatHintForUrl` for HLS / DASH / SS.
* Models expose `isDash` alongside `isHls` / `formatLabel`.
* Stop injecting a default custom User-Agent (avoids CDN + Range conflicts);
  hosts can still set headers via `HttpHeadersProvider`.
* Example: multi-format showcase (MP4 / HLS / MOV / M4V / WebM / DASH) with
  platform-aware filters and bundled `assets/videos/` samples.

## 0.1.2

* Raise `video_player` lower bound to `^2.10.0` (requires `VideoViewType`).
* Require Flutter `>=3.27.0` to match `video_player` 2.10.0.
* Shorten package description for pub.dev (60–180 characters).

## 0.1.1

* Separate player core from UI components.
* Add `FeedPlayerView` / `EpisodePlayerView` (surface + gestures only).
* Extract default chrome into public widgets (`FeedPlayerChrome`, `EpisodePlayerChrome`, and building blocks).
* `FeedPlayer` / `EpisodePlayer` remain convenience wrappers (view + default chrome).
* Customize via `overlayBuilder`, or compose chrome pieces freely.
* Playback UX: cold-start watchdog, retry overlay, forward-swipe lock while
  first frame is loading, eager next-item warm on forward drag intent.
* Feed clips can loop (`loopClips`).
* Models expose `isHls` / `formatLabel`; chrome can show a format badge.
* Example: MP4 / M3U8 grouped showcase with free public sample streams
  (Mux, Apple HLS examples, Unified Streaming, Flutter docs MP4).

## 0.1.0

* Initial release.
* `FeedPlayer` — vertical short-video feed with park/promote preloading.
* `EpisodePlayer` — vertical series episode binge player with adjacent warm-up.
* Injectable data models and mock-friendly APIs (no network client included).
