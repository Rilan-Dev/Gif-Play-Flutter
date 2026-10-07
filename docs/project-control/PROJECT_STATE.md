# GIF Play Flutter — Project State

## Authority
- Repository: Rilan-Dev/Gif-Play-Flutter
- Branch: main
- Current implementation baseline: 9a0c17c973a60b0e74aac4d6efc6f047f592f217
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
- Planning: ACTIVE
- Implementation: NOT STARTED
- Phase 0: PLANNED
- No production feature code has been changed for this program.

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
Complete Phase 0 architecture/design baseline, then implement phases sequentially without mixing persistence, navigation, search, and visual redesign into one unbounded change.
