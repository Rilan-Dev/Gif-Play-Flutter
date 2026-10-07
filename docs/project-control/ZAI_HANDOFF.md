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
docs/project-control/DATA_MODEL.md
docs/project-control/STORAGE_AND_CACHE.md
docs/project-control/SESSION_AND_NAVIGATION.md
```

## Current authorization
Phase 2 — Temporary Download / Ready-to-Share Engine is the active development phase.

### Authorized scope
- durable local cache manifest + filesystem binary cache;
- bounded download/prefetch;
- cache readiness/status;
- retry/backoff and expired-entry recovery;
- quota/LRU/TTL maintenance;
- reusable collection/share-list preparation;
- integration with the existing share flow;
- required tests and project-control updates.

Phase 1 runtime/dependency verification remains pending but does not block implementation per project-owner instruction.

## Required implementation discipline
For each feature:
1. Read current project-control state.
2. Inspect relevant existing code.
3. Define/confirm tests before implementation.
4. Implement the smallest coherent architectural slice.
5. Preserve backward compatibility where possible.
6. Update documentation when architecture changes.
7. Record evidence and next action.
8. Never mark a phase complete without verification evidence.

## Product invariants
- Collections are reusable and survive sharing.
- Sharing drains pending items; it never deletes the collection.
- Multiple collections are independent.
- Canonical media identity prevents duplicate binaries across collections.
- Binary GIF payloads do not belong in SQLite rows.
- Cache cleanup never deletes collection metadata.
- Do not solve scale requirements by decoding all GIFs into memory.

## Out of scope
- Home redesign
- Search 2.0
- Persistent Spaces/Detail Tabs
- replacing Provider with another state-management architecture
