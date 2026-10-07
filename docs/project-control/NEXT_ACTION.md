# Next Action

## Immediate
Finish Phase 0 planning artifacts and establish the implementation sequence.

## First implementation phase after planning
Phase 1 — Local Media Library & Collection Engine.

## Phase 1 priority
Build the persistent local data layer before large UI work:
1. database/storage abstraction
2. GIF metadata table/model
3. collections
4. collection items
5. persistent reusable empty lists
6. migration of liked/viewed state where appropriate
7. bounded indexes
8. repository APIs
9. focused persistence tests
10. cache metadata foundation

## Do not do yet
- Do not redesign the entire home screen before storage contracts exist.
- Do not use SharedPreferences for hundreds of GIF records.
- Do not store full binary GIF data inside ordinary database rows unless a measured implementation proves it is appropriate.
- Do not make session restoration depend only on the remote HTML source.
- Do not replace the existing navigation architecture blindly; first map it to persistent browsing spaces.
