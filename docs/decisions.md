# Active phase decisions

## 2026-10-19 — Performance first, then toy sabotage (planning only)

Owner reports solo smooth but two apps on the same machine in one room heat up and
drop frames. Build/device/FPS/temperature are not supplied. Treat that as real user
feedback with unclassified cause, not proof of networking or thermal throttling.
Existing overlap profiler adds avatars to one process; headless20-client and public
two-client correctness checks do not establish two rendered clients performance.
No explicit application FPS/background policy found; hidden Home preview is already
disabled. Measure before changing caps, rendering or snapshot work.

[Phase19](checklists/phase-19-multiplayer-frame-budget.md) plans matched solo/
network/two-renderer controls, focus/minimize/resolution/pacing and sustained traces.
Keep physics/ENet cadence correct under background rendering changes. Reference
hardware unknown; llvmpipe cannot establish GPU temperature/native60FPS.

[Phase20](checklists/phase-20-toybox-sabotage.md) plans the newly requested guns,
rockets and wider toy arsenal after measured headroom. First vertical slice: foam
blaster, plunger rocket, squeaky hammer; later batches add traps, displacement,
deflection and bounded environment combos. Proposed limits/timings are hypotheses,
not accepted balance. Default first slice uses position/impulse, not direct gun HP
damage, preserving survival rather than realistic deathmatch. Shared cross-item
protection, server hits/ammo and limited concurrency keep chaos reactive and bounded.
No DESIGN rewrite, gameplay code changes, new infra or deployment in this task.
Root `progress.json` owns the operational next action.

## Previous completed delivery

Phase18 outfit selection, four additional starter costumes and original menu/game
music passed the technical gates and source push. Owner-authorized follow-up on
2026-10-19 deployed revision741ae34 and published its matching
[prerelease](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-19-741ae34).
Windows uses the byte-exact deployed CI PCK; both downloaded assets match originals.
Public two-client equipment/Ready/Start/mutual movement, standalone server and exact
PCK rendered collection/music checks passed. This does not establish native Windows,
physical GPU/audio, human feel or separate-network acceptance.

- [Phase18 decisions](old-docs/phase-18-outfit-selection-and-costumes/decisions.md)
- [Full evidence](old-docs/phase-18-outfit-selection-and-costumes/progress.json)
- [Completed checklist](old-docs/phase-18-outfit-selection-and-costumes/checklist.md)
- [Current delivery evidence](../progress.json) supersedes the immutable source-only
  archive checkpoint; no historical archive was overwritten.

Existing human acceptance waiver, native Windows/GPU/audio limitations and deferred
packet-loss investigation remain unchanged. Source checks are not public deployment
or physical-device acceptance.
