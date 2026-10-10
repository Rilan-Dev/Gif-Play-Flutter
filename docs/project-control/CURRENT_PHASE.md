# Current Phase

## Phase 1 — Local Media Library & Collection Engine
Status: **IN PROGRESS (runtime/dependency verification pending; development continues)**

The persistence foundation, provider migration, migration hardening, reopen-test source, and cache-state primitives are implemented. Runtime verification remains pending because the available execution environment does not provide Flutter/Dart.

## Phase 2 — Temporary Download / Ready-to-Share Engine
Status: **IN PROGRESS (core implementation slice complete; runtime verification pending)**

### Implemented
- Shared `MediaCacheManager`.
- SQLite cache manifest with filesystem GIF bytes.
- Canonical media-ID cache filenames.
- Ready-file reuse and access-time tracking.
- Bounded concurrent collection preparation.
- TTL and checksum metadata.
- Byte-budget LRU eviction.
- Collection cache-state propagation.
- Collection readiness aggregation.
- Retry/backoff with configurable retries.
- Explicit expired/missing-file recovery.
- Maintenance cleanup for expired/failed cache entries.
- `CollectionShareService` for single/multiple collection preparation and post-success share-state transitions.
- Canonicalized `DownloadAndShare` remote download path; local file sharing remains supported.
- App-level Provider registration for cache/share orchestration.
- `CollectionShareController` for reusable selection, readiness, progress, and error state.
- Regression test source for retry, cleanup, collection preservation, and collection selection.

## Phase 3 — Persistent Browsing Spaces & Detail Tabs
Status: **IN PROGRESS — persistence infrastructure slice**

### Implemented
- Schema v2 tables for Spaces, Detail Tabs, and SessionSnapshot.
- Forward migration from schema v1 to v2.
- LocalMediaRepository CRUD and session snapshot APIs.
- SessionNavigationController for restore, activation, tab open/close, and persistent navigation mutations.
- App bootstrap registration.
- Source-level migration, persistence, and restoration tests.

### Next
Continue invalid/closed-tab restoration hardening and migration/reopen coverage before building the visual Space/Detail Tab strips.


### Phase 3 — latest implementation update (2026-10-10)

- Added a local-first `DetailTabContent` view for the selected persistent tab, including preview/title/source metadata and an explicit safe external-link action.
- MainScreen now persists per-Space feed snapshots containing at most 120 lightweight `MediaItem` records plus page/visited-page/search metadata; scroll/search writes are debounced.
- Switching Spaces restores the selected Space's saved feed items, search query, pagination metadata, and scroll offset; empty/unavailable snapshots fall back to fetching the feed.
- Remaining: focused tests for feed snapshot persistence/restoration and edge cases around fast Space switching and tab-open behavior. Runtime verification remains pending.
