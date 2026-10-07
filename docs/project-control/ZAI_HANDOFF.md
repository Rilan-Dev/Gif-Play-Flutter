# GIF Play Flutter — Implementation Handoff

## Role model

### ChatGPT
- Architect
- Project owner/reviewer
- Maintains project-control state
- Decides phase boundaries
- Reviews implementation direction
- Updates continuity documents

### Implementer
- Implements only the current authorized phase/task.
- Reads project-control documents before starting.
- Does not silently redefine product requirements.
- Records meaningful implementation notes.
- Stops at the phase boundary when instructed.

## Mandatory read order
```
docs/project-control/PROJECT_STATE.md
docs/project-control/CURRENT_PHASE.md
docs/project-control/NEXT_ACTION.md
docs/project-control/CHAT_CONTINUITY.md
docs/project-control/IMPLEMENTATION_PLAN.md
docs/project-control/DECISIONS.md
docs/project-control/ISSUES.md
docs/project-control/WORKLOG.md
docs/AI_REPO_INDEX.md
docs/AI_RESEARCH_PROTOCOL.md
```

## Current authorization
Only Phase 0 planning/design work is authorized at the moment.

Do not start Phase 1 implementation until Phase 0 contracts and storage selection are finalized.

## Required implementation discipline

For each feature:
1. Read current project-control state.
2. Inspect the relevant existing code.
3. Define/confirm tests before implementation.
4. Implement the smallest coherent architectural slice.
5. Preserve backward compatibility where possible.
6. Update documentation when architecture changes.
7. Record evidence and next action.
8. Never mark a phase complete without verification evidence.

## User's key product requirements

### Search
Fast, responsive GIF search across locally persisted metadata and remote discovery when available.

### Collections
Multiple reusable named lists. Example:
- List A: 50
- List B: 100
- List C: 60

Users can share one list or multiple selected lists. Sharing drains the current pending items but never destroys the list. Empty lists remain reusable.

### Local storage
At least 500 GIF metadata records and large collections must remain performant. Binary media is cached separately and bounded.

### Pre-download
Collection items are downloaded into temporary app-private storage ahead of sharing when appropriate. Cached files are reused across lists and removed by quota/LRU/TTL policy when no longer needed.

### Session restoration
The last browsing session must survive app close/restart. The user must return to the same Space/detail context rather than starting over.

### Browser-like navigation
Persistent top-level **Spaces** contain the home/feed context. Within a Space, **Detail Tabs** hold opened GIF detail pages, suggestions, and related navigation. Both levels support thumbnails and quick switching.

## Important invariant

Never delete user-created collection definitions merely because their item queue becomes empty after sharing.

## Important performance invariant

Never solve the 500-GIF requirement by keeping 500 GIF binaries decoded in memory. Use lazy loading and bounded disk caching.
