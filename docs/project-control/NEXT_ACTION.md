# Next Action

## Current
Phase 2 — Temporary Download / Ready-to-Share Engine is **IN PROGRESS**. Phase 1 runtime/dependency verification remains recorded as pending and is not a development blocker.

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
1. Continue collection/share hardening: preserve item-level state while retrying failed/expired items.
2. Add explicit preparation/share summaries for partial failures and empty collections.
3. Add focused tests for item retry and successful-share-only state mutation.
4. Then advance Phase 2 toward persistent browsing/session infrastructure according to IMPLEMENTATION_PLAN.md.
5. Continue project-control/index updates.

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
