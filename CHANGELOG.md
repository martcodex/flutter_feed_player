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
