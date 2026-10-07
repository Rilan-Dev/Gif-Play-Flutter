# Decisions

## D-001 — Structured local database for persistent media metadata
Status: **LOCKED**

Use **Drift + SQLite** for structured local persistence. SharedPreferences is limited to small settings.

Reason: typed schema, transactions, migrations, indexed queries, relational collection membership, and durable session state are required for the target workload.

## D-002 — Binary GIFs are cache files, not the primary database payload
Status: **LOCKED**

Store media metadata and cache-file references in SQLite. Store temporary downloaded binaries in app-private cache/storage with bounded quota and LRU/age-based eviction.

## D-003 — Collections are reusable containers
Status: **LOCKED**

A collection/list survives after its items are shared. Sharing drains its current pending queue but never deletes the collection itself.

Example: Work GIFs 50 → share → 0 → Work GIFs remains and can receive new GIFs.

## D-004 — Separate top-level browsing spaces from nested detail tabs
Status: **LOCKED**

Use two architectural levels:
- Spaces = persistent top-level browsing contexts whose main content is a home/feed/search list.
- Detail Tabs = nested browser-like detail pages opened inside a Space.

## D-005 — Persist the complete restorable browsing snapshot
Status: **LOCKED**

Persist active Space, Spaces, active DetailTab, tab URLs/identifiers, thumbnails/preview metadata, safe scroll position, feed/search/filter state, pagination, and timestamps. Restore local state first and revalidate remote content asynchronously.

## D-006 — Search is indexed and debounced
Status: **LOCKED**

Search persisted local metadata first through an indexed repository; remote discovery is a separate source adapter. Normalize/debounce queries and merge remote results by canonical media ID.

## D-007 — Pre-download is bounded and demand-driven
Status: **LOCKED**

Selected share-list items receive highest cache priority. Ready files are reused across collections. No unlimited pre-download.

## D-008 — Existing Provider architecture is retained initially
Status: **LOCKED**

Do not introduce a state-management rewrite as part of this program. New repositories/services feed the existing Provider layer.

## D-009 — Existing feed parser becomes an isolated backend seam
Status: **LOCKED**

HTML parsing/networking stays outside widgets and behind a replaceable source adapter.


## D-010 — Phase 1 database implementation seam
Status: **LOCKED FOR CURRENT IMPLEMENTATION SLICE**

The first persistence implementation uses Drift's DatabaseConnectionUser with prepared custom SQL APIs and an explicit versioned SQLite schema. This avoids committing generated Drift artifacts while the repository remains on Dart SDK ^3.6. The domain and repository boundaries remain independent of this implementation detail.

The dependency versions are constrained by the existing Dart SDK. Drift 2.32.1 and drift_dev 2.32.1 support Dart 3.5+, while newer Drift releases require newer Dart SDKs.
