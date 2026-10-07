# Decisions

## D-001 — Structured local database for persistent media metadata
Status: PLANNED

Do not use SharedPreferences as the primary store for 500+ GIF records or collection membership. Use a local database/storage abstraction with indexed metadata and efficient queries.

Reason:
- collections can contain hundreds of items;
- multiple lists require relational membership;
- search requires indexed/queryable metadata;
- session restoration needs durable structured state;
- SharedPreferences is appropriate for small settings, not a media library.

## D-002 — Binary GIFs are cache files, not the primary database payload
Status: PLANNED

Store media metadata and cache-file references in the database. Store temporary downloaded binaries in app-private cache/storage with a bounded quota and LRU/age-based eviction.

Reason:
- avoids oversized database rows;
- avoids loading hundreds of GIF binaries into memory;
- allows instant sharing when the selected list is cached;
- permits automatic cleanup of stale temporary files.

## D-003 — Collections are reusable containers
Status: PLANNED

A collection/list survives after its items are shared. Sharing drains its current pending items but never deletes the collection itself.

Example:
- Work GIFs: 50 -> share -> 0 -> Work GIFs still exists.
- Add 30 later -> Work GIFs: 30.

## D-004 — Separate top-level browsing spaces from nested detail tabs
Status: PLANNED

Use user-facing terminology based on two levels:
- Spaces = persistent top-level browsing contexts whose main content is the home/feed list.
- Detail tabs = nested browser-like tabs opened inside a Space for GIF details, suggestions, related content, etc.

The exact visual naming can be finalized during the home redesign, but the data model remains two-level.

## D-005 — Persist the complete restorable browsing snapshot
Status: PLANNED

Persist:
- active Space
- Space list
- active Detail tab per Space
- Detail tab URLs/identifiers
- thumbnail/preview metadata
- current scroll position where safely serializable
- feed/search/filter state
- relevant pagination state
- timestamps

On restore, cached/local metadata is shown immediately and remote content is revalidated asynchronously.

## D-006 — Search is indexed and debounced
Status: PLANNED

Search should query the local persisted metadata/index first, with remote/source search handled by a separate adapter when available.

Target:
- instant filtering for persisted records;
- debounce typing;
- title/source/URL metadata matching;
- pagination;
- filters and sort;
- no rebuild of the entire 500-item widget tree per keystroke.

## D-007 — Pre-download is bounded and demand-driven
Status: PLANNED

When GIFs enter a share list, the app may download them in the background into temporary cache. It should show readiness per item and prioritize the currently selected list.

Do not blindly pre-download unlimited content.

## D-008 — Existing Provider architecture is retained initially
Status: PLANNED

Do not introduce a state-management rewrite as part of this feature program. New repositories/services can feed the existing Provider layer.

## D-009 — Existing feed parser becomes an isolated backend seam
Status: PLANNED

HTML parsing/networking must remain outside widgets and be replaceable independently from the home redesign.
