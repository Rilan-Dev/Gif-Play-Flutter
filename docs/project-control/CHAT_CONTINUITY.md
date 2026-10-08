# Chat Continuity

## Purpose
A new ChatGPT conversation must be able to continue this project from repository-authored state.

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
Phase 0 is complete. Phase 1 persistence is implemented but runtime/dependency verification remains pending. Phase 2 — Temporary Download / Ready-to-Share Engine — is the active development phase and may continue without waiting for CI, Vercel, or runtime gates.

## Session-independent rule
Never infer completed work from a previous chat. GitHub files, Git history, and current repository contents are authoritative.

## Continuation procedure
- Re-read the files above.
- Inspect current GitHub tree and relevant implementation state.
- Identify the first unchecked/pending action in NEXT_ACTION.md.
- Continue from that action.
- Record meaningful work in WORKLOG.md.
- Update NEXT_ACTION.md whenever the next action changes.
- Update CURRENT_PHASE.md when a phase starts/completes.
- Do not close a phase without evidence recorded in the worklog and appropriate verification.

## Latest continuation point — Phase 3 persistent navigation infrastructure
- Phase 2 collection/share recovery now includes per-item status, retry, empty-collection handling, and successful-share-only state transitions.
- Phase 3 persistence has started without changing the large home UI: schema v2 adds Spaces, Detail Tabs, and SessionSnapshot; LocalMediaRepository exposes CRUD/session APIs; SessionNavigationController restores and persists active navigation state.
- Main bootstrap registers SessionNavigationController.
- Focused persistence tests cover navigation state, schema-v1 forward migration, and controller restoration.
- Startup now creates a durable Home Space when none exists and repairs invalid active-space references from stale snapshots.
- The next implementation action is invalid/closed-tab restoration coverage and migration/reopen coverage before the visual Space/Detail Tab redesign.

## APCP Adaptive Control Layer

For adaptive continuation and fresh-session recovery, also read `docs/project-control/NAVIGATION.md` and `docs/project-control/ADAPTIVE_PROJECT_CONTROL.md`. These documents add governance/navigation only and do not change the current implementation plan.

Fresh sessions must recover current phase, active scope, authorization/handoff, blockers, verification state, lessons and `NEXT_ACTION.md` from repository state. Do not depend on prior ChatGPT/Z.AI conversation memory.

A phase/task/checklist stop is a durable boundary. Inspect the current documents and determine whether the next action is already authorized before proceeding; do not infer authorization from a commit. When authorized independent work exists, do not wait or repeatedly poll for CI/CD, Vercel, deployment, review or verification.

Current owner requirements may change earlier requirements. Material changes require impact analysis and updated/superseding authorization; completed work may be reopened when the current authorized requirement requires it. Rules-only governance updates must not mutate product scope or implementation plans.

Use the copy/paste commands in `ADAPTIVE_PROJECT_CONTROL.md` for Continue, Execute Next, New Requirement, Change Requirement, Modify Implementation, Stopped Boundary, and Route Blocker.

## APCP agent invocation layer

Fresh sessions may be started for a specific APCP role without depending on another agent's chat history.

Before role-specific work, read:
- `docs/project-control/NAVIGATION.md`
- `docs/project-control/AGENT_REGISTRY.md`
- `docs/project-control/AGENT_SKILLS.md`
- `docs/project-control/AGENT_INVOCATION.md`

Then recover the normal project-control state and execute only the work authorized for the invoked role.

A new FIX-01 or OPS-01 session does not need DEV-01 to stop first. Likewise, DEV-01 does not wait for a pending FIX-01/OPS-01 task when independent authorized development exists.

The role prompt is an execution instruction, not a source of project authority.


## Independent-agent continuity extension

The same repository-first recovery model applies to DEV-01 / Forge, FIX-01 / Sentinel, OPS-01 / Shipwright, and WORK-01 / Rover.

A fresh role session reads AGENT_MEMORY.md first, then central events/sessions/handoffs/backlog, then its role-local MEMORY.md/WORKLOG.md, then the normal project-control state. This allows any agent to be invoked without a project briefing or previous chat transcript.

WORK-01 may execute SAFE-LOCAL or already AUTHORIZED daily work, but it cannot bypass authorization for a MATERIAL-CHANGE. Memory is supplementary; repository truth and current authorization remain authoritative.


## Human invocation and fresh-chat usage

The user does not need to carry project context between chats. For a fresh session, the preferred copy/paste instructions are in `docs/project-control/HOW_TO_USE_AGENTS.md`. The invoked agent must recover the project from GitHub and durable project-control records rather than requiring the previous conversation.

The user may invoke DEV-01, FIX-01, OPS-01, or WORK-01 while another agent is active. The new session must work independently, avoid conflicting edits, route dependencies, and continue any independent valid work without repeated waiting/polling.
