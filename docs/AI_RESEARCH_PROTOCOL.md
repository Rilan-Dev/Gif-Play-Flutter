# GIF Play Flutter — Research Protocol

## Purpose

This file defines how future AI-assisted development should research this repository quickly and consistently.

## Authority

- Repository: `Rilan-Dev/Gif-Play-Flutter`
- Default branch: `main`
- Index status: maintained against current main; see docs/AI_REPO_INDEX.md for the refreshed module map.
- Primary index: `docs/AI_REPO_INDEX.md`

## Before implementation

1. Read `docs/AI_REPO_INDEX.md`.
2. Locate the feature's entry screen.
3. Trace the feature's data service/actions.
4. Trace the relevant models.
5. Trace providers/persistence if state crosses screens or restarts.
6. Trace shared widgets before creating new widgets.
7. Check platform implications for Android/iOS/Web.
8. Inspect existing tests and add focused coverage.

## Search priority

Use this order unless the feature clearly points elsewhere:

```
Feature screen
  -> feature actions
  -> feature data service
  -> model
  -> provider
  -> shared widget
  -> utility
  -> platform integration
```

## Current architectural boundary

The repository has two important media representations:

- `MediaItem`: active feed/scraping/display path.
- `GifItem`: GIF detail/viewer/service/persistence-oriented path.

Do not silently merge these types during feature work. First determine whether the feature belongs to the feed path, GIF path, or both.

## Current backend boundary

The active main feed is HTML scraping through:
`MainScreenDataService.fetchData()`.

The generic `GifService` is currently placeholder code.

When replacing or improving the backend:
- introduce a clear repository/service contract;
- keep HTML parsing isolated;
- make failures explicit;
- avoid coupling widgets to HTTP;
- retain compatibility with existing providers and views where practical.

## Current implementation additions

The current repository includes Drift/SQLite persistence, cache/share orchestration, and persistent Spaces/Detail Tabs. For those areas, follow the active-module research paths in docs/AI_REPO_INDEX.md; do not rely only on the original source inventory.

Before changing navigation restoration, inspect SessionNavigationController, LocalMediaRepository, the session/space/tab models, and test/session_navigation_recovery_test.dart. Keep restoration local-first and repair stale or cross-Space tab references.

## Testing policy

The existing smoke test is not meaningful application coverage.

For each feature, prioritize tests for:
- model behavior;
- parsing/service behavior;
- provider state transitions;
- navigation;
- critical user actions;
- error/empty/loading states.

## Index maintenance

Update `docs/AI_REPO_INDEX.md` when:
- a new feature area is introduced;
- files move between architectural layers;
- a new service/provider/repository is introduced;
- a backend source changes;
- state management changes;
- the media model contract changes;
- platform-specific capabilities change.

Do not update the index for every trivial styling-only edit.

## Fast investigation examples

- Feed performance -> main screen + media widgets + cached image widget + data service.
- Better search -> search screen + main feed filter + media model + data service.
- Favorites redesign -> liked provider + persistence + liked screen + media identity.
- Viewer controls -> gif viewer directory + GIF detail + GIF model + data service.
- Sharing -> download/share utilities + file utils + share screen + platform manifests.
- New layout -> view mode enum/provider/selector/switcher + layout implementations.


## Phase 3 UI slice

The home screen now mounts `SessionNavigationStrip`, and feed item opens create durable Detail Tab metadata in the active Space. For further work, inspect `lib/common/widgets/session_navigation_strip.dart`, `lib/screens/main_screen/main_screen.dart`, `lib/screens/main_screen/main_screen_actions.dart`, and `SessionNavigationController`. Space/Detail Tab selection is now bound to visible content, per-Space feed/search/scroll state is persisted/restored, and stale async restores/fetches/post-frame scrolls are generation-guarded. Regular feed-item opens use the Detail Tab as the primary surface with an explicit GIF options action. The empty-feed restoration/fetch fallback and focused tab-open interaction now have source coverage. `SpaceFeedSnapshot` filters invalid entries, restores pagination/search/scroll metadata, and caps saved media to 120 records. MainScreen applies the latest query when a fetch completes. Next, add explicit rapid-Space-switch/in-flight-fetch regression coverage and confirm previous-Space snapshot isolation, then resume the broader home/search UX roadmap. Keep SQLite contracts unchanged unless a separately authorized schema change is needed.


## Android APK CI/CD research

For automated Android builds, read `docs/AI_REPO_INDEX_CI_CD.md` and `docs/CI_CD_ANDROID_APK.md`, then inspect `.github/workflows/android-apk.yml` and the Android Gradle configuration. APK artifacts are for testing while the release build uses debug signing. Continue unrelated implementation while CI is pending; do not repeatedly poll build runs.


## Phase 3 content restoration research path
For Space switching and selected-tab content, read `lib/screens/main_screen/main_screen.dart`, `lib/common/widgets/session_navigation_strip.dart`, `lib/common/widgets/detail_tab_content.dart`, `lib/data/local/session_navigation_controller.dart`, and `lib/data/local/local_media_repository.dart` Space/tab APIs. Feed snapshots are JSON metadata bounded to 120 `MediaItem` records and reuse existing schema fields. Add focused persistence tests before changing the serialization contract. Flutter/Dart runtime verification remains pending and is not a development blocker.
