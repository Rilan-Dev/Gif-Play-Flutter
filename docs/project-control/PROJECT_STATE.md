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
- Collection definitions and memberships are stored in SQLite. The Collections screen refreshes persistent records on entry and displays saved item counts, including shared items; clear compatibility calls reset items to pending instead of deleting membership. Bulk sharing tolerates selected empty collections, and each collection has an explicit non-destructive reset-to-share action.
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
