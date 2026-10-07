# GIF Play Flutter — Project State

## Authority
- Repository: Rilan-Dev/Gif-Play-Flutter
- Branch: main
- Original application baseline: 9a0c17c973a60b0e74aac4d6efc6f047f592f217
- Repository research index: docs/AI_REPO_INDEX.md
- Research protocol: docs/AI_RESEARCH_PROTOCOL.md

## Current status
- Phase 0: COMPLETE
- Phase 1: IN PROGRESS (implementation complete; runtime/dependency verification pending)
- Phase 2: IN PROGRESS
- Product feature implementation: local persistence and cache/share infrastructure are under active development; major UI redesign remains pending.

## Current implementation
- Drift + SQLite local database initialized during app bootstrap.
- Version 1 schema stores media metadata, collections, collection membership, cache metadata, and migration state.
- Canonical media identity uses normalized URL material hashed with SHA-256.
- LocalMediaRepository provides media persistence/search, reusable collections, membership, share-state lifecycle, and cache metadata operations.
- Legacy liked/viewed JSON is imported once into durable collections; legacy SharedPreferences data is not deleted.
- Provider public APIs remain compatible while app bootstrap uses repository-backed state.
- MediaCacheManager provides durable filesystem caching with SQLite manifest, bounded collection preparation, TTL, checksum, retry/backoff, expired-file recovery, and byte-budget LRU maintenance.
- CollectionShareService provides reusable single/multi-collection preparation and successful-share state transitions.

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
Normalize the existing DownloadAndShareGif implementation onto MediaCacheManager, wire CollectionShareService into the existing share flow, then continue the reusable collection/share-list data layer. Do not wait for CI/Vercel/runtime gates; record verification status honestly.
