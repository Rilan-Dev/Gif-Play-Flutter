# Current Phase

## Phase 1 — Local Media Library & Collection Engine

Status: **IN PROGRESS**

## Completed in this phase
- Drift + SQLite dependency direction added using versions compatible with the repository's Dart 3.6 SDK constraint.
- Local database bootstrap and schema version 1 created.
- MediaRecord domain model and deterministic SHA-256 identity created.
- Collection and CollectionItem domain models created.
- MediaCacheEntry metadata model created; binary cache remains Phase 2.
- LocalMediaRepository created with media CRUD/search, collection CRUD/membership, share-state lifecycle, and cache metadata operations.
- Legacy liked/viewed JSON migration created and wired into app bootstrap without deleting legacy SharedPreferences data.
- Focused repository tests created for 500 records, 50/100/60 independent collections, reusable empty-after-share behavior, deterministic identity, and deduplicated membership.

## Remaining Phase 1 work
1. Verify dependency resolution/build on the project-supported Flutter SDK and update the lockfile through the normal package manager.
2. Review the migration against real legacy data shapes and edge cases.
3. Connect existing LikedGifsProvider/ViewedGifsProvider to repository-backed state while retaining their public UI contract. **DONE (startup now injects LocalMediaRepository; legacy constructor fallback remains for compatibility).**
4. Add cache-state update helpers needed by Phase 2.
5. Add repository/provider integration tests and migration idempotency coverage. **PARTIAL: repository/reopen/cache/migration regression tests added; provider-specific runtime tests remain pending Flutter execution.**
6. Replace or supplement the generated counter test with real application persistence coverage.
7. Update the research index for the new data layer.

## Phase 1 completion criteria
- 500+ MediaRecords can persist/query without SharedPreferences.
- Collection definitions survive restart, including empty collections.
- Multiple collections remain independent.
- Collection membership is deduplicated by canonical media identity.
- Database migrations are versioned and tested.
- Repository APIs do not expose UI-specific state.
- No GIF binary payload is stored in ordinary database rows.
- Tests cover create/add/remove/share-state/reset and persistence/reopen behavior.

## Gate
Do not start the large home redesign, full Search 2.0 UI, or persistent Spaces/Detail Tabs UI until Phase 1 is complete.
## Phase 2 — Temporary Download / Ready-to-Share Engine

Status: **IN PROGRESS (development continues without waiting for Phase 1 CI/runtime gate)**

### Implemented slice
- Shared `MediaCacheManager` added under `lib/data/cache/`.
- Cache manifest remains in SQLite; GIF bytes remain filesystem files.
- Cache filenames use canonical media IDs, preventing duplicate binaries across collections.
- Existing GIF download/share flow now reuses the shared cache when available.
- Cached files are retained after sharing; non-share downloads still create the existing `saved_` copy.
- Bounded concurrent collection preparation is implemented with a configurable worker limit.
- Cache TTL, ready-file validation, checksum recording, and byte-budget LRU eviction are implemented.
- Cache state is reflected on collection items during preparation.

### Next implementation slice
1. Connect collection-specific preparation to the future collection/share-list workflow.
2. Add share readiness/status aggregation (ready/downloading/failed/not-cached).
3. Normalize the duplicate `DownloadAndShareGif` implementation onto the cache service.
4. Add retry/backoff and explicit expired-entry handling.
5. Add cache cleanup controls without deleting collection metadata.
6. Continue toward collection UI/data-layer implementation.

- Collection readiness aggregation is implemented for the upcoming share-list workflow.
