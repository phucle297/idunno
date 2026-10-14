# Disaster Party — Checklist Index

`DESIGN.md` remains the design authority; root `progress.json` is the operational source of truth. Each phase has its own checklist. [NEED_REAL_CHECK.md](../NEED_REAL_CHECK.md) records the user's manual-acceptance waiver and bug-report policy; planning does not reinstate required human checklists.

## Active and planned phases

| Phase | Status | Checklist |
| --- | --- | --- |
| 8 — Character, UI and Disaster Counterplay | In progress; 8.1–8.4 passed, 8.5 meteor waves current | [Phase 8](checklists/phase-8-character-disaster-counterplay.md) |
| 9 — Weather and Rockslides | Planned; after8 | [Phase 9](checklists/phase-9-weather-rockslides.md) |
| 10 — Swarms, UFO and Volcanic Terrain | Planned; after9 | [Phase 10](checklists/phase-10-swarms-ufo-volcano.md) |
| 11 — Shrinking Survival Zone and Integrated Local Delivery | Former8 postponed; revalidation after8–10 | [Phase 11](checklists/phase-11-shrinking-survival-zone.md) |

Phases 6 and the original 7 are archived below. The Phase7 visual-completion claim
was overstated and is superseded by the separately archived visual correction.
On2026-10-14 the owner reprioritized model/UI, existing hazard counterplay and new
disasters ahead of the shrinking zone: old Phase8 → Phase11. Historical archive
IDs stay unchanged. Phases9–11 are planned, not implemented; chunk streaming stays
a separate proposal. Existing human waiver and deployment approval boundaries remain.

Phases 3–5 have historical implementation archives, but their blanket "all gates passed"
summaries are superseded by the [audit reconciliation](old-docs/phase-5-validation-followup/decisions.md). Phase 3 hardware
performance/native captures and Phase 4 human comparison are unverified, not passed.
The follow-up closes technical scale/fairness coverage separately. Phase 2 is
[suspended in old-docs](old-docs/phase-2-human-playtest-and-core-feel/checklist.md),
not completed or scheduled; reopen only on owner request. Its unfinished evidence
and continuation waiver remain intact. Current state and action live only in root progress.

## Completed phases

Completed-phase checklists, decisions and progress are grouped in [old-docs](old-docs/README.md):

- [Phase 0 — Init Project](old-docs/phase-0-init-project/checklist.md)
- [Phase 1 — UI Identity and Feedback](old-docs/phase-1-ui-identity-and-feedback/checklist.md)
- [Phase 3 — Player-Caused Chaos](old-docs/phase-3-player-caused-chaos/checklist.md) · [decisions](old-docs/phase-3-player-caused-chaos/decisions.md) · [evidence](old-docs/phase-3-player-caused-chaos/progress.json)
- [Phase 4 — Disaster Remix and Toy Town Interaction](old-docs/phase-4-disaster-remix-and-toy-town-interaction/checklist.md) · [decisions](old-docs/phase-4-disaster-remix-and-toy-town-interaction/decisions.md) · [evidence](old-docs/phase-4-disaster-remix-and-toy-town-interaction/progress.json)
- [Phase 5 — Session Distribution and Release Readiness](old-docs/phase-5-session-distribution-and-release-readiness/checklist.md) · [decisions](old-docs/phase-5-session-distribution-and-release-readiness/decisions.md) · [evidence](old-docs/phase-5-session-distribution-and-release-readiness/progress.json)
- [Phase 5 — Validation Follow-up](old-docs/phase-5-validation-followup/checklist.md) · [decisions](old-docs/phase-5-validation-followup/decisions.md) · [evidence](old-docs/phase-5-validation-followup/progress.json)
- [Phase 6 — Cosmetic Loot-Box Drops and Customization](old-docs/phase-6-cosmetic-loot-box-drops-and-customization/checklist.md) · [decisions](old-docs/phase-6-cosmetic-loot-box-drops-and-customization/decisions.md) · [evidence](old-docs/phase-6-cosmetic-loot-box-drops-and-customization/progress.json) — validated local packages; not deployed/published. Software measurement completed, 60FPS/native/human acceptance not passed.
- [Phase 7 — Soft Creature, Detailed World and Complete Interface](old-docs/phase-7-soft-creature-world-and-interface/checklist.md) · [decisions](old-docs/phase-7-soft-creature-world-and-interface/decisions.md) · [evidence](old-docs/phase-7-soft-creature-world-and-interface/progress.json) — validated agent-owned source/regression gates only; native GPU/Windows/60FPS/separate-network acceptance unverified and nonblocking.
- [Phase 7R — Visual Correction](old-docs/phase-7-visual-correction/checklist.md) · [decisions](old-docs/phase-7-visual-correction/decisions.md) · [evidence](old-docs/phase-7-visual-correction/progress.json) — corrected source and references pushed; no exact-concept/native-GPU/human acceptance claim and no deployment.
- [Phase 7S — Rounded World Rebuild](old-docs/phase-7-rounded-world-rebuild/checklist.md) · [decisions](old-docs/phase-7-rounded-world-rebuild/decisions.md) · [evidence](old-docs/phase-7-rounded-world-rebuild/progress.json) — rounded source/reference pushed after owner rejected7R visuals; concept parity, native GPU and human approval unverified. No deployment/release; Phase8 paused.

- [Phase 7T — Integrated Terraced Town](old-docs/phase-7-integrated-town/checklist.md) · [decisions](old-docs/phase-7-integrated-town/decisions.md) · [evidence](old-docs/phase-7-integrated-town/progress.json) — source/regression delivery complete; no concept-parity, native-GPU or human aesthetic approval claim. No deployment/release or chunk streaming.

## Tracking rules

- Work through phase → milestone → task; tasks are optional for small milestones.
- Complete and validate required gates before closing a phase. Completed tasks within an active phase stay in that phase's checklist for context.
- Keep exactly one executable `next_action` in root `progress.json`; do not maintain a competing next action here.
- Record active decisions in `docs/decisions.md`. On phase completion, move its checklist, decisions and full progress to `docs/old-docs/{phase-slug}/`; never overwrite an archive.
- Do not replace real-user acceptance with automated checks. Record the actual build, conditions and result in `NEED_REAL_CHECK.md`, then reconcile `progress.json` and the phase checklist.

## Explicitly deferred

Unrequested disaster classes beyond the new scoped Snow/Rain/Rockslide/Bee/UFO/Volcano plan,
non-cosmetic progression, currencies, shops, non-cosmetic inventories, paid loot boxes,
ranked matchmaking, chat, voice, player-to-player grabbing, complex parkour, production
bots, advanced destruction and a large cosmetic catalog. Crouch is removed by the
Phase8 plan, not repurposed as a survival counter. Grabbing/holding is temporarily
removed; later held hammer/wood objects for character-to-character interactions are
an explicit owner-requested backlog only, with no scheduled phase or current combat
implementation. Define effects, fairness, physics/network budgets and abuse controls
when that work is opened; phases8–11 require none of it. Volcanic terrain uses predefined states,
not arbitrary terraforming. A second map and disaster compositions landed in Phase4;
free cosmetic drops/equipment landed in Phase6. Completed archives are not new scope.
