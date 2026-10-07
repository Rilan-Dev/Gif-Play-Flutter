# Phase 0 Storage, Cache & Search Architecture

Status: **LOCKED FOR PHASE 1 IMPLEMENTATION**

## Storage layers

### Layer A — Structured local database

Use **Drift over SQLite** as the application persistence layer. Rationale: typed Dart tables/queries, explicit migrations, transactional writes, indexed queries, and a clean repository boundary for Flutter mobile/desktop/web evolution. The exact compatible package versions are pinned during Phase 1 dependency implementation.

SQLite stores metadata and relationships, not GIF binary payloads.

### Layer B — Application-private media cache

GIF binaries are files in an app-private cache/storage directory. SQLite stores only the cache manifest. File paths are never the primary media identity.

Cache writes are atomic: download to a temporary file, validate size/type when possible, rename into the final cache path, then commit the ready manifest row.

### Layer C — SharedPreferences

Only small settings belong here. It must never become a JSON database for hundreds of GIFs, collections, or tabs.

## Cache policy

Default policy is demand-driven and bounded:

1. Explicitly selected collection/share-list items receive highest priority.
2. Visible/current detail media is next.
3. Nearby/anticipated media may be prefetched only within a small concurrency/size budget.
4. Session restore never mass-downloads all historical tabs.
5. Duplicate media IDs share one cached binary.

Required cache states: notCached → downloading → ready, with failed and expired recovery paths.

Eviction is LRU/age based subject to a configurable maximum byte budget. A ready item that is currently required by an active share operation is pinned until that operation completes. Failed entries use bounded retry/backoff metadata.

## Share pipeline

1. Read pending CollectionItems in collection order.
2. Resolve each MediaRecord to a cache entry.
3. Immediately use ready local files.
4. Queue missing items with bounded concurrency.
5. Share only when the required file is ready.
6. Record success/failure per item.
7. Keep the collection and its membership intact.
8. After successful share, pending count becomes zero; the named collection remains available for reuse.

The share pipeline must not redownload a media item already cached for another collection.

## Search architecture

Search is local-first and indexed. Search fields include title, source name, tags, source URL, and media URL. Queries are debounced in the UI, normalized once, and executed against the local index/repository. Results are paged/lazy loaded.

Remote discovery is an independent source adapter. Remote results are normalized into MediaRecords and merged by canonical media ID. Remote HTML/network failure must not erase local results.

## Performance contract

The target is at least:

- 500 persisted media records without loading all binary data into RAM.
- 500 items in one collection query with lazy UI rendering.
- 50/100/60 items in three independent collections without cross-list mutation.
- 100+ DetailTabs across multiple Spaces with lightweight metadata only.
- Search over 500+ records without rebuilding the entire object graph per keystroke.
- Bounded download concurrency and bounded cache size.

Performance testing must measure cold start, database open, collection load, search latency, scrolling, tab restoration, and cache/share preparation on representative Android hardware.

## Repository boundaries

UI → application/repository interfaces → Drift repositories/cache manager → SQLite/filesystem.

Network HTML parsing stays behind a source adapter and must not be called directly from persistence/UI code.
