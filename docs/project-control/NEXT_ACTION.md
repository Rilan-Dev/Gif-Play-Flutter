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
7. [NEXT] Add focused tests for Space feed-state persistence/restoration and continue edge-case handling for rapid Space switching, empty saved feeds, and stale detail URLs. Ensure tab creation does not cause duplicate dialogs or unexpected feed loss.
8. Refresh the research index and project-control records as this integration evolves.

Runtime Flutter/Dart verification remains pending in the available environment; continue implementation without waiting for CI/Vercel/runtime gates.

## Execution rule
Do not wait for GitHub Actions, Vercel deployments, or continuous verification to continue implementation. Runtime verification must be recorded honestly when unavailable, but it is not a development blocker.

## Acceptance invariants
- A shared collection remains after its pending queue reaches zero.
- Sharing one collection never changes another collection.
- Duplicate media across collections reuses one canonical cache file.
- Failed downloads remain retryable and do not silently become shared.
- Cache cleanup removes cache artifacts/manifest entries only; collection metadata survives.
- Multi-collection preparation deduplicates selected collection IDs.
- Remote sharing has one canonical download path; no legacy direct HTTP fallback remains in the share utility.
- Collection items become shared only after a successful share operation.

## Do not do yet
- Do not redesign the entire home screen.
- Do not implement full Search 2.0 UI.
- Do not implement persistent Spaces/Detail Tabs UI.


## Current UI implementation note
The initial strip and feed-open tab recording are implemented. Detail-tab selection currently updates persisted navigation state but does not yet swap the visible page content; per-Space feed state is also not yet wired into MainScreen. These are explicit next actions, not completed behavior.


## Phase 3 implementation status — 2026-10-10
The main screen now restores per-Space feed/search/scroll state from the persisted `feed_state_json` snapshot, bounded to 120 lightweight `MediaItem` records, and writes updates with a short debounce. Selecting a Detail Tab renders a local-first content view using stored title/thumbnail/URL metadata; opening the original URL is an explicit user action. The next slice is focused regression coverage and UX edge-case cleanup. Runtime tests remain pending.
