# GIF Play Flutter — Implementation Plan

## Product objective

Transform GIF Play from a basic GIF browsing application into a persistent, browser-like GIF discovery and sharing workspace.

The requested program combines five related systems:
1. fast GIF discovery/search;
2. reusable multi-list collection/share workflow;
3. persistent local media metadata/cache;
4. browser-like persistent navigation;
5. redesigned home UX.

The implementation is deliberately phased so the storage/navigation contracts exist before the visual redesign depends on them.

---

# Phase 0 — Architecture, contracts & migration plan

**Status:** COMPLETE

### Deliverables
- canonical GIF identity contract;
- local database selection and repository interfaces;
- collection/list/item schema;
- cache manifest and eviction rules;
- Space and Detail Tab schema;
- session snapshot schema;
- search index/query contract;
- migration strategy for existing likes/viewed data;
- performance budget;
- error/offline behavior;
- UX wire-level information architecture.

### Core entities

#### MediaRecord
Stores durable metadata, not binary payload:
- stable id;
- source URL;
- media URL;
- title;
- source/site;
- width/height;
- thumbnail URL;
- created/discovered timestamp;
- last viewed;
- last used;
- optional tags/search text;
- cache state;
- schema version.

#### Collection
Reusable user-owned list:
- id;
- name;
- createdAt;
- updatedAt;
- sort mode;
- item count;
- optional cover thumbnail;
- archived flag if later needed.

#### CollectionItem
Membership/order entity:
- collectionId;
- mediaId;
- position;
- addedAt;
- share state;
- cached/download state;
- sharedAt;
- optional error state.

Important: sharing changes item state/removes it from the pending queue, but does not delete the Collection.

#### MediaCacheEntry
Tracks temporary local binary:
- mediaId;
- local path;
- byte size;
- downloadedAt;
- lastAccessedAt;
- checksum if available;
- download status;
- failure/retry information.

#### Space
Persistent top-level browsing context:
- id;
- name;
- createdAt/updatedAt;
- main feed state;
- search/filter state;
- current scroll position;
- active detail tab;
- ordered detail-tab IDs.

#### DetailTab
Nested browser-like content context:
- id;
- spaceId;
- title;
- thumbnail URL/local thumbnail;
- canonical URL/media id;
- content type;
- createdAt/lastAccessedAt;
- scroll position;
- serialized lightweight view state.

#### SessionSnapshot
Global restoration pointer:
- activeSpaceId;
- activeDetailTabId;
- lastUpdatedAt;
- app version/schema version.

### Storage design

Use a database abstraction (SQLite/Drift or equivalent selected during Phase 0) for:
- media metadata;
- collections;
- collection membership;
- spaces;
- detail tabs;
- session state;
- cache metadata.

Keep SharedPreferences for small settings only:
- theme;
- UI preferences;
- feature toggles;
- last migration version if appropriate.

Keep binary downloads in app-private cache/storage, not normal SharedPreferences and preferably not inside database rows.

### Performance target

Minimum acceptance target:
- 500+ MediaRecord rows persisted;
- 500-item collection query without loading all GIF binaries;
- smooth scrolling using lazy builders;
- search results returned without rebuilding the whole application;
- bounded memory use;
- cache downloads processed with concurrency limits;
- tab restoration does not synchronously download every remote GIF.

---

# Phase 1 — Local Media Library & Collection Engine

**Status:** IN PROGRESS (runtime/dependency verification pending)

### Work
1. Add storage dependency/abstraction.
2. Create schema and migrations.
3. Implement MediaRepository.
4. Implement CollectionRepository.
5. Implement CollectionItemRepository.
6. Add stable media identity/deduplication.
7. Persist liked/viewed records through the new media store where appropriate.
8. Build collection CRUD:
   - create;
   - rename;
   - delete/optional archive;
   - add item;
   - remove item;
   - reorder;
   - clear pending items.
9. Build multi-select collection assignment.
10. Build collection list screen/data layer.
11. Add tests for 500+ metadata records and multiple lists.

### Acceptance
Example:
- List A = 50
- List B = 100
- List C = 60
- all three persist after restart;
- sharing A drains A's pending items only;
- B/C remain unchanged;
- A remains visible as an empty reusable list;
- adding new GIFs to A works without recreating A.

---

# Phase 2 — Temporary Download / Ready-to-Share Engine

**Status:** IN PROGRESS

### Work
1. Cache manager abstraction.
2. Download queue with bounded concurrency.
3. Cache manifest.
4. Per-item states:
   - not cached;
   - downloading;
   - ready;
   - failed;
   - expired.
5. Collection-driven prefetch.
6. Prioritize currently selected list.
7. Avoid duplicate downloads across lists using media identity.
8. LRU/TTL eviction.
9. Storage quota.
10. Resume/retry rules.
11. Share operation uses local cached files first.
12. If an item is not ready, download only what is required.
13. Cache cleanup must never delete collection metadata.

### Network optimization
- One binary can satisfy multiple lists.
- Reuse already cached media.
- Download only selected/shareable items.
- Limit concurrent downloads.
- Avoid re-downloading unchanged files when checksum/metadata allows.
- Do not eagerly download all browsing history.

### Acceptance
A list selected for sharing should report readiness and share from local files whenever possible.

---

# Phase 3 — Persistent Browsing Spaces & Detail Tabs

**Status:** IN PROGRESS — persistence infrastructure slice

### User model

Recommended terminology:
- **Spaces** — persistent top-level browsing contexts.
- **Detail Tabs** — nested browser-like tabs inside each Space.

A Space represents the home/feed journey.
A Detail Tab represents an opened GIF/detail/suggestion page.

### UX

Top strip:
- compact thumbnails;
- title;
- close action;
- active indicator;
- horizontal scrolling;
- add-new Space action.

Within a Space:
- Detail Tabs appear as a second compact strip when used;
- suggestions/detail navigation opens a Detail Tab instead of destroying the Space's home state;
- user can jump between Detail Tabs;
- closing a Detail Tab returns to the previous active context;
- closing/reopening the application restores the last active Space and Detail Tab.

### Persistence
Persist every important navigation transition asynchronously:
- create Space;
- rename Space;
- open Detail Tab;
- close Detail Tab;
- change active tab;
- scroll/search/filter state;
- last active Space.

### Restoration
Startup:
1. load session snapshot;
2. load Space/tab metadata;
3. immediately render cached/local state;
4. rehydrate remote data asynchronously;
5. preserve tab identity even if remote content fails.

### Acceptance
User can open 100+ GIF/detail pages, close the application, reopen it, and see the previous Spaces/Detail Tabs and return to the last opened page without the app resetting the navigation stack.

---

# Phase 4 — Search 2.0

**Status:** PENDING

### Search UX
- prominent home search;
- debounce;
- instant local results;
- recent searches;
- clear button;
- filters;
- sorting;
- result count;
- empty/error/offline states.

### Search fields
At minimum:
- title;
- URL;
- source/site;
- metadata;
- tags when available.

### Search architecture
- Local indexed query over persisted MediaRecord.
- Remote/source adapter for discovery beyond locally known content.
- Merge/deduplicate results using canonical media identity.
- Persist useful discovered metadata.
- Paginate results.
- Do not rebuild hundreds of cards on every keystroke.

### Acceptance
Searching through hundreds of persisted GIF metadata records remains responsive and does not trigger full binary downloads.

---

# Phase 5 — Home Experience Redesign

**Status:** PENDING

### Information architecture

Home should become a workspace rather than a single feed.

Suggested structure:
1. top browser/navigation strip for Spaces;
2. search/discovery area;
3. quick collection/share-list access;
4. current feed;
5. optional secondary Detail Tab strip;
6. contextual action bar for selected GIFs;
7. persistent lightweight navigation state.

### Design principles
- browsing first;
- collections always reachable;
- sharing requires few taps;
- tab navigation is visually compact;
- GIF thumbnails are lazy-loaded;
- avoid giant widget trees;
- maintain existing light/dark themes;
- use existing Material 3 foundation;
- reuse media widgets where possible.

### Responsive behavior
Mobile:
- horizontal thumbnail strips;
- bottom sheets for collection actions;
- compact selection toolbar.

Tablet/web:
- wider multi-column layout;
- persistent side panel where useful;
- more visible tab labels.

---

# Phase 6 — Share Workflow & Collection UX

**Status:** PENDING

### Features
- select any collection;
- select multiple collections;
- select all pending items;
- see ready/not-ready count;
- share immediately from cache;
- show download progress for missing items;
- preserve collection after sharing;
- optional "share and keep" behavior should NOT delete the reusable list;
- after successful share, pending queue becomes empty while the collection remains.

### Example
Collections:
- Friends — 50
- Memes — 100
- Work — 60

User can:
- share Friends only;
- share Memes + Work;
- share all three.

After successful share:
- selected collections show 0 pending items;
- collection names remain;
- new GIFs can be added later.

---

# Phase 7 — Session Recovery, Offline Resilience & Performance

**Status:** PENDING

### Recovery cases
- normal app close;
- process killed;
- crash/restart;
- no network;
- stale remote page;
- partial cache;
- failed download.

### Rule
Local state is authoritative for user-created collections and navigation history.
Remote content is revalidation/input, not the source of truth for user navigation state.

### Performance verification
Test:
- 500+ GIF metadata records;
- 100+ detail tabs;
- 10+ Spaces;
- collections containing 50/100/60 items;
- search over 500+ records;
- cache containing hundreds of files;
- rapid tab switching;
- cold start restoration;
- low-memory conditions;
- offline restoration.

---

# Phase 8 — Hardening & Release

**Status:** PENDING

### Work
- replace placeholder tests;
- parser contract tests;
- storage migration tests;
- collection lifecycle tests;
- cache queue tests;
- restoration tests;
- widget/accessibility tests;
- performance profiling;
- error telemetry/logging;
- documentation update;
- final architecture index update.

No phase should be marked complete merely because code compiles. Evidence must be recorded in the project-control worklog.
