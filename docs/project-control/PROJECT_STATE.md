# GIF Play Flutter — Project State

## Authority
- Repository: Rilan-Dev/Gif-Play-Flutter
- Branch: main
- Original application baseline: 9a0c17c973a60b0e74aac4d6efc6f047f592f217
- Repository research index: docs/AI_REPO_INDEX.md
- Research protocol: docs/AI_RESEARCH_PROTOCOL.md

## Current status
- Phase 0: COMPLETE
- Phase 1: IN PROGRESS
- Product feature implementation: persistence foundation started; major UI features remain pending.

## Current implementation
- Drift + SQLite local database initialized during app bootstrap.
- Version 1 schema stores media metadata, collections, collection membership, cache metadata, and migration state.
- Canonical media identity uses normalized URL material hashed with SHA-256.
- LocalMediaRepository provides media persistence/search, reusable collections, membership, share-state lifecycle, and cache metadata operations.
- Legacy liked/viewed JSON is imported once into durable collections; legacy SharedPreferences data is not deleted.
- Provider public APIs remain unchanged so existing screens can continue during the migration.

## Non-negotiable product invariants
- Collection/list definitions survive app restart.
- Sharing a list removes shared/pending items from that list's current queue, but NEVER deletes the list itself.
- A reusable empty list remains visible and can receive new GIFs.
- Multiple lists can coexist with independent names and item counts.
- User can share any one list or multiple selected lists.
- Target capacity is >=500 GIF records with smooth browsing and scrolling.
- Temporary downloads are used to make selected collection items ready for immediate sharing and reduce repeated network usage.
- Last opened browsing session survives process/app closure.
- Previously opened top-level browsing spaces survive.
- Detail pages opened from a space survive as nested tabs.
- Restoring a session must preserve enough state to reopen the same content even if network access is temporarily unavailable.
- UI must avoid loading hundreds of full GIF binaries into memory simultaneously.

## Next
Finish Phase 1 provider migration, persistence/reopen tests, dependency verification, cache metadata helpers, and repository indexing. Then proceed to Phase 2 only after Phase 1 acceptance evidence is recorded.


## Phase 1 implementation update
- Phase 1: IN PROGRESS
- Durable local persistence foundation is implemented.
- Liked/viewed providers are now repository-backed when created by app bootstrap.
- Legacy SharedPreferences migration is hardened and idempotent.
- Cache-state metadata helpers are ready for Phase 2.

## Current implementation continuation — Phase 2 cache
- Phase 2 cache engine development has started without waiting for CI/Vercel gates.
- `MediaCacheManager` provides demand-driven local file caching with bounded concurrency and LRU byte eviction.
- Existing share/download flow now checks the durable cache first and does not delete cache files after sharing.
- Collection-specific readiness/share orchestration is the next implementation slice.

- Collection-level cache readiness is now available for future share-list UX.
