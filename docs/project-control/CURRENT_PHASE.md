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
The visual Space/Detail Tab strips and initial content restoration are now implemented. The final-tab pointer clearing contract is fixed and has repository regression coverage. Async Space-switch/feed-fetch race handling is implemented: stale restore/fetch results and delayed scroll restorations are discarded, and the latest Space's fetch is queued when necessary. Regular feed-item opens now use the selected Detail Tab as the primary surface, with GIF options available through an explicit action. Added source coverage for unsafe source URLs and independent per-Space snapshots. Next, cover empty-feed restoration and the tab-open interaction. Keep Flutter/Dart runtime verification pending if unavailable; do not wait for CI/Vercel.


### Phase 3 — latest implementation update (2026-10-10)

- Added a local-first `DetailTabContent` view for the selected persistent tab, including preview/title/source metadata and an explicit safe external-link action.
- MainScreen now persists per-Space feed snapshots containing at most 120 lightweight `MediaItem` records plus page/visited-page/search metadata; scroll/search writes are debounced.
- Switching Spaces restores the selected Space's saved feed items, search query, pagination metadata, and scroll offset; empty/unavailable snapshots fall back to fetching the feed.
- Added `SpaceFeedSnapshot` parsing to make missing, malformed, and empty saved feeds recover by fetching fresh content; restored snapshots are filtered and bounded to 120 items.
- Source tests cover empty/missing/malformed snapshots, valid state restoration, and the item bound. Runtime verification remains pending.
- Next: harden loading-state cleanup for stale fetch completions and query changes during an in-flight request.


### Phase 3 continuation update — 2026-10-10
- Repository updates can now explicitly clear `active_detail_tab_id`; the last Detail Tab close path clears the persisted Space pointer instead of retaining a stale ID.
- Added a repository test assertion for the cleared pointer.
- Next implementation focus: avoid stale feed fetch results crossing Space boundaries and ensure the latest selected Space gets its fetch when another request is in flight.


### Async restoration update — 2026-10-10
- MainScreen now uses a restore generation and active-Space identity checks for async restore/fetch results.
- Feed fetches use snapshots rather than live mutable feed collections; pending requests for the latest Space are queued.
- Detached scroll callbacks are ignored. Runtime verification remains pending and is not a blocker.
