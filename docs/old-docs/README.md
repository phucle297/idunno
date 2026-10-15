# Completed-phase archives

These are historical implementation checkpoints, not unconditional current-build
release/acceptance claims. The [audit reconciliation](phase-5-validation-followup/decisions.md) qualifies
Phase 3 performance/native gates, Phase 4 fairness/human gates and Phase 5 scale,
deployment/demand and archive-provenance claims. Preserve these payloads unchanged;
new follow-up evidence belongs in a separately named archive.

| Phase | Checklist | Decisions | Full validation evidence |
| --- | --- | --- | --- |
| 0 — Init Project | [Checklist](phase-0-init-project/checklist.md) | [Decisions](phase-0-init-project/decisions.md) | [Progress](phase-0-init-project/progress.json) |
| 1 — UI Identity and Feedback | [Checklist](phase-1-ui-identity-and-feedback/checklist.md) | [Decisions](phase-1-ui-identity-and-feedback/decisions.md) | [Progress](phase-1-ui-identity-and-feedback/progress.json) |
| 3 — Player-Caused Chaos | [Checklist](phase-3-player-caused-chaos/checklist.md) | [Decisions](phase-3-player-caused-chaos/decisions.md) | [Progress](phase-3-player-caused-chaos/progress.json) |
| 4 — Disaster Remix and Toy Town Interaction | [Checklist](phase-4-disaster-remix-and-toy-town-interaction/checklist.md) | [Decisions](phase-4-disaster-remix-and-toy-town-interaction/decisions.md) | [Progress](phase-4-disaster-remix-and-toy-town-interaction/progress.json) |
| 5 — Session Distribution and Release Readiness | [Checklist](phase-5-session-distribution-and-release-readiness/checklist.md) | [Decisions](phase-5-session-distribution-and-release-readiness/decisions.md) | [Progress](phase-5-session-distribution-and-release-readiness/progress.json) |
| 5 — Validation Follow-up | [Checklist](phase-5-validation-followup/checklist.md) | [Decisions](phase-5-validation-followup/decisions.md) | [Progress](phase-5-validation-followup/progress.json) |
| 6 — Cosmetic Loot-Box Drops and Customization | [Checklist](phase-6-cosmetic-loot-box-drops-and-customization/checklist.md) | [Decisions](phase-6-cosmetic-loot-box-drops-and-customization/decisions.md) | [Progress](phase-6-cosmetic-loot-box-drops-and-customization/progress.json) |
| 7 — Soft Creature, Detailed World and Complete Interface | [Checklist](phase-7-soft-creature-world-and-interface/checklist.md) | [Decisions](phase-7-soft-creature-world-and-interface/decisions.md) | [Progress](phase-7-soft-creature-world-and-interface/progress.json) |
| 7R — Visual Correction | [Checklist](phase-7-visual-correction/checklist.md) | [Decisions](phase-7-visual-correction/decisions.md) | [Progress](phase-7-visual-correction/progress.json) |
| 7S — Rounded World Rebuild | [Checklist](phase-7-rounded-world-rebuild/checklist.md) | [Decisions](phase-7-rounded-world-rebuild/decisions.md) | [Progress](phase-7-rounded-world-rebuild/progress.json) |
| 7T — Integrated Terraced Town | [Checklist](phase-7-integrated-town/checklist.md) | [Decisions](phase-7-integrated-town/decisions.md) | [Progress](phase-7-integrated-town/progress.json) |
| 8 — Character, UI and Disaster Counterplay | [Checklist](phase-8-character-disaster-counterplay/checklist.md) | [Decisions](phase-8-character-disaster-counterplay/decisions.md) | [Progress](phase-8-character-disaster-counterplay/progress.json) |
| 8F — Solid Environment Collision | [Checklist](phase-8-collision-followup/checklist.md) | [Decisions](phase-8-collision-followup/decisions.md) | [Progress](phase-8-collision-followup/progress.json) |
| 9 — Weather and Rockslides | [Checklist](phase-9-weather-rockslides/checklist.md) | [Decisions](phase-9-weather-rockslides/decisions.md) | [Progress](phase-9-weather-rockslides/progress.json) |
| 10 — Swarms, UFO and Volcanic Terrain | [Checklist](phase-10-swarms-ufo-volcano/checklist.md) | [Decisions](phase-10-swarms-ufo-volcano/decisions.md) | [Progress](phase-10-swarms-ufo-volcano/progress.json) |
| 10F — Volcanic Relief | [Checklist](phase-10-volcanic-relief-followup/checklist.md) | [Decisions](phase-10-volcanic-relief-followup/decisions.md) | [Progress](phase-10-volcanic-relief-followup/progress.json) |

Phase 6 completed agent-owned source/local-package gates on2026-10-13, not deployment
or publication. The original Phase7 archive retains functional regression evidence, but its
visual-completion claim is superseded by the2026-10-14 audit: no UI-source redesign had
landed in that phase. The [separate visual correction](phase-7-visual-correction/checklist.md)
delivered the missing source work and selected references; human aesthetic/native-GPU
acceptance is not claimed. Historical payloads are unchanged.
Software p95 measurements did not meet60FPS on llvmpipe; native GPU/Windows/human
acceptance remains unverified/nonblocking under the waiver. Phase8 completed all
six agent-owned technical/local-package gates on2026-10-14; source14be2c3 pushed,
matching local bundles verified. No new public deployment/release. Phase8 diary paths are historical workspace-relative
paths; checklist and decisions navigation now use the archive directory.

Phase9 completed all four agent-owned milestones on2026-10-14: full45 suites/five
matrices/managed20, both-map2/4/8/20 weather transport/reset checks,40 inspected
render states and matching local packages. Its archive preserves the then-uncommitted,
preauthorization closure. Subsequent owner-authorized source push, EC2 deployment and
[matching public pre-release](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-14-c0a7800)
are verified in root `progress.json`; Phase10 subsequently completed technical/local
gates2026-10-15, while11–12 remain planned. Phase10 source is uncommitted/unpushed;
matching local packages are not public deployment/release. No native
Windows/GPU/audio/human acceptance is claimed. Earlier
pending statements in the Phase9 diary are chronological and superseded by its final
entries. Existing human waiver and all actual failure logs/evidence are preserved.

## Suspended phase snapshot — not completed

Phase2 was suspended on2026-10-09 for user-authorized Phase3 continuation under the manual-acceptance waiver. Its [full progress](phase-2-human-playtest-and-core-feel/progress.json) retains every unfinished gate and validation result; [decisions](phase-2-human-playtest-and-core-feel/decisions.md) retain the historical body. On2026-10-14 the owner requested moving its [checklist](phase-2-human-playtest-and-core-feel/checklist.md) here and removing it from the active/planned roadmap; reopen only on owner request. All three payloads are preserved byte-for-byte, including historical navigation/status statements. This is not a completed-phase archive or a human/release pass.

[PROMPT.md](PROMPT.md) is the original brief, not an active-phase checklist.

Historical decisions and progress were moved without changing their contents. Paths and phase/milestone numbers inside them describe the layout at recording time. In particular, historical `superseded_by` and `previous_phase_archive` strings are not current navigation links; use this index and root `progress.json` for current locations.

Future completed phases use `docs/old-docs/{phase-slug}/{checklist.md,decisions.md,progress.json}`. Preserve full evidence, never overwrite an existing archive, and leave active/planned checklists under `docs/checklists/`.

2026-10-14 numbering change: the formerly planned shrinking-zone Phase8 is now
[Phase11](../checklists/phase-11-shrinking-survival-zone.md), after new Phase8–10
character/UI and disaster work. Historical Phase8 IDs/paths in archived evidence
remain unchanged; use that new link for the current postponed zone plan.
