# Current Phase

## Phase 1 — Local Media Library & Collection Engine
Status: **IN PROGRESS (runtime/dependency verification pending; development continues)**

The persistence foundation, provider migration, migration hardening, reopen-test source, and cache-state primitives are implemented. Runtime verification remains pending because the available execution environment does not provide Flutter/Dart.

## Phase 2 — Temporary Download / Ready-to-Share Engine
Status: **IN PROGRESS**

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

### Next implementation slice
1. Normalize the existing duplicate `DownloadAndShareGif` implementation onto `MediaCacheManager`.
2. Wire `CollectionShareService` into the existing share flow.
3. Build the reusable collection/share-list data layer and UI.
4. Propagate readiness/progress/error state to that workflow.
5. Add focused source-level regression coverage for retry, expiry, maintenance, and orchestration.

## Phase boundary
Do not start the large home redesign, full Search 2.0 UI, or persistent Spaces/Detail Tabs UI until the collection/share infrastructure is sufficiently implemented and the authorized phase boundary is explicitly advanced.
