# Phase 0 Session & Navigation Contract

Status: **LOCKED FOR PHASE 3 IMPLEMENTATION**

## Terminology

- **Space** = persistent top-level browsing context. It represents a home/search/discovery workspace and remains available after navigating elsewhere.
- **Detail Tab** = nested browser-like detail page inside a Space. Suggestions and related GIFs open as additional DetailTabs instead of replacing the Space.

## Space behavior

A Space owns:

- feed/search/filter state
- pagination position
- scroll position where safely restorable
- ordered DetailTab IDs
- active DetailTab
- lightweight title/thumbnail metadata

Users can create multiple Spaces. Spaces remain persistent until explicitly closed/deleted.

## Detail Tab behavior

Opening a GIF from a Space creates or activates a DetailTab. Opening a suggestion from that detail view creates a new DetailTab in the same Space unless the user explicitly chooses reuse.

Each tab stores canonical URL/media ID, title, thumbnail, timestamps, scroll state where useful, and lightweight page state. Full GIF bytes are never serialized into session state.

## Restore algorithm

On cold start:

1. Open the local database.
2. Read SessionSnapshot.
3. Restore Spaces, their tab order, active Space, and active DetailTab from local metadata.
4. Render local media/thumbnail/cache content immediately where available.
5. Revalidate remote page/feed data asynchronously.
6. If a remote URL is stale or unavailable, keep the local tab visible with stored metadata and an offline/stale indicator.
7. Never block application startup on remote HTML retrieval.

## Crash/process-kill semantics

Session state is persisted after meaningful navigation mutations, not only on graceful shutdown. Writes should be transactional and lightweight. A crash may lose only the most recent transient UI mutation; it must not destroy previously committed Spaces, collections, or tabs.

## Close semantics

Closing a DetailTab removes it from its Space's active tab set after persisting any final state needed for restoration. Closing a Space removes that browsing context explicitly. Collections/media remain independent and are not deleted as a side effect.

## Offline semantics

Local navigation, collections, search, and previously stored metadata remain usable offline. Network-dependent actions show an explicit unavailable state and can retry later. A missing remote page must not reset the user's current Space/tab structure.

## Session size

Session persistence stores IDs and small JSON state only. It must not store hundreds of GIF binaries, decoded frames, or large HTML documents.
