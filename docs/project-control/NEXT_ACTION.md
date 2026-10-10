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
12. [NEXT] Add focused source coverage for rapid Space switching with an in-flight fetch and confirm previous-Space snapshot writes remain isolated; then continue the broader home/search UX roadmap. Keep runtime verification pending rather than waiting for CI/Vercel. New Detail Tabs now restore a full GIF detail surface with suggestions and a thumbnail/title overview; collections remain durable and bulk-shareable, including after prior shares.

Runtime Flutter/Dart verification remains pending in the available environment; continue implementation without waiting for CI/Vercel/runtime gates.

## Execution rule
Do not wait for GitHub Actions, Vercel deployments, or continuous verification to continue implementation. Runtime verification must be recorded honestly when unavailable, but it is not a development blocker.

## Acceptance invariants
- A collection and all its saved GIF memberships survive app restart and sharing; a reset makes previously shared GIFs pending again without deleting records.
- A shared collection remains after its pending queue reaches zero.
- Sharing one collection never changes another collection.
- Duplicate media across collections reuses one canonical cache file.
- Failed downloads remain retryable and do not silently become shared.
- Cache cleanup removes cache artifacts/manifest entries only; collection metadata survives.
- Multi-collection preparation deduplicates selected collection IDs.
- Remote sharing has one canonical download path; no legacy direct HTTP fallback remains in the share utility.
- Collection items become shared only after a successful share operation.

## Scope boundaries
- Do not redesign the entire home screen yet.
- Do not implement full Search 2.0 UI until Phase 3 navigation behavior is stable.
- Persistent Spaces/Detail Tabs UI is already in progress; extend the existing strip rather than creating a second navigation system.


## Current UI implementation note
The navigation strip, restored GIF detail/suggestions view, child-tab thumbnail overview, and bounded per-Space feed/search/pagination/scroll snapshot restoration are implemented. MainScreen now guards overlapping restore/fetch completions and delayed scroll restoration with a generation token and active Space identity; when a Space needs a fetch while another is running, its ID is queued and fetched after the in-flight request finishes. Regular feed-item opens now select the persistent Detail Tab without immediately layering the legacy GIF dialog; a deliberate GIF options action remains available from the tab. Runtime verification remains pending.


## Phase 3 implementation status — 2026-10-10
The main screen now restores per-Space feed/search/scroll state from the persisted `feed_state_json` snapshot, bounded to 120 lightweight `MediaItem` records, and writes updates with a short debounce. Selecting a Detail Tab renders a local-first content view using stored title/thumbnail/URL metadata; opening the original URL is an explicit user action. The next slice is focused regression coverage and UX edge-case cleanup. Runtime tests remain pending.
