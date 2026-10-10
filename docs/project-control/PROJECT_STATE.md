# GIF Play Flutter — Project State

## Authority
- Repository: Rilan-Dev/Gif-Play-Flutter
- Branch: main
- Original application baseline: 9a0c17c973a60b0e74aac4d6efc6f047f592f217
- Repository research index: docs/AI_REPO_INDEX.md
- Research protocol: docs/AI_RESEARCH_PROTOCOL.md

## Current status
- Phase 0: COMPLETE
- Phase 1: IN PROGRESS (implementation complete; runtime/dependency verification pending)
- Phase 2: IN PROGRESS (core implementation slice complete; runtime verification pending)
- Phase 3: IN PROGRESS (persistent navigation, per-Space feed restoration, and Detail Tab UX)
- Product feature implementation: local persistence, cache/share infrastructure, persistent Spaces/Detail Tabs, and feed-state restoration are under active development; broader home-screen redesign and Search 2.0 remain pending.

## Current implementation
- Drift + SQLite local database initialized during app bootstrap.
- Version 1 schema stores media metadata, collections, collection membership, cache metadata, and migration state.
- Canonical media identity uses normalized URL material hashed with SHA-256.
- LocalMediaRepository provides media persistence/search, reusable collections, membership, share-state lifecycle, and cache metadata operations.
- Legacy liked/viewed JSON is imported once into durable collections; legacy SharedPreferences data is not deleted.
- Provider public APIs remain compatible while app bootstrap uses repository-backed state.
- MediaCacheManager provides durable filesystem caching with SQLite manifest, bounded collection preparation, TTL, checksum, retry/backoff, expired-file recovery, and byte-budget LRU maintenance.
- CollectionShareService provides reusable single/multi-collection preparation and successful-share state transitions.
- DownloadAndShare now uses the canonical cache path for remote media and direct sharing only for already-local files.
- CollectionShareController exposes reusable multi-select collection state, readiness, preparation progress, and errors to UI consumers.
- Regression test sources cover cache retry, cleanup preserving collection metadata, collection selection/retry, empty-share safety, persistent navigation restoration, independent per-Space feed snapshots, and Detail Tab source URL/action behavior.
- MainScreen rejects stale feed-fetch completions and delayed scroll restores using a generation token plus active-Space identity. Regular item opens focus the selected Detail Tab; the tab now rebuilds its GIF detail view and source-page suggestions, and chosen suggestions open as child tabs. The tab strip and Brave-style bottom bar include a thumbnail/title overview dialog.
- Bulk Share Queue preparation had a concrete path bug: fallback queue keys like `url:https://...` were being used as cache filenames. Fallback IDs now become stable MediaIdentity hashes, and the cache manager hashes arbitrary IDs before filesystem use. Share payloads explicitly declare `image/gif`, deduplicate file paths, check file existence, and return accurate success/failure status. Added a cache filename regression test source; runtime verification remains pending.\n- Collection definitions and memberships are stored in SQLite. The Collections screen refreshes persistent records on entry and displays saved item counts, including shared items; clear compatibility calls reset items to pending instead of deleting membership. Bulk sharing tolerates selected empty collections, and each collection has an explicit non-destructive reset-to-share action.
- Flutter/Dart tests and analyzer have not been run for the latest changes; verification remains pending and is not a development gate.

## Non-negotiable product invariants
- Collection/list definitions survive app restart.
- Sharing a list removes shared/pending items from that list's current queue, but NEVER deletes the list itself.
- A reusable empty list remains visible and can receive new GIFs.
- Multiple lists can coexist with independent names and item counts.
- User can share any one list or multiple selected lists.
- Target capacity is >=500 GIF records with smooth browsing and scrolling.
- Temporary downloads are used to make selected collection items ready for immediate sharing and reduce repeated network usage.
- Last opened browsing session survives process/app closure.
- Previously opened top-level browsing spaces survive.
- Detail pages opened from a space survive as nested tabs.
- Restoring a session must preserve enough state to reopen the same content even if network access is temporarily unavailable.
- UI must avoid loading hundreds of full GIF binaries into memory simultaneously.

## Next
Phase 3 persistence infrastructure remains active. Startup creates a durable Home Space and now repairs invalid, closed, stale, or cross-Space active-tab references. Controller transition and database close/reopen regression sources have been added. The initial visual Space/Detail Tab strips are now mounted on the home screen and feed opens persist lightweight Detail Tab metadata. Per-Space feed/search/scroll restoration is now wired through the existing `feed_state_json`, `search_query`, `feed_page`, and `scroll_offset` fields; Detail Tab selection renders a local-first content view from saved metadata. Last-tab pointer clearing is fixed and covered by a repository regression assertion. Async Space-switch/feed-fetch race handling and stale post-frame scroll protection are implemented. Regular item opens use the selected Detail Tab as the primary surface, with explicit GIF options available from the tab. `SpaceFeedSnapshot` now recovers from missing, malformed, or empty saved feeds by triggering a fresh fetch; regression sources cover snapshot parsing, bounds, and fallback decisions. In-flight feed results now derive filtered items from the latest visible search query instead of applying stale filtered results. Next is focused rapid-Space-switch regression coverage and suggestion-to-child-tab/overview interaction coverage, then broader home/search improvements. Runtime tests remain pending. Flutter/Dart runtime verification remains pending; do not wait for CI/Vercel/runtime gates, and record verification status honestly.


## 2026-10-11 — User-reported build 28 regressions and follow-up fixes
- New confirmed source-level failure paths: share-queue cache insertion could violate the media-record foreign key; child-tab creation could violate the same foreign key because callers supplied an image URL as a media ID.
- Fixed both paths by upserting media records before cache entries and normalizing URL-shaped tab media IDs to stable MediaIdentity IDs.
- Child-tab opens no longer deduplicate/re-activate an existing tab. Each explicit GIF selection creates a new child tab.
- Home feed is now an explicit selectable navigation surface beside child tabs. Selecting it persists a null active-tab pointer; the tab overview has direct close controls. Legacy special-domain home clicks no longer push a separate detail route that hides the navigation shell.
- Share Queue is now persisted locally and restored before the app UI is shown. Collection persistence is SQLite-backed; file-backed reopen coverage already exists. Test source added for share queue restoration and navigation/cache regressions.
- Current verification remains pending: Flutter tests/analyzer/build/device retest were not executed by this assistant. The user reports build 28 still has the issue; the next APK must include these newer commits.


## 2026-10-11 continued work — Navigation, lifecycle, and search
- Added controller regression source for concurrent Space switches and widget coverage for Home feed, child-tab reactivation, tab overview, and close-from-overview.
- Added deterministic suggestion-loader injection and a widget test source confirming a selected suggestion opens a new child tab.
- MainScreen now flushes debounced feed/search/pagination/scroll state when the app backgrounds and flushes serialized Share Queue writes.
- Search field visibility follows a restored non-empty query; local matching now checks title, source URL and image URL using a shared helper.
- Runtime test/analyzer/APK/device verification remains pending; development continues without waiting for CI/Vercel.


- Further edge-case hardening: closing the active Space now restores the destination Space's persisted active tab or Home feed, and closing an active child tab refreshes the in-memory Space pointer after the database update.


- MainScreen now queues an overlapping fetch when the requested/current Space differs from the Space owning the active fetch. Same-Space duplicate requests are ignored to avoid repeated redundant fetches; the pure policy is covered by test/space_fetch_policy_test.dart.
