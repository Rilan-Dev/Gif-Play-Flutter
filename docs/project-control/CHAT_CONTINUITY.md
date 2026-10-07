# Chat Continuity

## Purpose
A new ChatGPT conversation must be able to continue this project without relying on hidden conversation memory.

## Read order
1. docs/project-control/PROJECT_STATE.md
2. docs/project-control/CURRENT_PHASE.md
3. docs/project-control/NEXT_ACTION.md
4. docs/project-control/IMPLEMENTATION_PLAN.md
5. docs/project-control/DECISIONS.md
6. docs/project-control/ISSUES.md
7. docs/project-control/WORKLOG.md
8. docs/AI_REPO_INDEX.md
9. docs/AI_RESEARCH_PROTOCOL.md
10. docs/project-control/DATA_MODEL.md
11. docs/project-control/STORAGE_AND_CACHE.md
12. docs/project-control/SESSION_AND_NAVIGATION.md

## Current handoff
Phase 0 is complete and its architecture contracts are locked. Phase 1 — Local Media Library & Collection Engine — is the current authorized implementation phase.

## Session-independent rule
Never infer completed work from a previous chat. GitHub files, Git history, and current repository contents are authoritative.

## Continuation procedure
- Re-read the files above.
- Inspect current GitHub tree and relevant implementation state.
- Identify the first unchecked/pending action.
- Continue from that action.
- Record meaningful work in WORKLOG.md.
- Update NEXT_ACTION.md whenever the next action changes.
- Update CURRENT_PHASE.md when a phase starts/completes.
- Do not close a phase without evidence recorded in the worklog and appropriate verification.
