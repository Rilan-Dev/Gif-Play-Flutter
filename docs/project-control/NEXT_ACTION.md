# Next Action

## Current
Phase 2 — Temporary Download / Ready-to-Share Engine is **IN PROGRESS**. Phase 1 runtime/dependency verification remains recorded as pending and is not a development blocker.

## Completed development slices
- Phase 1 SQLite persistence foundation and repository-backed liked/viewed state.
- Legacy migration hardening and idempotency coverage.
- File-backed persistence/reopen test source.
- Repository cache-state primitives.
- Shared `MediaCacheManager` with cache reuse, bounded collection preparation, TTL, checksum, and byte-budget LRU eviction.
- Collection-level cache readiness aggregation.
- Retry/backoff recovery for cache downloads with configurable retry count and base delay.
- Explicit expired/missing-file recovery.
- Cache maintenance cleanup for expired/failed entries without deleting collection metadata.
- Reusable `CollectionShareService` for single/multiple collection preparation and successful-share state transition.

## Immediate next implementation sequence
1. Normalize the existing duplicate `DownloadAndShareGif` implementation onto the shared cache path.
2. Wire `CollectionShareService` into the existing share flow without redesigning the home screen.
3. Add a user-facing collection/share-list data layer for reusable collections and multi-select sharing.
4. Add progress/status propagation for ready/downloading/failed/not-cached states.
5. Add focused source-level regression coverage for retry/expiry/maintenance and collection-share orchestration.
6. Continue project-control/index updates after each coherent slice.

## Execution rule
Do not wait for GitHub Actions, Vercel deployments, or continuous verification to continue implementation. Runtime verification must be recorded honestly when unavailable, but it is not a development blocker.

## Acceptance invariants
- A shared collection remains after its pending queue reaches zero.
- Sharing one collection never changes another collection.
- Duplicate media across collections reuses one canonical cache file.
- Failed downloads remain retryable and do not silently become shared.
- Cache cleanup removes cache artifacts/manifest entries only; collection metadata survives.
- Multi-collection preparation deduplicates selected collection IDs.

## Do not do yet
- Do not redesign the entire home screen.
- Do not implement full Search 2.0 UI.
- Do not implement persistent Spaces/Detail Tabs UI.
