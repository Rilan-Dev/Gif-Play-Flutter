# GIF Play Flutter — Project State

## Authority
- Repository: Rilan-Dev/Gif-Play-Flutter
- Branch: main
- Original application baseline: 9a0c17c973a60b0e74aac4d6efc6f047f592f217
- Repository research index: docs/AI_REPO_INDEX.md
- Research protocol: docs/AI_RESEARCH_PROTOCOL.md

## Program
Large UX/data-layer improvement program:
1. GIF search
2. persistent multi-list collections/share lists
3. redesigned home experience
4. local storage capacity for at least 500 GIF records without UI degradation
5. temporary pre-download cache for ready-to-share GIFs
6. persistent browser-like browsing/session restoration
7. persistent top-level browsing spaces and nested detail tabs
8. ChatGPT-session-independent project-control documentation

## Current status
- Planning: COMPLETE for Phase 0
- Implementation: NOT STARTED for product features
- Phase 0: COMPLETE
- Phase 1: READY / AUTHORIZED
- No production feature code was changed during Phase 0.

## Locked architecture
- Drift + SQLite is the source of truth for structured local media/collection/navigation metadata.
- SharedPreferences is limited to small settings.
- GIF binaries live in a bounded app-private cache, not ordinary database rows.
- Collections remain after sharing and can be reused when empty.
- Spaces contain persistent nested DetailTabs.
- Session restore is local-first and remote-revalidation-second.
- Search is local indexed metadata first, with remote discovery isolated behind an adapter.
- Provider remains the initial state-management layer.

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

## Current architecture observations
- Provider is the active state-management mechanism.
- SharedPreferences is currently used for lightweight persistence.
- Main feed uses MainScreenDataService and HTML parsing.
- MediaItem is the main feed representation.
- GifItem is used by GIF/detail/viewer paths.
- MediaViewSwitcher is the main presentation router.
- Existing widget test is only the generated Flutter counter test.

## Next
Implement Phase 1 from the locked contracts. Start with database bootstrap/schema/migrations, then MediaRecord and collection repositories, followed by focused persistence tests.
