# Phase 10 — Swarms, UFO and Volcanic Terrain

Status: completed agent-owned source/local-package gates2026-10-15.
Source is uncommitted/unpushed; no public release/deployment or native/human pass.
Do not start all new hazards together before each solo contract is validated.

## Requested behavior and bounded implementation

- [x] 10.1 Bee swarm: audible/visible swarm announces a fair target, follows through
  navigable space, then stings periodically within actual reach. Retarget with a
  warning and recovery window; do not teleport or repeatedly focus one survivor.
  Break pursuit through enclosed shelter/closed cover or diving into water; obstacles
  block attacks. One authoritative swarm volume, cosmetic bees, no hundreds of bodies.
  Bounded navigation retries; no indoor wall penetration or unavoidable speed pursuit.
- [x] 10.2 UFO: a toy saucer telegraphs a fixed beam footprint, lifts exposed players
  with bounded force and drops them with normal authoritative fall damage. Move out
  during warning or take actual overhead shelter; no crouch/held-item immunity.
  Roof interruption releases safely onto that support, not through ceilings. Retain
  some air control, cap lift height so fall damage is avoidable/nonlethal at full HP
  for baseline capture, bound repeat capture/recovery and exclude no-escape overlap.
  Respect ragdoll, elimination, disconnect and reset lifecycles.
- [x] 10.3 Volcano: choose one authored, warned district and transform it visibly
  from intact terrain to a cooled volcanic/crater field with changed route geometry
  and collision. Use predefined before/after states, not runtime procedural terrain
  destruction. Evacuate with measured time; retain at least two viable exits and
  usable high refuge paths on each map. Cool texture alone does not count as a
  "completely changed area". No invisible collision switch under an unwarned player.
- [x] 10.4 Ground heat: **60s default hot lifetime after eruption**, contact damage
  while standing on affected support, not a one-minute delay before damage. Proposed
  baseline6HP/s; warning/heat meter and hot/warm/cooled materials agree with authority.
  Flood immersion rapidly cools only reached surfaces; rain/snow shorten lifetime
  only on exposed surfaces; no carried-water/pour dependency. Initial cooling rates:
  dry1 heat-second/s, rain3, snow4, immersion10; use the strongest applicable rate,
  not duplicate cooling stacked by frame order. Values remain provisional. No instant
  global cooldown just because Flood is active; raised dry lava stays hot. Never
  reheat cooled terrain within that event. Cooled changed terrain persists to rematch.
- [x] 10.5 Integration/reset: replicate stable district/variant ID, surface state,
  authoritative heat/cool time and captures/targets, not individual bees/particles.
  All mutations reset before rematch/lobby/map-switch/crash retry. Volcano remains
  a director hazard while residual lethal heat exists (counts toward max2), avoiding
  a hidden third threat. Preserve mutable-terrain restoration with static-map reuse.
- [x] 10.6 Validate pursuit/cover/target transfer, beam ceiling/lift/drop bounds,
  eruption escape and each dry/rain/snow/partial-flood cooling boundary. Same
  seed, delta partitions, simultaneous victims, late joins, both maps and5 rematches.
  Extend full network/regression, render altered district and warning states, measure
  physics/navigation/snapshot/memory budgets, provenance and matching local packages.

Snapshot convergence checks do not add midmatch joining; preserve existing
admission restrictions. Pending targets/heat state must still reconstruct correctly.

Exit: all five requested disasters (Snow, Rockslide, Bees, UFO, Volcano) plus Rain
are implemented with readable counters and coherent combinations, not merely visuals.
No safe-zone or streaming implementation in this phase. Human/GPU acceptance remains
separate/nonblocking under the existing waiver; no public deployment inferred.

## Final technical evidence

- Bees77 solo checks: both maps, five resets, reach/wall/roof/water, seed replay,
  bounded pursuit, fair transfer and disconnect.
- UFO78 solo checks: both maps, five resets, actual walk/lift/drop/roof interruption.
- Volcano260 final checks: both maps, five resets, two walking evacuations,
  changed support collision, immediate contact damage, dry/rain/snow/partial Flood
  and delta partitions. Integration47 adds roof/weather/immersion, malformed/remote
  state, cooled crossing reentry, exclusions, distinct audio and ordinary fall checks.
- 49 Godot suites,5 network groups, managed20, settings restart and41 Python tests pass.
- Town/Harbor2/4/8/20 real peers and five rematches each pass; no midmatch admission added.
- 40 final720p/1080p captures inspected via four contact sheets and targeted originals.
  Initial water setter/stale frozen HUD fixture mistakes corrected before final review.
- Five600-tick cycles/map:4 bodies; combined tick p95 initially62/51us, incremental
  snapshot max556/560bytes, stable node counts. Headless subsystem budget, not GPU FPS.
  Four simultaneous UFO captures/ragdoll/disconnect and four lethal grounded heat
  victims/map pass; shared-last outcome preserves existing winner policy.
- Matching local Windows/Linux117-entry PCK manifests and byte comparison pass;
  standalone Linux no-editor/no-cache create/join/version/crash/retry/port lifecycle pass.
  Bees/UFO/Volcano each3 consecutive verbose clean exported-PCK fixture exits;
  Integration47 exported-PCK exit also clean. Packages explicitly identify an
  uncommitted content snapshot, not a Git revision; native Windows unverified.
- Full regression first exposed duplicate landing listeners on room retry (fixed)
  and obsolete free-fall HP assumptions in roof/Flood tests (updated to isolate
  landing damage from breathing grace). Older fixtures retain shutdown-only
  Dummy-audio resources; diagnostics remain enabled and recorded, not a runtime pass.
- Full chronological evidence in [progress](progress.json), contracts in
  [decisions](decisions.md). Artifacts `.amp/in/artifacts/phase10*` are orb-local.
  No phase11/12 implementation or public delivery is inferred.
