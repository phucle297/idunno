# Disaster Party — Checklist Index

`DESIGN.md` remains the design authority; root `progress.json` is the operational source of truth. Each phase has its own checklist. [NEED_REAL_CHECK.md](../NEED_REAL_CHECK.md) records the user's manual-acceptance waiver and bug-report policy; planning does not reinstate required human checklists.

## Active and planned phases

| Phase | Status | Checklist |
| --- | --- | --- |
| 2 — Human Playtest and Core Feel | Deferred, not completed | [Phase 2](checklists/phase-2-human-playtest-and-core-feel.md) · [frozen evidence](old-docs/phase-2-human-playtest-and-core-feel/progress.json) |
| 3 — Player-Caused Chaos | In progress: 3.1 | [Phase 3](checklists/phase-3-player-caused-chaos.md) |
| 4 — Disaster Remix and Toy Town Interaction | Planned | [Phase 4](checklists/phase-4-disaster-remix-and-toy-town-interaction.md) |
| 5 — Session Distribution and Release Readiness | Planned | [Phase 5](checklists/phase-5-session-distribution-and-release-readiness.md) |
| 6 — Cosmetic Loot-Box Drops and Customization | Planned | [Phase 6](checklists/phase-6-cosmetic-loot-box-drops-and-customization.md) |

Phase3 has six ordered milestones: safe interaction → carrying → one useful prop → optional shove decision → two interruptible emotes → integrated validation/packages. User-authorized activation preserves Phase2's unfinished gates, not a closure or an invented pass; its checklist stays at the original path as a deferred reference. Current status and next action live only in root progress.

## Completed phases

Completed-phase checklists, decisions and progress are grouped in [old-docs](old-docs/README.md):

- [Phase 0 — Init Project](old-docs/phase-0-init-project/checklist.md)
- [Phase 1 — UI Identity and Feedback](old-docs/phase-1-ui-identity-and-feedback/checklist.md)

## Tracking rules

- Work through phase → milestone → task; tasks are optional for small milestones.
- Complete and validate required gates before closing a phase. Completed tasks within an active phase stay in that phase's checklist for context.
- Keep exactly one executable `next_action` in root `progress.json`; do not maintain a competing next action here.
- Record active decisions in `docs/decisions.md`. On phase completion, move its checklist, decisions and full progress to `docs/old-docs/{phase-slug}/`; never overwrite an archive.
- Do not replace real-user acceptance with automated checks. Record the actual build, conditions and result in `NEED_REAL_CHECK.md`, then reconcile `progress.json` and the phase checklist.

## Explicitly deferred

Additional disaster classes, non-cosmetic progression, currencies, shops, non-cosmetic inventories, paid loot boxes, ranked matchmaking, chat, voice, player-to-player grabbing, complex parkour, production bots, advanced destruction, and a large cosmetic catalog. A second map and more disaster compositions are planned in Phase 4; earned cosmetic loot-box drops and a minimal owned/equip collection are planned in Phase 6. Neither is current implementation scope.
