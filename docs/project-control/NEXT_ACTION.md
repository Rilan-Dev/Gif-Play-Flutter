# Next Action

## Current
Phase 3 — Persistent Browsing Spaces & Detail Tabs is **IN PROGRESS**. Phase 1/2 runtime and dependency verification remains pending and is not a development blocker.

## Completed development slices
- Phase 1 SQLite persistence foundation and repository-backed liked/viewed state.
- Legacy migration hardening and idempotency coverage.
- File-backed persistence/reopen test source.
- Repository cache-state primitives.
- Shared `MediaCacheManager` with cache reuse, bounded collection preparation, TTL, checksum, and byte-budget LRU eviction.
- Retry/backoff recovery with explicit expired/missing-file recovery.
- Cache maintenance cleanup without deleting collection metadata.
- Reusable `CollectionShareService` for single/multiple collection preparation and successful-share state transition.
- Existing `DownloadAndShare` normalized so remote downloads use `MediaCacheManager`; local files are shared directly without duplicate downloads.
- `CollectionShareService` registered at app bootstrap and exposed to the share utility.
- Reusable `CollectionShareController` added for collection loading, multi-select, readiness, preparation progress, and failure state.
- Focused regression source added for cache retry, cache cleanup, collection preservation, and collection-selection deduplication.

## Immediate next implementation sequence
1. [x] Add controller-level activation/close transition coverage and assert snapshot persistence.
2. [x] Repair startup restoration for invalid, closed, stale, and cross-Space detail-tab references; persist the corrected snapshot.
3. [x] Add database close/reopen coverage for Spaces, Detail Tabs, and SessionSnapshot; retain the existing v1-to-v2 migration test.
4. [x] Add the initial visual Space/Detail Tab UI layer through the existing Provider/controller boundary: compact horizontally scrollable Space chips, create/close/select actions, nested Detail Tab chips, and feed-open tab metadata persistence.
5. [x] Render selected Detail Tab content from its saved title, thumbnail, and canonical URL, with a safe external-source action.
6. [x] Persist and restore per-Space feed state (bounded to 120 lightweight media records), current page metadata, visited pages, search query, and scroll offset; debounce persistence during scrolling/search changes.
7. [x] Add a repository regression assertion that closing the final Detail Tab clears the Space's persisted active-tab pointer.
8. [x] Guard overlapping Space restores with a generation token; discard stale restore results and stale feed-fetch completions, and queue a fetch for the latest active Space if an earlier request is still in flight.
9. [x] Finish edge-case behavior: ignore stale post-frame scroll restoration, guard scroll callbacks when the feed is detached, and make feed-item opening consistent with selected Detail Tab content instead of layering competing navigation/dialog surfaces.
10. [x] Extract resilient `SpaceFeedSnapshot` restoration and add source coverage for empty, missing, malformed, valid, and bounded snapshots; empty/unavailable saved content is marked for a fresh feed fetch.
11. [x] Harden fetch lifecycle ownership: each active fetch has a request generation, and only that request may clear loading state or drain the queued Space fetch. Successful fetches schedule a debounced snapshot save, and results are filtered using the latest query.
12. [x] Add regression source for queue-only cache preparation/foreign-key safety, repeated same-GIF child tabs, URL media-ID normalization, per-Space active tabs, Home-feed restoration, and Share Queue persistence.
13. [x] Add regression source for rapid concurrent Space switches, Home/tab/overview interactions, and suggestion-to-child-tab creation; improve copyable bulk-share diagnostics.
14. [NEXT] Continue focused home/search UX and state-recovery work: inspect feed item actions and empty/error/loading states, review collection/tab persistence contracts, and add any missing regression coverage. Device retest remains pending because build 28 predates these commits.

Runtime Flutter/Dart verification remains pending in the available environment; continue implementation without waiting for CI/Vercel/runtime gates.

## Execution rule
Do not wait for GitHub Actions, Vercel deployments, or continuous verification to continue implementation. Runtime verification must be recorded honestly when unavailable, but it is not a development blocker.

## Acceptance invariants
- A collection and all its saved GIF memberships survive app restart and sharing; a reset makes previously shared GIFs pending again without deleting records.
- A shared collection remains after its pending queue reaches zero.
- Sharing one collection never changes another collection.
- Duplicate media across collections reuses one canonical cache file.
- Failed downloads remain retryable and do not silently become shared. Queue fallback IDs must never be interpolated into filesystem paths; share payloads must use a declared image/GIF MIME type.
- Cache cleanup removes cache artifacts/manifest entries only; collection metadata survives.
- Multi-collection preparation deduplicates selected collection IDs.
- Remote sharing has one canonical download path; no legacy direct HTTP fallback remains in the share utility.
- Collection items become shared only after a successful share operation.

## Scope boundaries
- Do not redesign the entire home screen yet.
- Do not implement full Search 2.0 UI until Phase 3 navigation behavior is stable.
- Persistent Spaces/Detail Tabs UI is already in progress; extend the existing strip rather than creating a second navigation system.


## Current UI implementation note
The navigation strip, restored GIF detail/suggestions view, child-tab thumbnail overview, Brave-style bottom tab control, and bounded per-Space feed/search/pagination/scroll snapshot restoration are implemented. MainScreen now guards overlapping restore/fetch completions and delayed scroll restoration with a generation token and active Space identity; when a Space needs a fetch while another is running, its ID is queued and fetched after the in-flight request finishes. Regular feed-item opens now select the persistent Detail Tab without immediately layering the legacy GIF dialog; a deliberate GIF options action remains available from the tab. Runtime verification remains pending.


## Phase 3 implementation status — 2026-10-10
The main screen now restores per-Space feed/search/scroll state from the persisted `feed_state_json` snapshot, bounded to 120 lightweight `MediaItem` records, and writes updates with a short debounce. Selecting a Detail Tab renders the saved GIF preview/title, reloads source-page suggestions, and offers an explicit safe source action. Choosing a suggestion opens a persistent child tab; the tab strip and bottom bar open a thumbnail/title overview. The next slice is focused rapid-Space-switch and child-tab interaction regression coverage. Runtime tests remain pending.


## 2026-10-11 user-reported regression priority
- [x] Fix queue cache preparation by ensuring media rows exist before cache-entry foreign keys are written.
- [x] Fix tab creation by normalizing URL-shaped IDs to a persisted media record before writing detail_tabs.
- [x] Always create a new child tab for each explicit GIF selection; add persistent Home-feed selection and tab overview close controls.
- [x] Persist and restore the Share Queue across app launches.
- [x] Add focused interaction coverage and improve visible/share-stage diagnostics. Flutter runtime verification remains pending; do not block development on CI/Vercel. Build 28 does not contain these commits.


## 2026-10-11 follow-up — navigation regressions and lifecycle flush
- [x] Add rapid concurrent Space-switch regression source that checks final session snapshot and independent per-Space active tab pointers.
- [x] Add widget regression source for Home feed ↔ child-tab navigation, tab overview visibility, and closing a tab from the overview.
- [x] Flush the debounced Space feed/search/pagination/scroll snapshot when the app backgrounds, and flush queued Share Queue writes through its serialized persistence chain.
- [x] Add explicit suggestion-to-child-tab interaction coverage and review the lifecycle of tabs/collections after process recreation. Continue focused home/search UX improvements without a broad redesign; tests/analyzer/build/device verification remain pending.


## 2026-10-11 follow-up — suggestions and focused search behavior
- [x] Add deterministic suggestion-to-child-tab widget coverage via an injectable loader.
- [x] Restore the search input visibility when restoring a non-empty Space query.
- [x] Make local search match title, source URL, and image URL, and add focused unit-test source.
- [x] Restore search visibility and shared title/source/image URL matching; keep current navigation contracts and add focused tests. Continue remaining empty/error/loading and collection persistence review under the current NEXT action.


- [x] Preserve destination Space tab/Home-feed selection when closing the currently active Space; refresh in-memory active-tab pointers after closing the current child tab.
- [x] Add suggestion-to-child-tab widget test source, shared title/source/image URL search matching, and query visibility restoration.


- [x] Preserve pagination requests for a newly active Space while a previous Space fetch is still in flight, without queueing duplicate same-Space requests; add focused policy tests.


- [x] Make feed loading, empty-search, and fetch-error states mutually exclusive and actionable.
- [x] Expose user-created named collections in the UI and allow selected GIFs to be saved into durable SQLite collection memberships without replacing Share Queue functionality.
- [x] Add controller regression source for creating a named collection and saving/restoring its GIF membership.
