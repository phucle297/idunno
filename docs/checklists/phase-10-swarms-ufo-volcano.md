# Phase 10 — Swarms, UFO and Volcanic Terrain

Status: planned; depends on Phase8 counterplay and Phase9 wet/cold surface exposure.
Do not start all new hazards together before each solo contract is validated.

## Requested behavior and bounded implementation

- [ ] 10.1 Bee swarm: audible/visible swarm announces a fair target, follows through
  navigable space, then stings periodically within actual reach. Retarget with a
  warning and recovery window; do not teleport or repeatedly focus one survivor.
  Break pursuit through enclosed shelter/closed cover or diving into water; obstacles
  block attacks. One authoritative swarm volume, cosmetic bees, no hundreds of bodies.
  Bounded navigation retries; no indoor wall penetration or unavoidable speed pursuit.
- [ ] 10.2 UFO: a toy saucer telegraphs a fixed beam footprint, lifts exposed players
  with bounded force and drops them with normal authoritative fall damage. Move out
  during warning or take actual overhead shelter; no crouch/held-item immunity.
  Roof interruption releases safely onto that support, not through ceilings. Retain
  some air control, cap lift height so fall damage is avoidable/nonlethal at full HP
  for baseline capture, bound repeat capture/recovery and exclude no-escape overlap.
  Respect ragdoll, elimination, disconnect and reset lifecycles.
- [ ] 10.3 Volcano: choose one authored, warned district and transform it visibly
  from intact terrain to a cooled volcanic/crater field with changed route geometry
  and collision. Use predefined before/after states, not runtime procedural terrain
  destruction. Evacuate with measured time; retain at least two viable exits and
  usable high refuge paths on each map. Cool texture alone does not count as a
  "completely changed area". No invisible collision switch under an unwarned player.
- [ ] 10.4 Ground heat: **60s default hot lifetime after eruption**, contact damage
  while standing on affected support, not a one-minute delay before damage. Proposed
  baseline6HP/s; warning/heat meter and hot/warm/cooled materials agree with authority.
  Flood immersion rapidly cools only reached surfaces; rain/snow shorten lifetime
  only on exposed surfaces; no carried-water/pour dependency. Initial cooling rates:
  dry1 heat-second/s, rain3, snow4, immersion10; use the strongest applicable rate,
  not duplicate cooling stacked by frame order. Values remain provisional. No instant
  global cooldown just because Flood is active; raised dry lava stays hot. Never
  reheat cooled terrain within that event. Cooled changed terrain persists to rematch.
- [ ] 10.5 Integration/reset: replicate stable district/variant ID, surface state,
  authoritative heat/cool time and captures/targets, not individual bees/particles.
  All mutations reset before rematch/lobby/map-switch/crash retry. Volcano remains
  a director hazard while residual lethal heat exists (counts toward max2), avoiding
  a hidden third threat. Preserve mutable-terrain restoration with static-map reuse.
- [ ] 10.6 Validate pursuit/cover/target transfer, beam ceiling/lift/drop bounds,
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
