# Current Phase

## Phase 1 — Local Media Library & Collection Engine

Status: **READY / IMPLEMENTATION AUTHORIZED**

## Objective
Build the durable local media/collection foundation defined by the completed Phase 0 contracts.

## Phase 0 completion record
Phase 0 is complete. The locked contracts are:
- docs/project-control/DATA_MODEL.md
- docs/project-control/STORAGE_AND_CACHE.md
- docs/project-control/SESSION_AND_NAVIGATION.md
- docs/project-control/PHASE0_ACCEPTANCE.md

## Phase 1 required outputs
- Drift + SQLite persistence dependency and initialization
- versioned schema and migrations
- canonical MediaRecord model/identity service
- Collection and CollectionItem models
- MediaCacheEntry metadata foundation
- repository interfaces/implementations
- liked/viewed migration where applicable
- indexes and efficient collection queries
- reusable empty collection behavior
- independent multi-list membership
- focused database/repository/migration tests

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
Phase 1 may now be implemented. Do not begin the large home redesign, full search UI, or persistent tab UI until their storage dependencies are ready.