# GIF Play Flutter — AI Research Index

> Persistent repository map for fast feature research and implementation.
> Source of truth: GitHub repository `Rilan-Dev/Gif-Play-Flutter`, branch `main`.
> Index status: refreshed against current `main` on 2026-10-10; this map is maintained as code and architecture evolve.
> Inventory: original source inventory plus the Phase 1 persistence, Phase 2 cache/share, and Phase 3 navigation modules listed below.

## 1. Research rules

1. Treat GitHub `main` as the current repository authority unless a task names another ref.
2. Start with this index before broad repository exploration.
3. Read the smallest relevant slice first: screen -> actions/data service -> providers/models -> shared widgets/utils.
4. Do not assume `GifService` is the production data path. The current home/mood-vibe flows use screen-specific data services.
5. Preserve existing Provider-based state management unless a feature explicitly requires architectural migration.
6. For behavior changes, update or add tests rather than relying on the placeholder smoke test.
7. Treat external HTML scraping, image URLs, sharing/downloading, local persistence, and authentication as separate seams.
8. Re-index this document when the project structure changes materially.

## 2. Application topology

```
lib/main.dart
  └── global initialization
      ├── SharedPreferencesUtil
      ├── ThemeProvider
      ├── LikedGifsProvider
      ├── ViewedGifsProvider
      ├── ViewModeProvider
      └── MoodVibeViewModeProvider
          └── MyApp
              └── SplashScreen
                  └── LoginScreen
                      └── MainScreen
                          ├── main_screen_data_service.dart
                          ├── main_screen_actions.dart
                          ├── MediaViewSwitcher
                          │   ├── grid
                          │   ├── list
                          │   ├── card
                          │   └── masonry
                          ├── Viewed GIFs
                          ├── Saved/Shared GIFs
                          └── Liked GIFs

Other feature branches:
  SearchScreen
  GifDetailScreen
  GifViewer
  MoodVibe
  ShareGifScreen
  ViewedGifsScreen
  LikedGifsScreen
```

## 3. Core architecture

### Phase 3 persistent navigation (current implementation)
- `lib/data/local/session_navigation_controller.dart` — active Space and Detail Tab state, restoration, and navigation persistence.
- `lib/common/widgets/session_navigation_strip.dart` — existing UI for switching Spaces and Detail Tabs, plus the thumbnail/title overview dialog for all child tabs and the bottom browser-style tab control.
- `lib/common/widgets/detail_tab_content.dart` — restored selected-GIF detail surface, source-page suggestion grid, safe explicit source opening, and child-tab activation; exposes an explicit GIF options callback.
- `lib/screens/main_screen/main_screen.dart` — bounded per-Space feed snapshot, query/page/visited-page/scroll restoration, generation-guarded restore/fetch lifecycle, and stale post-frame scroll protection.
- `lib/screens/main_screen/main_screen_actions.dart` — regular item open persists/activates a Detail Tab with stable media identity without immediately layering a legacy details dialog; special Mood & Vibe route remains.
- `lib/screens/collections_screen.dart` and `lib/data/cache/collection_share_controller.dart` — refresh SQLite-backed collections on entry, show saved membership, support safe reset/retry, and allow bulk share to skip empty selected lists.
- `test/session_navigation_recovery_test.dart` — startup recovery, persistence, close/activation transitions, and independent per-Space feed snapshot source coverage.
- `test/detail_tab_content_test.dart` — unsafe source URL rejection and explicit GIF options widget test sources.
- `test/main_screen_actions_test.dart` — regular feed-item interaction activates a saved Detail Tab without displaying the legacy GIF details dialog.


### Bootstrap
- `lib/main.dart`
  - orientation lock
  - SharedPreferences initialization
  - provider initialization/loading
  - theme selection
  - splash screen
  - app entry

### State
- `lib/common/providers/theme_provider.dart` — theme mode persistence/toggle.
- `lib/common/providers/liked_gifs_provider.dart` — liked GIF state/persistence.
- `lib/common/providers/viewed_gifs_provider.dart` — viewing history/persistence.
- `lib/common/providers/view_mode_provider.dart` — grid/list/card/masonry mode.
- `lib/common/providers/mood_vibe_view_mode_provider.dart` — Mood & Vibe layout state.

### Models
- `lib/common/models/media_item.dart` — general scraped media representation.
- `lib/common/models/gif_item.dart` — GIF-oriented representation.
- `lib/common/models/view_mode.dart` — display mode enum.

### Persistence / utilities
- `lib/common/utils/shared_preferences_util.dart`
- `lib/common/utils/file_utils.dart`
- `lib/common/utils/download_and_share.dart`
- `lib/common/utils/download_and_share_gif.dart`
- `lib/common/utils/time_ago_util.dart`
- `lib/common/mixins/selection_state_mixin.dart`
- `lib/common/animations/slide_animation.dart`

### Shared UI
- `lib/common/widgets/media_view_switcher.dart` — central layout router.
- `lib/common/widgets/media_grid.dart`
- `lib/common/widgets/media_list_view.dart`
- `lib/common/widgets/media_card_view.dart`
- `lib/common/widgets/media_masonry_view.dart`
- `lib/common/widgets/mood_vibe_media_*.dart`
- `lib/common/widgets/cached_gif.dart`
- `lib/common/widgets/shimmer_loading.dart`
- `lib/common/widgets/empty_state.dart`
- `lib/common/widgets/error_state.dart`
- `lib/common/widgets/action_mode_bottom_bar.dart`
- `lib/common/widgets/selection_indicator.dart`
- `lib/common/widgets/view_mode_selector.dart`
- `lib/common/widgets/mood_vibe_view_mode_selector.dart`

## 4. Feature map

| Feature | Entry point | Logic | State / shared dependencies |
|---|---|---|---|
| App bootstrap | `lib/main.dart` | initialization in main | all providers |
| Authentication UI | `lib/screens/login_screen.dart` | local credential check in screen | ThemeProvider |
| Main feed | `lib/screens/main_screen/main_screen.dart` | `main_screen_data_service.dart`, `main_screen_actions.dart` | ViewMode, LikedGifs, Theme |
| Search | `lib/screens/search_screen.dart` + main-screen search | screen-local filtering / feature UI | MediaItem |
| GIF detail | `lib/screens/gif_detail_screen.dart` | screen-local | GIF/media models |
| GIF viewer | `lib/screens/gif_viewer/*` | actions + data service + UI | GIF/media models |
| Mood & Vibe | `lib/screens/mood_vibe/*` | actions + data service + UI | MoodVibeViewModeProvider |
| Liked GIFs | `lib/screens/liked_gifs_screen.dart` | screen + provider | LikedGifsProvider |
| Viewed GIFs | `lib/screens/viewed_gifs_screen.dart` | screen + provider | ViewedGifsProvider |
| Save/share | `lib/screens/share_gif_screen.dart` | download/share utilities | filesystem + share_plus |
| Display modes | `lib/common/widgets/media_view_switcher.dart` | four layout widgets | ViewModeProvider |
| Theme | `lib/theme/app_theme.dart` | Material 3 ThemeData | ThemeProvider |
| Generic GIF API abstraction | `lib/services/gif_service.dart` | currently placeholder | GifItem |

## 5. Main feed data path

Current production-like feed path:

```
MainScreen
  -> MainScreenDataService.fetchData()
  -> HTTP GET https://porngifmag.com/page/<random-page>
  -> HTML parser
  -> .thumb.thumb-loop
  -> .thumb-image img + article link
  -> MediaItem
  -> _mediaItems / _filteredItems
  -> shuffle
  -> MediaViewSwitcher
```

Important implementation details:
- Pages are randomly selected, initially from 1..50.
- A `visitedPages` set prevents immediate repetition.
- Total pages are inferred from `.pagination a`, otherwise 50 is used.
- Main-feed search is currently client-side filtering over already fetched `MediaItem` values.
- Infinite loading triggers around 80% of scroll extent.
- Main feed uses `http` + `html` directly rather than `GifService`.
- The parser depends on CSS selectors from the remote HTML site; this is a major external fragility seam.

## 6. Detail/GIF retrieval seam

`MainScreenDataService.fetchGifsFromUrl(url)`:
- GETs a supplied detail URL.
- Parses `.single-main .single-image img`.
- Produces `GifItem` values.
- Uses generated IDs based on timestamp + image URL hash.
- Extracts URL, alt text, width and height.

Research this path before changing:
- viewer behavior
- GIF playback
- detail page parsing
- download/share
- media metadata

## 7. State and persistence map

```
SharedPreferences
  ├── theme mode
  ├── liked GIF collection
  ├── viewed GIF collection
  └── view-mode preferences

Provider / ChangeNotifier
  ├── ThemeProvider
  ├── LikedGifsProvider
  ├── ViewedGifsProvider
  ├── ViewModeProvider
  └── MoodVibeViewModeProvider
```

Use `SharedPreferencesUtil` before introducing another local persistence mechanism.

## 8. Layout system

The main media presentation contract is:

```
MediaViewSwitcher
  ├── ViewMode.grid    -> MediaGrid
  ├── ViewMode.list    -> MediaListView
  ├── ViewMode.card    -> MediaCardView
  └── ViewMode.masonry -> MediaMasonryView
```

A new main-feed presentation mode should normally enter here rather than adding a second independent layout router.

Mood & Vibe has a parallel presentation family:
- `MoodVibeMediaViewSwitcher`
- `MoodVibeMediaGrid`
- `MoodVibeMediaListView`
- `MoodVibeMediaCardView`
- `MoodVibeMediaMasonryView`

## 9. High-value research hotspots

### P0 — external data contract
`lib/screens/main_screen/main_screen_data_service.dart`

Why:
- external HTML source
- hard-coded URL
- hard-coded CSS selectors
- random pagination
- parsing and networking are coupled
- error handling is broad
- production data path bypasses `GifService`

### P0 — main UX orchestration
`lib/screens/main_screen/main_screen.dart`

Why:
- feed state
- search state
- infinite scrolling
- selection mode
- refresh
- navigation
- shuffle
- UI actions are concentrated here

### P0 — media model boundary
`lib/common/models/media_item.dart`
`lib/common/models/gif_item.dart`

Why:
- every feed/viewer/persistence improvement depends on stable identity and metadata.

### P1 — media presentation
`lib/common/widgets/media_view_switcher.dart`
`lib/common/widgets/media_grid.dart`
`lib/common/widgets/media_list_view.dart`
`lib/common/widgets/media_card_view.dart`
`lib/common/widgets/media_masonry_view.dart`

### P1 — persistence
`lib/common/providers/*.dart`
`lib/common/utils/shared_preferences_util.dart`

### P1 — viewer
`lib/screens/gif_viewer/*`
`lib/screens/gif_detail_screen.dart`

### P1 — sharing
`lib/common/utils/download_and_share.dart`
`lib/common/utils/download_and_share_gif.dart`
`lib/common/utils/file_utils.dart`
`lib/screens/share_gif_screen.dart`

### P2 — visual system
`lib/theme/app_theme.dart`
`assets/images/*`

### P2 — generic service abstraction
`lib/services/gif_service.dart`

This currently contains placeholder/example behavior and should not be mistaken for the active feed backend.

## 10. Dependency map

Declared application dependencies in `pubspec.yaml`:

- Flutter SDK
- flutter_riverpod
- http
- html
- dartz
- cached_network_image
- share_plus
- lottie
- flutter_staggered_animations
- cupertino_icons
- url_launcher
- provider
- shared_preferences
- animated_splash_screen
- page_transition
- intl
- flutter_launcher_icons
- rename_app

Notable architecture observation:
- `provider` is the active state-management mechanism in `main.dart`.
- `flutter_riverpod` is declared but the inspected bootstrap does not use Riverpod.
- `dartz` is declared but should be verified before treating it as an active architectural dependency.
- `GifService` is currently placeholder-oriented despite the HTTP dependency being actively used elsewhere.

## 11. Testing state

Current test inventory:
- `test/widget_test.dart`

The existing test is the default Flutter counter smoke test and does not represent the actual GIF Play application behavior. Feature work should progressively replace this with tests around:
- bootstrap/login navigation
- provider persistence
- media parsing
- pagination selection
- search/filtering
- selection mode
- view mode switching
- download/share error handling
- viewer behavior

## 12. Platform map

### Android
- `android/app/build.gradle`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/riluraafu/gif_play/MainActivity.kt`
- launcher/background resources

### iOS
- `ios/Runner/*`
- `ios/Runner.xcodeproj/*`
- `ios/Runner.xcworkspace/*`
- app icon / launch assets
- `ios/RunnerTests/RunnerTests.swift`

### Web
- `web/index.html`
- `web/manifest.json`
- `web/icons/*`
- `web/favicon.png`

Platform-specific feature work should be checked against the sharing, filesystem, networking and image-loading dependencies before implementation.

## 13. Full source inventory

### Root
- `.gitignore`
- `.metadata`
- `README.md`
- `analysis_options.yaml`
- `pubspec.yaml`
- `pubspec.lock`

### lib/common
- `lib/common/README.md`
- `lib/common/animations/slide_animation.dart`
- `lib/common/mixins/selection_state_mixin.dart`
- `lib/common/models/gif_item.dart`
- `lib/common/models/media_item.dart`
- `lib/common/models/view_mode.dart`
- `lib/common/providers/liked_gifs_provider.dart`
- `lib/common/providers/mood_vibe_view_mode_provider.dart`
- `lib/common/providers/theme_provider.dart`
- `lib/common/providers/view_mode_provider.dart`
- `lib/common/providers/viewed_gifs_provider.dart`
- `lib/common/utils/download_and_share.dart`
- `lib/common/utils/download_and_share_gif.dart`
- `lib/common/utils/file_utils.dart`
- `lib/common/utils/shared_preferences_util.dart`
- `lib/common/utils/time_ago_util.dart`
- `lib/common/widgets/README.md`
- `lib/common/widgets/action_mode_bottom_bar.dart`
- `lib/common/widgets/cached_gif.dart`
- `lib/common/widgets/empty_state.dart`
- `lib/common/widgets/error_state.dart`
- `lib/common/widgets/media_card_view.dart`
- `lib/common/widgets/media_grid.dart`
- `lib/common/widgets/media_list_view.dart`
- `lib/common/widgets/media_masonry_view.dart`
- `lib/common/widgets/media_view_switcher.dart`
- `lib/common/widgets/mood_vibe_media_card_view.dart`
- `lib/common/widgets/mood_vibe_media_grid.dart`
- `lib/common/widgets/mood_vibe_media_list_view.dart`
- `lib/common/widgets/mood_vibe_media_masonry_view.dart`
- `lib/common/widgets/mood_vibe_media_view_switcher.dart`
- `lib/common/widgets/mood_vibe_view_mode_selector.dart`
- `lib/common/widgets/selection_indicator.dart`
- `lib/common/widgets/shimmer_loading.dart`
- `lib/common/widgets/view_mode_selector.dart`

### lib/screens
- `lib/screens/gif_detail_screen.dart`
- `lib/screens/gif_viewer/gif_viewer_actions.dart`
- `lib/screens/gif_viewer/gif_viewer_data_service.dart`
- `lib/screens/gif_viewer/gif_viewer_screen.dart`
- `lib/screens/gif_viewer/gif_viewer_ui.dart`
- `lib/screens/gif_viewer_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/liked_gifs_screen.dart`
- `lib/screens/login_screen.dart`
- `lib/screens/main_screen.dart`
- `lib/screens/main_screen/main_screen.dart`
- `lib/screens/main_screen/main_screen_actions.dart`
- `lib/screens/main_screen/main_screen_data_service.dart`
- `lib/screens/mood_vibe/mood_vibe_actions.dart`
- `lib/screens/mood_vibe/mood_vibe_data_service.dart`
- `lib/screens/mood_vibe/mood_vibe_screen.dart`
- `lib/screens/mood_vibe/mood_vibe_ui.dart`
- `lib/screens/mood_vibe_screen.dart`
- `lib/screens/search_screen.dart`
- `lib/screens/share_gif_screen.dart`
- `lib/screens/viewed_gifs_screen.dart`

### Other Dart
- `lib/main.dart`
- `lib/services/gif_service.dart`
- `lib/theme/app_theme.dart`
- `lib/widgets/gif_grid.dart`
- `lib/widgets/media_adapter.dart`
- `lib/widgets/time_category_list.dart`

### Tests
- `test/widget_test.dart`

### Assets
- `assets/images/app_icon.jpeg`
- `assets/images/app_icon.png`
- `assets/images/app_logo.png`

### Native/web
Native platform files and generated Flutter platform scaffolding are included in the Git tree; they should be treated as platform integration surfaces rather than the primary application feature layer.

## 14. Fast research recipes

### "Change the home feed"
Read:
1. `main_screen.dart`
2. `main_screen_data_service.dart`
3. `main_screen_actions.dart`
4. `MediaItem`
5. `MediaViewSwitcher`
6. relevant layout widget

### "Add a new media action"
Read:
1. `main_screen_actions.dart`
2. `action_mode_bottom_bar.dart`
3. `selection_state_mixin.dart`
4. download/share utilities
5. target provider if persistent

### "Improve GIF viewer"
Read:
1. `gif_viewer_screen.dart`
2. `gif_viewer_ui.dart`
3. `gif_viewer_actions.dart`
4. `gif_viewer_data_service.dart`
5. `gif_detail_screen.dart`
6. `GifItem`

### "Improve likes/history"
Read:
1. relevant provider
2. `shared_preferences_util.dart`
3. target screen
4. target media widget
5. `MediaItem` / `GifItem` identity fields

### "Add/change a view mode"
Read:
1. `view_mode.dart`
2. `view_mode_provider.dart`
3. `view_mode_selector.dart`
4. `media_view_switcher.dart`
5. all four existing layout implementations

### "Improve search"
Read:
1. `search_screen.dart`
2. main-screen search logic
3. `MediaItem`
4. feed data service
5. relevant view widget

### "Improve authentication"
Read:
1. `login_screen.dart`
2. `main.dart`
3. navigation callers
4. any future persistence/auth service

## 15. Known technical debt / improvement candidates

1. Authentication is currently local/hard-coded in `login_screen.dart`.
2. The active feed scrapes an external website directly from the client.
3. Feed networking, HTML parsing and UI-oriented result shaping are coupled.
4. `GifService` is placeholder code and is not the active main feed service.
5. Riverpod is declared but Provider is used, creating unnecessary dependency/architecture ambiguity.
6. The test suite is still the generated Flutter counter test.
7. Media identity is inconsistent across areas; some operations use URL/hash-derived identifiers while `GifItem` can generate timestamp-based IDs.
8. Main-screen state is highly concentrated in one StatefulWidget.
9. Random page selection and pagination are embedded in the data service rather than represented by a dedicated repository/pagination abstraction.
10. Download/share behavior has multiple utility paths that should be normalized before major media-action expansion.
11. The README does not document the actual application's current feature set or architecture.
12. The remote HTML selectors are an explicit breakage point and should be isolated behind a parser/repository boundary.

## 16. Feature implementation principle

For future feature requests, prefer this progression:

```
Existing feature seam
  -> identify source of truth
  -> preserve existing UI/state contracts
  -> isolate new domain logic
  -> add/update model contract
  -> update provider only if persistent/shared state is needed
  -> integrate through existing screen/widget seam
  -> add focused tests
  -> update this index when the topology changes
```

Avoid introducing a parallel architecture merely to implement a single feature.

## Phase 1 persistence layer additions
- `lib/data/local/local_database.dart` — versioned SQLite/Drift bootstrap and schema.
- `lib/data/local/local_media_repository.dart` — media, collection, membership, cache-state, and collection-media queries.
- `lib/data/local/legacy_preferences_migration.dart` — one-time migration from `liked_gifs`/`viewed_gifs` SharedPreferences payloads.
- `lib/common/providers/liked_gifs_provider.dart` and `viewed_gifs_provider.dart` — repository-backed Provider state with compatibility fallback.
- `test/local_media_repository_test.dart` — persistence, reopen, migration, collection, deduplication, and cache-state coverage.

## Phase 2 cache layer additions
- `lib/data/cache/media_cache_manager.dart` — demand-driven cache preparation, TTL validation, checksum recording, bounded collection workers, and LRU byte-budget eviction.
- `LocalMediaRepository` now exposes cache manifest listing, byte accounting, access touch, and deletion primitives.
- `DownloadAndShare` now reuses the shared cache when the app-level cache service is available.

- `MediaCacheManager` now exposes collection readiness aggregation for share-list preparation.


## 17. Current persistence, cache/share, and navigation map (2026-10-10)

The original inventory above documents the pre-persistence application baseline. The following modules are now part of the current implementation and should be consulted first for collection, cache, share, and session work.

### Local data layer
- `lib/data/local/local_database.dart` — Drift SQLite connection, explicit schema, `PRAGMA user_version`, v1→v2 migration for navigation tables.
- `lib/data/local/local_media_repository.dart` — media/collection CRUD, collection membership/share state, cache manifest operations, Spaces/Detail Tabs/SessionSnapshot persistence.
- `lib/data/local/media_identity.dart` — deterministic canonical media identity.
- `lib/data/local/legacy_preferences_migration.dart` — one-time migration of legacy liked/viewed preferences.
- `lib/data/local/session_navigation_controller.dart` — restores and mutates persistent Spaces and nested Detail Tabs; repairs invalid snapshot references at startup.
- `lib/data/local/models/` — `media_record.dart`, `collection.dart`, `collection_item.dart`, `media_cache_entry.dart`, `space.dart`, `detail_tab.dart`, `session_snapshot.dart`.

### Cache and collection sharing
- `lib/data/cache/media_cache_manager.dart` — canonical file cache, retry/backoff, expiry recovery, bounded concurrency, checksum/TTL metadata, LRU byte-budget eviction and readiness.
- `lib/data/cache/collection_share_service.dart` — single/multi-collection preparation and post-success share transitions.
- `lib/data/cache/collection_share_controller.dart` — collection loading, multi-select, readiness, preparation progress and item/collection retry.
- `lib/common/utils/download_and_share.dart` — remote media follows the canonical cache path; already-local files may be shared directly.
- `lib/main.dart` — initializes SQLite/migration and registers repository/cache/share/navigation services with Provider.

### Current test map
- `test/local_media_repository_test.dart` — media identity, 500-record storage, collection isolation/reuse, cache behavior, legacy migration, navigation persistence, and v1 schema migration.
- `test/session_navigation_recovery_test.dart` — closed/stale/cross-Space tab recovery, navigation transitions, and database close/reopen persistence.
- `test/widget_test.dart` — legacy generated smoke test; not sufficient as application-level regression coverage.

### Current phase research path
For Space/Detail Tab behavior, read:
1. `docs/project-control/SESSION_AND_NAVIGATION.md`
2. `lib/data/local/session_navigation_controller.dart`
3. `lib/data/local/local_media_repository.dart` (Space/tab/session methods)
4. `lib/data/local/models/space.dart`, `detail_tab.dart`, and `session_snapshot.dart`
5. `test/session_navigation_recovery_test.dart` and navigation tests in `test/local_media_repository_test.dart`
6. `lib/screens/main_screen/main_screen.dart` and the actual home/navigation widgets before UI integration.

For collection/cache/share work, read:
1. `lib/data/cache/collection_share_controller.dart`
2. `lib/data/cache/collection_share_service.dart`
3. `lib/data/cache/media_cache_manager.dart`
4. `lib/data/local/local_media_repository.dart`
5. `lib/common/utils/download_and_share.dart`
6. `test/local_media_repository_test.dart`

### Research-index maintenance
When adding or moving a repository, controller, provider, feature screen, or shared widget, update this index and `docs/AI_RESEARCH_PROTOCOL.md`. Do not use the historical baseline inventory above as a complete current-tree listing; use the current GitHub tree and this active-module map together.


### Phase 3 UI and content restoration — 2026-10-10
- `lib/common/widgets/session_navigation_strip.dart` — compact horizontal Space strip with create/close/select controls and a nested Detail Tab strip with select/close controls.
- `lib/screens/main_screen/main_screen.dart` — mounts the navigation strips, restores/saves per-Space feed/search/pagination/scroll state, and renders selected Detail Tab content.
- `lib/screens/main_screen/main_screen_actions.dart` — records a lightweight Detail Tab when a feed item is opened, using the active Space and local metadata; legacy detail-dialog actions remain available.
- `lib/common/widgets/detail_tab_content.dart` — local-first selected-tab view with saved title/thumbnail/source URL and an explicit external-source action.
- Feed snapshots are bounded to 120 lightweight `MediaItem` records. Runtime tests remain pending; inspect overlapping async Space restores and stale feed fetches next.


## 18. Android APK CI/CD research path (2026-10-10)

- Workflow: `.github/workflows/android-apk.yml` — builds a release APK on pushes to `main`, `feature/**`, and `feat/**`, pull requests to `main`, and manual dispatch.
- Build output: `build/app/outputs/flutter-apk/app-release.apk`; uploaded as a 30-day GitHub Actions artifact.
- Operator guide: `docs/CI_CD_ANDROID_APK.md`.
- Focused CI/CD map: `docs/AI_REPO_INDEX_CI_CD.md`.
- Android build configuration research: `pubspec.yaml`, `android/app/build.gradle`, `android/settings.gradle`, `android/build.gradle`, and `android/gradle/wrapper/gradle-wrapper.properties`.
- Signing caveat: current Android release build uses debug signing; treat the artifact as a test/install build, not a production Play Store release.
- CI/CD failures must not block independent feature implementation; inspect a failed run when practical without repeated polling.


### Phase 3 content restoration — 2026-10-10
- `lib/common/widgets/detail_tab_content.dart` — local-first content for a selected Detail Tab, showing saved title/thumbnail/source URL and opening the original URL only via an explicit safe external action.
- `lib/screens/main_screen/main_screen.dart` — bounded per-Space feed snapshot restore/save (`feed_state_json`), query/pagination/visited-page/scroll persistence, debounced state writes, and selected Detail Tab content rendering.
- Existing `BrowsingSpace` persistence fields are reused; this slice does not require a schema change. Feed snapshots are capped at 120 lightweight `MediaItem` records to avoid persisting large binary payloads.


### Phase 3 persistence contract note — 2026-10-10
- `LocalMediaRepository.updateSpace` now exposes `clearActiveDetailTabId` so callers can explicitly clear a nullable active-tab pointer without accidentally preserving the previous value.
- `SessionNavigationController` uses that option during session repair, last-tab close, and Space activation when no valid Detail Tab remains.
- `test/local_media_repository_test.dart` includes a repository assertion that closing the final Detail Tab clears the persisted Space pointer.


### Phase 3 feed snapshot restoration and Detail Tab UX update — 2026-10-10
- `lib/screens/main_screen/space_feed_snapshot.dart` parses persisted feed state, filters invalid entries, restores pagination/search/scroll metadata, caps records at 120, and marks empty/missing/malformed snapshots for fetch fallback.
- `test/space_feed_snapshot_test.dart` covers empty, absent/malformed, valid, and bounded snapshots.

### Phase 3 async restoration and Detail Tab UX update — 2026-10-10
- `lib/screens/main_screen/main_screen.dart` tracks a Space-restore generation and checks active Space identity before applying asynchronous restore/fetch results and before applying delayed scroll restoration.
- Feed fetches operate on snapshots of current items, query, and visited-page state. A fetch needed for the latest Space is queued if another request is active and started after it completes.
- The feed scroll listener is guarded when its ScrollController is detached.
- Regular feed-item opens now make the saved Detail Tab primary rather than immediately overlaying it with the legacy details dialog. `DetailTabContent` exposes a deliberate GIF options action; the special Mood & Vibe route remains.
- Regression sources cover independent per-Space feed snapshots, empty/missing/malformed/corrupt feed snapshot recovery, unsafe source URL rejection, explicit GIF options, and regular item-to-tab activation. Successful fetches schedule snapshot persistence; latest-query filtering is applied to fetched results. Runtime verification has not been run.


## 2026-10-11 — Latest navigation, persistence, and bulk-share changes
- Share path: lib/common/providers/share_queue_provider.dart persists the queue under share_queue_gifs_v1; lib/main.dart restores it before runApp. lib/data/cache/media_cache_manager.dart upserts media before cache-entry creation and supports an injectable cache directory for deterministic tests.
- Navigation path: lib/data/local/session_navigation_controller.dart normalizes URL-based media IDs before creating foreign-key-backed tabs, creates a new tab for every open, restores per-Space active tabs, and persists intentional Home-feed selection. lib/common/widgets/session_navigation_strip.dart exposes Home feed, subtabs, overview and close actions.
- Home selection path: lib/screens/main_screen/main_screen_actions.dart awaits tab creation and keeps home GIF details inside the main navigation shell.
- Regression sources: test/media_cache_manager_test.dart, test/local_media_repository_test.dart, and test/share_queue_provider_test.dart. Test/analyzer/build/device verification remains pending.
