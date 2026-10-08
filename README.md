# gif_play

For My Love

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## AI Project Control

This repository uses repository-first APCP governance. Start with `docs/project-control/NAVIGATION.md`, then follow `CHAT_CONTINUITY.md` → current state/phase → `NEXT_ACTION.md` → authorization/handoff → verification and ledgers. For adaptive requirements, agent routing, no-wait continuation, and copy/paste prompts, use `docs/project-control/ADAPTIVE_PROJECT_CONTROL.md`. This governance layer does not change the product implementation plan.

## APCP agent control

This repository supports independently invokable autonomous APCP roles:

- **DEV-01 / Forge** — product development.
- **FIX-01 / Sentinel** — error diagnosis and remediation.
- **OPS-01 / Shipwright** — CI/CD, deployment, and infrastructure.

Start with `docs/project-control/NAVIGATION.md`. For role behavior use `docs/project-control/AGENT_SKILLS.md`; for direct assignment prompts use `docs/project-control/AGENT_INVOCATION.md`; for ownership use `docs/project-control/AGENT_REGISTRY.md`; for the governance file audit use `docs/project-control/FILES.md`.

These role controls allow a new agent chat to begin while another agent is still working. The new agent recovers its own authorized work from GitHub and does not depend on the other conversation.



## APCP — How to use agents

You can start a brand-new ChatGPT chat with any APCP agent without explaining the project again. The agent must recover the architecture, current work, authorization, project-control state, shared lessons, known mistakes, sessions, and next action from GitHub.

**Human quick guide:** `docs/project-control/HOW_TO_USE_AGENTS.md`

Use it for **which agent to call, when to call it, how to continue where you left off, daily/unplanned work, concurrent agents, and copy/paste prompts**.

Roles: **DEV-01 / Forge** (planned development), **FIX-01 / Sentinel** (bugs/failures), **OPS-01 / Shipwright** (CI/CD/deployment/infrastructure), **WORK-01 / Rover** (daily/simple/unplanned safe work).

Starting an agent selects its role; it does not grant authorization. Shared and role-local memory preserve lessons and prevent repeat mistakes; current GitHub/project-control state remains authoritative.
