# flutter_feed_player

Vertical **short-video feed** and **series episode** players for Flutter, built on [`video_player`](https://pub.dev/packages/video_player).

Extracted from production TikTok-style / binge-episode UX patterns (parked controller promote, adjacent warm-up, exclusive audio). Host apps inject playable data — **no backend client is included**.

## Demo

Swipe feed, pull-to-refresh, and load-more in the example app:

![Demo](doc/demo.gif)

## Features

| Layer | Widget | Use case |
|-------|--------|----------|
| Convenience | `FeedPlayer` / `EpisodePlayer` | View + default chrome |
| Core | `FeedPlayerView` / `EpisodePlayerView` | Surface + gestures only |
| Components | `FeedPlayerChrome` / `EpisodePlayerChrome` | Default overlays (replace freely) |

- Park / promote `VideoPlayerController` map for instant swipe
- Adjacent preload with ~2s warm buffer
- Exclusive unmute (one audible player at a time)
- Auto-advance to next clip / episode on end (`autoAdvanceOnEnd`; mutually exclusive with effective loop)
- Tap play/pause, long-press 2×, seek bar with scrub time, speed sheet (episode)
- Scrub focus: while dragging the seek bar, chrome hides meta / side actions
- Pull-to-refresh on first page / pull-up load-more on last page
- Multi-format playback: MP4 / HLS / MOV / M4V / WebM / DASH (platform-dependent)
- Network, Flutter asset (`asset://…`), and local `file:` URLs via `PlayerFactory.create`
- Optional `HttpHeadersProvider` / `UrlTransformer` for CDN auth

Player core and UI components are separated: keep the view, swap chrome via `overlayBuilder`.

### Format support (via `video_player`)

| Format | Android (ExoPlayer) | iOS / macOS (AVPlayer) | Web |
|--------|---------------------|------------------------|-----|
| MP4 / MOV / M4V | ✅ | ✅ | ✅* |
| HLS (`.m3u8`) | ✅ | ✅ | ✅* |
| WebM | ✅ | ❌ | ✅* |
| DASH (`.mpd`) / SS | ✅ | ❌ | ❌ |

\* Browser codec support still applies. Use `MediaFormat.isSupportedOnCurrentPlatform` / `unsupportedReason` to gate UI.

---

## 接入流程（Integration）

整体顺序：**依赖 → 数据映射 → Controller + loader → 选一层 Widget → 生命周期**。包内不含网络客户端，由宿主把接口 DTO 转成 `FeedItem` / `SeriesInfo`。

```
Host API / mock
      │  map → FeedItem / SeriesInfo / EpisodeItem
      ▼
FeedPlayerController / EpisodePlayerController   (loader 分页)
      ▼
┌─────────────────┬──────────────────┐
│ FeedPlayer      │ FeedPlayerView   │  ← 推荐流
│ EpisodePlayer   │ EpisodePlayerView│  ← 剧集
└────────┬────────┴────────┬─────────┘
         │ default chrome  │ overlayBuilder 自由拼装
         ▼                 ▼
   FeedPlayerChrome   FeedBottomChrome / FeedSideActions / …
```

### 1. 添加依赖

```yaml
dependencies:
  flutter_feed_player: ^0.1.3
```

```sh
flutter pub get
```

要求 Flutter `>=3.27.0`，与 [`video_player`](https://pub.dev/packages/video_player) `^2.10.0` 一致。确保目标平台已按该插件文档完成配置（如 Android 网络权限、iOS ATS）。网络渐进式媒体需支持 **HTTP Range**（尤其 AVPlayer）。

### 2. 映射播放数据

宿主接口返回什么都可以，**最终必须变成**下列模型再交给 loader：

| 模型 | 用途 |
|------|------|
| `FeedItem` | 推荐流单卡（标题、点赞、内嵌 `EpisodeItem` 等） |
| `EpisodeItem` | 单集；用 `playUrl` 或 `assets[].url` |
| `EpisodeAsset` | 多清晰度 / 多 locale / 多格式资源 |
| `SeriesInfo` | 剧集元数据 + `episodes` 列表 |
| `MediaFormat` | 从 URL / `assetType` 推断格式、徽章文案、平台是否可播 |

播放地址解析：`playUrl` 优先；为空则取 `assets` 中第一个非空 `url`。含 `/v{n}/index.m3u8` 的 HLS 地址会在工厂层尽量归一到 `master.m3u8`。

支持的 URL 形态：

| 形态 | 示例 |
|------|------|
| 网络 | `https://cdn.example.com/a.mp4` / `.m3u8` / `.mpd` |
| Flutter asset | `asset://assets/videos/clip.webm`（或直接 `assets/...`） |
| 本地文件 | `file:///…`（非 Web） |

```dart
import 'package:flutter_feed_player/flutter_feed_player.dart';

FeedItem mapFeedDto(YourFeedDto dto) {
  return FeedItem(
    id: dto.id,
    seriesId: dto.seriesId,
    title: dto.title,
    coverUrl: dto.cover,
    description: dto.desc,
    tags: dto.tags,
    likeCount: dto.likes,
    isLiked: dto.liked,
    ctaText: 'Watch full series',
    episode: EpisodeItem(
      episodeId: dto.episodeId,
      episodeNo: dto.episodeNo,
      playUrl: dto.streamUrl, // MP4 / HLS / MOV / … 或 asset://…
      // 或：assets: [EpisodeAsset(assetType: 'hls', url: dto.hlsUrl)],
    ),
  );
}

SeriesInfo mapSeriesDto(YourSeriesDto dto, List<YourEpDto> page) {
  return SeriesInfo(
    seriesId: dto.id,
    title: dto.title,
    coverUrl: dto.cover,
    description: dto.desc,
    episodes: page
        .map(
          (e) => EpisodeItem(
            episodeId: e.id,
            episodeNo: e.no,
            title: e.title,
            playUrl: e.url,
          ),
        )
        .toList(),
  );
}
```

`EpisodeItem` / `FeedItem` 暴露 `isHls`、`isDash`、`formatLabel`（如 `HLS` / `DASH` / `WebM` / `MOV` / `MP4`），chrome 可直接用作格式徽章。

### 3. 推荐流（Feed）接入

**步骤：**

1. 实现 `FeedPageLoader`：`(page) → Future<List<FeedItem>>`，页码从 **1** 开始；没有更多时返回 **空列表**（或长度 `< pageSize`）。
2. 创建 `FeedPlayerController`（与 `pageSize` 对齐，便于判断 `hasMore`）。
3. 在 `State.initState` 里创建 Controller，在 `dispose` 里 `controller.dispose()`。
4. 挂载 `FeedPlayer`（默认 UI）或 `FeedPlayerView`（自定义 chrome）。

```dart
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  static const _pageSize = 10;
  late final FeedPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FeedPlayerController(
      loader: (page) async {
        final list = await yourApi.fetchFeedPage(page, size: _pageSize);
        return list.map(mapFeedDto).toList();
      },
      pageSize: _pageSize,
      // 默认 autoAdvanceOnEnd: true（播完滑下一则）。短视频循环请见下表。
      loopClips: true,              // 仅当 autoAdvanceOnEnd == false 时生效
      autoAdvanceOnEnd: false,      // false + loopClips → 单卡循环
      lockForwardWhileCold: false,  // HLS 冷启动时建议保持 false
      // headersProvider / urlTransformer — 见下文 CDN
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FeedPlayer(
        controller: _controller,
        bottomInset: MediaQuery.paddingOf(context).bottom,
        onWatchFullSeries: (index) {
          final item = _controller.items[index];
          // 跳转 EpisodePlayer，传入 seriesId / 起始集
        },
        onShare: (index) { /* 分享 */ },
        onMore: (index) { /* 更多菜单 */ },
      ),
    );
  }
}
```

`FeedPlayerView` 默认 `autoInit: true`，首帧会调用 `controller.init()` → `refresh()` 拉第 1 页。也可自行 `await controller.init()`。

**循环 vs 自动下一则：**

| `loopClips` | `autoAdvanceOnEnd` | 实际行为 |
|-------------|--------------------|----------|
| `true` | `false` | 当前卡循环（短视频常见） |
| `*` | `true`（默认） | 播完动画滑到下一则；`effectiveLoopClips == false` |
| `false` | `false` | 播完停在片尾 |

运行时可调用 `setLoopClips` / `setAutoAdvanceOnEnd`；开启自动下一则时会强制关闭原生 looping。

**分页手势：**

| 手势 | 行为 | 开关 |
|------|------|------|
| 首页下拉 | `refresh()` | `enablePullToRefresh` |
| 末页上拉 | `loadMore()` | `enablePullToLoadMore` |
| 靠近末尾 | 自动预取下一页 | 内置 |

### 4. 剧集（Episode）接入

**步骤：**

1. 实现 `SeriesLoader`：`(page) → Future<SeriesInfo>`，页码从 **1** 开始。
2. **第 1 页必须带齐系列元数据**（`seriesId` / `title` / …）+ 本页 `episodes`。
3. **后续页只需填 `episodes`**（其它字段会被忽略）；空列表表示没有更多。
4. 可选 `initialEpisodeId` / `initialEpisodeNo` 定位开播集。
5. 挂载 `EpisodePlayer` 或 `EpisodePlayerView`。

```dart
class SeriesPage extends StatefulWidget {
  const SeriesPage({super.key, required this.seriesId});

  final String seriesId;

  @override
  State<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends State<SeriesPage> {
  static const _pageSize = 10;
  late final EpisodePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EpisodePlayerController(
      loader: (page) async {
        final raw = await yourApi.fetchSeriesPage(
          widget.seriesId,
          page: page,
          size: _pageSize,
        );
        return mapSeriesDto(raw.meta, raw.episodes);
      },
      pageSize: _pageSize,
      initialEpisodeNo: 1,
      lockForwardWhileCold: false,
      // 默认 true：播完自动滑到下一集；末页会先 loadMore
      autoAdvanceOnEnd: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: EpisodePlayer(
        controller: _controller,
        onBack: () => Navigator.of(context).maybePop(),
        onShare: () { /* 分享 */ },
        onOpenEpisodeList: () { /* 选集面板 */ },
      ),
    );
  }
}
```

### 5. 选择接入层级

| 需求 | 用法 |
|------|------|
| 最快上线、默认 TikTok 风格 UI | `FeedPlayer` / `EpisodePlayer` |
| 完全自定义浮层 | `FeedPlayerView` / `EpisodePlayerView` + `overlayBuilder` |
| 半定制 | `overlayBuilder` 里混用 `FeedBottomChrome`、`FeedSideActions` 等积木 |

#### 自定义 chrome（推荐流）

```dart
FeedPlayerView(
  controller: controller,
  overlayBuilder: (context, slot) {
    if (!slot.isActive) return const SizedBox.shrink();
    return Stack(
      children: [
        if (slot.controller.showCenterPlay) const FeedCenterPlayIcon(),
        FeedSideActions(
          bottomInset: 0,
          liked: slot.item.isLiked,
          likeCount: slot.item.likeCount,
          onLike: () => slot.controller.toggleLike(slot.index),
          onShare: () { /* … */ },
          onMore: () { /* … */ },
        ),
        FeedBottomChrome(
          bottomInset: 0,
          title: slot.item.title,
          description: slot.item.description,
          tags: slot.item.tags,
          ctaText: slot.item.ctaText,
          formatLabel: slot.item.formatLabel,
          seekController: slot.player,
          // 拖拽进度条时可用 onScrubbingChanged 隐藏其它浮层
        ),
        // 也可完全自绘，使用 slot.controller / slot.item / slot.player
      ],
    );
  },
);
```

剧集侧同理：用 `EpisodePlayerSlot` + `EpisodeTopBar` / `EpisodeBottomChrome` / `EpisodeCenterControl` 等，或整页换成自己的 UI。

默认 chrome（`FeedPlayerChrome` / `EpisodePlayerChrome`）在 **scrub 拖拽** 时会收起标题、侧栏等，只保留进度条与时间码；`PlayerSeekBar` / `*BottomChrome` 暴露 `onScrubbingChanged` 便于自绘同样行为。

`loadingBuilder` / `errorBuilder` 可替换首屏加载、空列表错误壳。冷启动过久时 `showLoadingPrompt` 只在缓冲指示下显示软提示文案，**不再**当作重试页；硬错误（含超时）才走 retry overlay。

### 6. CDN 鉴权 / URL 改写（可选）

在 Controller 构造时注入：

```dart
FeedPlayerController(
  loader: loader,
  headersProvider: ({required url, required isHls}) => {
    'Authorization': 'Bearer $token',
    if (!isHls) 'User-Agent': 'MyApp/1.0',
  },
  urlTransformer: (url) => appendExpireQuery(url),
);
```

`EpisodePlayerController` 参数相同。默认不再注入自定义 User-Agent（部分 CDN 会与 Range 请求冲突）；需要时通过 `headersProvider` 自行添加。

### 7. 生命周期与其它约定

- **必须**在宿主 `State.dispose` 中调用 `controller.dispose()`，释放 parked / active 播放器。
- 页面不可见时，View 会配合暂停；需要后台播放可设 `allowBackgroundPlayback: true`（慎用）。
- Demo 在 `main` 里调用了 `PlaybackMemory.init()`（记忆进度）；宿主按需同样初始化。
- `FeedItem.identity` / `episodeId` 尽量稳定唯一，便于 park 缓存命中。
- 从 Feed 进剧集：在 `onWatchFullSeries` 里 `Navigator.push` 打开带同一 `seriesId` 的 `EpisodePlayer`。
- WebM / DASH 在 iOS/macOS 不可播；可用 `MediaFormat` 过滤列表或展示 `unsupportedReason`。
- View 会绑定 `controller.animateToIndex`，供 `autoAdvanceOnEnd` 驱动 `PageView` 动画；自建列表时需自行赋值。

### 8. 接入检查清单

- [ ] `pubspec` 依赖 `flutter_feed_player`
- [ ] DTO → `FeedItem` / `SeriesInfo` / `EpisodeItem`，且 `playUrl` 或 `assets` 可播
- [ ] 目标平台支持该格式（见上方矩阵）；网络流支持 HTTP Range
- [ ] `loader` 分页从 1 开始；耗尽返回空列表；`pageSize` 与接口一致
- [ ] 剧集第 1 页带系列元数据
- [ ] `Controller` 在 `dispose` 中释放
- [ ] 选用 `*Player` 或 `*PlayerView` + chrome
- [ ] 需要鉴权时配置 `headersProvider` / `urlTransformer`
- [ ] 按需配置 `loopClips` / `autoAdvanceOnEnd`（二者有效互斥）
- [ ] 真机验证竖滑、下拉刷新、上拉加载、播完自动下一则、音画互斥

---

## Quick start — feed

```dart
final controller = FeedPlayerController(
  loader: (page) async {
    // Map your API (or mock) → List<FeedItem>
    return mockFeedPage(page);
  },
  // Defaults: autoAdvanceOnEnd: true. For looping shorts:
  // loopClips: true, autoAdvanceOnEnd: false,
);

FeedPlayer(
  controller: controller,
  onWatchFullSeries: (index) { /* open EpisodePlayer */ },
  onShare: (index) { /* … */ },
  onMore: (index) { /* … */ },
);
```

## Quick start — episodes

```dart
final controller = EpisodePlayerController(
  loader: (page) async => mockSeriesPage(page),
  pageSize: 10,
  initialEpisodeNo: 1,
  // autoAdvanceOnEnd: true (default) — binge to next episode
);

EpisodePlayer(controller: controller);
```

## Demo

```sh
cd example
flutter run
```

Example home lists format filters available on the **current platform** (MP4 / HLS / MOV / M4V; plus WebM / DASH where supported). Samples include public network streams and a bundled WebM under `asset://assets/videos/…`. Demo pages expose grouped playback toggles (gestures, pull refresh/load-more, lock-forward, loop, auto-advance) and compose chrome via `overlayBuilder`.

## Models

```dart
FeedItem / EpisodeItem / EpisodeAsset / SeriesInfo / MediaFormat
```

Provide `playUrl` and/or `assets[].url`. HLS URLs containing `/v{n}/index.m3u8` are normalized to `master.m3u8` when applicable. `formatLabel` / `isHls` / `isDash` come from `MediaFormat`.

## Public chrome building blocks

**Feed:** `FeedPlayerChrome`, `FeedCenterPlayIcon`, `FeedSideActions` (like / share / more), `FeedBottomChrome`, `FeedActionButton`, `PlayerSeekBar`

**Episode:** `EpisodePlayerChrome`, `EpisodeTopBar`, `EpisodeCenterControl`, `EpisodeSideActions`, `EpisodeBottomChrome`, `EpisodeBoostBadge`

`PlayerSeekBar` supports shimmer while uninitialized, a progress thumb, scrub time labels (`current / total`), and `onScrubbingChanged`.

## License

MIT
