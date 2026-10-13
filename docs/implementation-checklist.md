# Disaster Party — Checklist Index

`DESIGN.md` remains the design authority; root `progress.json` is the operational source of truth. Each phase has its own checklist. [NEED_REAL_CHECK.md](../NEED_REAL_CHECK.md) records the user's manual-acceptance waiver and bug-report policy; planning does not reinstate required human checklists.

## Active and planned phases

| Phase | Status | Checklist |
| --- | --- | --- |
| 2 — Human Playtest and Core Feel | Deferred, not completed | [Phase 2](checklists/phase-2-human-playtest-and-core-feel.md) · [frozen evidence](old-docs/phase-2-human-playtest-and-core-feel/progress.json) |
| 6 — Cosmetic Loot-Box Drops and Customization | In progress; Milestones 6.1–6.4 complete, final regression/packaging active | [Phase 6](checklists/phase-6-cosmetic-loot-box-drops-and-customization.md) |

Phases 3–5 have historical implementation archives, but their blanket "all gates passed"
summaries are superseded by the [audit reconciliation](old-docs/phase-5-validation-followup/decisions.md). Phase 3 hardware
performance/native captures and Phase 4 human comparison are unverified, not passed.
The follow-up closes technical scale/fairness coverage separately. Phase 2 remains
deferred under its continuation waiver. Current state and action live only in root progress.

## Completed phases

Completed-phase checklists, decisions and progress are grouped in [old-docs](old-docs/README.md):

- [Phase 0 — Init Project](old-docs/phase-0-init-project/checklist.md)
- [Phase 1 — UI Identity and Feedback](old-docs/phase-1-ui-identity-and-feedback/checklist.md)
- [Phase 3 — Player-Caused Chaos](old-docs/phase-3-player-caused-chaos/checklist.md) · [decisions](old-docs/phase-3-player-caused-chaos/decisions.md) · [evidence](old-docs/phase-3-player-caused-chaos/progress.json)
- [Phase 4 — Disaster Remix and Toy Town Interaction](old-docs/phase-4-disaster-remix-and-toy-town-interaction/checklist.md) · [decisions](old-docs/phase-4-disaster-remix-and-toy-town-interaction/decisions.md) · [evidence](old-docs/phase-4-disaster-remix-and-toy-town-interaction/progress.json)
- [Phase 5 — Session Distribution and Release Readiness](old-docs/phase-5-session-distribution-and-release-readiness/checklist.md) · [decisions](old-docs/phase-5-session-distribution-and-release-readiness/decisions.md) · [evidence](old-docs/phase-5-session-distribution-and-release-readiness/progress.json)
- [Phase 5 — Validation Follow-up](old-docs/phase-5-validation-followup/checklist.md) · [decisions](old-docs/phase-5-validation-followup/decisions.md) · [evidence](old-docs/phase-5-validation-followup/progress.json)

## Tracking rules

- Work through phase → milestone → task; tasks are optional for small milestones.
- Complete and validate required gates before closing a phase. Completed tasks within an active phase stay in that phase's checklist for context.
- Keep exactly one executable `next_action` in root `progress.json`; do not maintain a competing next action here.
- Record active decisions in `docs/decisions.md`. On phase completion, move its checklist, decisions and full progress to `docs/old-docs/{phase-slug}/`; never overwrite an archive.
- Do not replace real-user acceptance with automated checks. Record the actual build, conditions and result in `NEED_REAL_CHECK.md`, then reconcile `progress.json` and the phase checklist.

## Explicitly deferred

Additional disaster classes, non-cosmetic progression, currencies, shops, non-cosmetic inventories, paid loot boxes, ranked matchmaking, chat, voice, player-to-player grabbing, complex parkour, production bots, advanced destruction, and a large cosmetic catalog. A second map and more disaster compositions landed in Phase 4 (archived); earned cosmetic loot-box drops and a minimal owned/equip collection are planned in Phase 6. Neither is current implementation scope.
