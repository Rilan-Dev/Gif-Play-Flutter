# Phase 0 Data Model

Status: **LOCKED FOR PHASE 1 IMPLEMENTATION**

This document is the concrete persistence contract for Gif-Play-Flutter. It is intentionally independent of UI widgets so later phases can evolve without changing storage semantics.

## 1. Canonical media identity

Every GIF is represented by a stable local `mediaId` derived from a canonical source identity. Prefer, in order:

1. Stable source/site ID when the source exposes one.
2. Canonicalized media URL + source URL hash.
3. Canonicalized media URL hash when no page URL exists.

The identity function must normalize scheme/host casing, remove known tracking parameters, and preserve meaningful path/query parameters. Identity generation must be deterministic and collision-resistant. The raw URLs remain stored for revalidation.

## 2. MediaRecord

Required fields:

- `id` (TEXT PRIMARY KEY): canonical media ID.
- `sourceUrl` (TEXT): detail/page URL when available.
- `mediaUrl` (TEXT): direct GIF/media URL.
- `thumbnailUrl` (TEXT nullable): preview URL.
- `title` (TEXT nullable).
- `sourceName` (TEXT nullable).
- `width`, `height` (INTEGER nullable).
- `mimeType` (TEXT nullable).
- `tagsText` (TEXT nullable): normalized searchable tags.
- `searchText` (TEXT): normalized title/source/tags/URLs.
- `createdAt`, `updatedAt`, `lastViewedAt` (INTEGER epoch millis).
- `lastSeenAt` (INTEGER epoch millis).
- `schemaVersion` (INTEGER).

Indexes: updated/lastViewed timestamps and search fields as required by the selected query implementation. URL lookup must be indexed/unique where safe.

## 3. Collection

A collection is reusable and survives sharing.

- `id` TEXT PRIMARY KEY
- `name` TEXT NOT NULL
- `createdAt`, `updatedAt` INTEGER
- `lastUsedAt` INTEGER nullable
- `sortOrder` INTEGER
- `isArchived` INTEGER boolean

There is no automatic deletion when a collection becomes empty.

## 4. CollectionItem

- `collectionId` TEXT FK
- `mediaId` TEXT FK
- `position` INTEGER
- `addedAt` INTEGER
- `shareState` INTEGER/enum: pending, sharing, shared, failed
- `cacheState` INTEGER/enum: notCached, downloading, ready, failed, expired
- `sharedAt` INTEGER nullable
- `lastError` TEXT nullable

Primary key: (`collectionId`, `mediaId`). Unique position is not required globally; ordering is per collection. Queries must support pending items ordered by position.

Sharing semantics: sharing a collection processes its pending items only. On success, items become shared/history but remain associated with the collection. The collection itself remains reusable. A UI action can reset selected/all shared items to pending for another share cycle without reconstructing the collection.

## 5. MediaCacheEntry

Metadata only; binary bytes live outside SQLite.

- `mediaId` TEXT PRIMARY KEY
- `localPath` TEXT
- `byteSize` INTEGER
- `downloadedAt` INTEGER
- `lastAccessedAt` INTEGER
- `expiresAt` INTEGER nullable
- `checksum` TEXT nullable
- `status` enum: downloading, ready, failed, expired
- `failureCount` INTEGER
- `lastError` TEXT nullable

## 6. Space

A Space is a persistent top-level browsing context.

- `id` TEXT PRIMARY KEY
- `name` TEXT
- `createdAt`, `updatedAt` INTEGER
- `feedType` TEXT
- `feedPage` INTEGER nullable
- `feedStateJson` TEXT nullable
- `searchQuery` TEXT nullable
- `filterStateJson` TEXT nullable
- `scrollOffset` REAL nullable
- `activeDetailTabId` TEXT nullable
- `sortOrder` INTEGER

## 7. DetailTab

A Detail Tab is nested inside a Space.

- `id` TEXT PRIMARY KEY
- `spaceId` TEXT FK
- `mediaId` TEXT nullable
- `canonicalUrl` TEXT nullable
- `title` TEXT nullable
- `thumbnailUrl` TEXT nullable
- `openedAt`, `updatedAt`, `lastAccessedAt` INTEGER
- `scrollOffset` REAL nullable
- `stateJson` TEXT nullable
- `sortOrder` INTEGER
- `isClosed` INTEGER boolean

Detail tabs can contain suggestion navigation without replacing the parent Space.

## 8. SessionSnapshot

One authoritative restorable session row:

- `id` INTEGER PRIMARY KEY CHECK(id = 1)
- `activeSpaceId` TEXT nullable
- `activeDetailTabId` TEXT nullable
- `updatedAt` INTEGER
- `schemaVersion` INTEGER

The session references persistent Spaces/DetailTabs rather than serializing hundreds of media binaries.

## 9. Small settings

SharedPreferences remains appropriate for non-relational, low-volume settings such as theme, view mode, onboarding flags, cache policy preferences, and last-selected lightweight UI options. It is not the source of truth for media records, collections, tabs, or session graphs.

## 10. Relationships

- MediaRecord 1:N CollectionItem
- Collection 1:N CollectionItem
- MediaRecord 1:1 MediaCacheEntry
- Space 1:N DetailTab
- SessionSnapshot 1:1 active Space/DetailTab references

Foreign-key cleanup must be deliberate. Deleting a media record must not silently delete a user collection; Phase 1 should prefer retaining metadata while removing orphaned records only through an explicit maintenance policy.

## 11. Migration contract

Database schema versions are monotonic. Every migration must be forward-only, transaction-safe, and covered by a migration test. Existing liked/viewed state must migrate into collections/media records without losing user intent.
