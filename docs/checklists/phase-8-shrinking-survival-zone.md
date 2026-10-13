# Phase 8 — Shrinking Survival Zone and Integrated Local Delivery

Status: planned; depends on all required Phase 7 gates. No zone exists in current code.

## Product outcome

Concentrate survivors over the existing 600-second match without replacing disasters
with combat or making buildings universally safe. A separate gameplay phase allows
art/camera regressions to be settled before movement-pressure rules change.
Implementation defaults below are deliberate first-version choices, not human-tuned
balance or owner selection of every number. Do not add a new selectable ruleset.
Apply to solo testing and all multiplayer modes; solo still ends only at death/timeout.

## Fixed gameplay contract

- One horizontal circle per map, centered throughout the round. Initial radius covers
  every playable corner plus 0.5m margin: derive from bounds and center, not a hard-coded
  radius that excludes square-map corners. Town candidate center (x=0,z=-8); Harbor
  candidate (0,-10). Final radius 22m. These candidates encompass both Town north roofs
  and Harbor Warehouse/CraneDeck; collision-path validation is required before locking.
- Use the match's authoritative elapsed/duration fraction, never a separate wall clock.
  Stage timing scales with non-default durations in fixtures. Client renders replicated
  state; client interpolation never changes authority, extends grace or deals damage.
- Circle contracts linearly during shrink intervals, holds otherwise; final circle
  stays nonzero until existing timeout ranking. No moving/random center or collapse
  to a point: that would need different shelter/flood balance and route validation.
- Inside means authoritative player root x/z distance ≤ radius (consistent numerical
  tolerance); vertical height, crouch, hats and cosmetic ragdoll bodies do not change it.
  Whole-map out-of-bounds death remains a separate existing rule.
- Outside deals gradual damage to alive players, with cause `Outside survival zone`;
  roofs/walls cannot shield it. No zone damage in lobby/results, before first shrink,
  after death or while resetting. Integrate elapsed exposure, not client FPS or one
  accumulated tick burst. Cross-stage time steps split at stage boundaries.
- No new teleport, respawn, healing, weapon, loot or progression rule. Existing result
  ties, participation/reward rules and disconnect semantics remain unchanged.

### Default stage schedule

Times are the default 600s match; use their fractions for other durations.

| Interval | Zone action | Outside damage |
| --- | --- | --- |
| 0–120s | Initial full-map coverage; grace | 0 HP/s |
| 120–150s | Announce first target and shrink countdown | 0 HP/s |
| 150–240s | Initial radius → 32m | 2 HP/s |
| 240–300s | Hold 32m; announce next target at 270s | 2 HP/s |
| 300–360s | 32 → 28m | 2 HP/s |
| 360–420s | Hold 28m; announce next target at 390s | 4 HP/s |
| 420–480s | 28 → 24m | 4 HP/s |
| 480–540s | Hold 24m; announce next target at 510s | 4 HP/s |
| 540–570s | 24 → 22m | 6 HP/s |
| 570–600s | Hold 22m; existing timeout if needed | 6 HP/s |

The first two minutes remain forgiving. Hard changes director pace only, not zone
damage or timing. A final multi-survivor result is allowed: this is pressure, not a
promise that every match ends with exactly one winner. Exposure damage begins at
first shrink, even though the large initial circle may still include most of the map.

## 8.1 — Map route and hazard feasibility before damaging players

Owners: `game/main.gd` map anchors, actual map geometry, `game/disasters/disaster_director.gd`.

- [ ] 8.1a Measure actual collision paths to the next circle from all spawn/refuge
  exits and house/school rooms on both maps. Do not infer reachability from a point
  being inside a radius. Walk paths with normal controller, no crate boost required.
  Include damaged roofs/gangways and both presets. Thirty-second notice plus shrink
  time must exceed measured ordinary route time with room for avoiding telegraphs.
- [ ] 8.1b Verify at least two independent reachable high refuge areas above maximum
  flood level remain within the final zone, with legal exits. Town Shop/School roofs
  and Harbor Warehouse/CraneDeck are candidates; narrow roof slivers alone do not qualify.
  Preserve routes inside the current circle to the next area through shrinking stages.
- [ ] 8.1c Audit disaster targeting/paths/fire/breakage against remaining navigable
  area. Retain minimum warning/force/damage bounds. Do not concentrate meteor/lighting
  density inversely with zone area. Bound sampling attempts; no unbounded rejection loop.
  Existing persistent warnings/strikes finish at their announced locations, never jump.

Gate G8.1: collision-driven route tests pass for both maps and each transition, with
asymmetric start positions and damaged structures. Refuse an unsafe center/radius;
adjust map-specific anchors/radius upward before reducing warnings or adding immunity.

## 8.2 — Authoritative zone, exposure and replication

Owners: `game/session/match_manager.gd` clock/damage/results; `game/main.gd` authority,
snapshot/reset lifecycle; one cohesive `game/session/survival_zone.gd` if separating
zone evaluation from orchestration reduces complexity. No generic hazard framework.

- [ ] 8.2a Implement one source of truth for stage/radius/target/damage from normalized
  match time and map configuration. Configure/reset on map changes and round start;
  dispose state on return to lobby/crash retry. Keep engine-independent stage evaluation
  only if used by authority and presentation; don't duplicate schedule tables.
- [ ] 8.2b Authority evaluates alive root positions and batches zone damage for all
  players together using existing damage batch API, preserving simultaneous zone-death
  ties. Current `main._process` advances the match clock before snapshots and
  `tick_match` immediately finishes at timeout. Extend that tick to accept an optional
  authority-computed zone event batch: evaluate exposure over old time → capped new time,
  advance clock/participation, apply the batch once, then finish timeout only if still
  ACTIVE. Existing callers without zone events retain behavior. Preserve existing hazard
  tick order; simultaneous zone deaths share one batch, not a new cross-hazard tie claim.
  No duplicate final frame damage, dead-player repeat or zone-driven reward bypass.
  Fractional damage/time must be stable for different delta partitions at fixed positions.
- [ ] 8.2c Include compact center/current/next radius, stage, authoritative remaining
  time and schedule identity in existing ordered snapshots. Validate finite values,
  ranges and stage consistency; reject malformed/stale payloads, never trust client-sent
  position/equipment/zone claims. Apply map identity before zone visuals, respect roster
  sequencing and monitor existing 1200-byte unreliable/reliable threshold at 20 players.

Gate G8.2: public observable tests at exact radius and just inside/outside, high/low y,
before/at/after each stage boundary, split large delta, different centers, stale state,
simultaneous last deaths, timeout, dead/results immunity, solo and five rematches.
Unauthoritative clients cannot apply damage; fresh/reconnecting clients converge.

## 8.3 — Readable boundary and disaster integration

Owners: `game/ui/gameplay_hud.gd`, `game/main.gd`, director and six disaster scripts.

- [ ] Current boundary: thin segmented slate/amber ground ring and restrained vertical
  dotted posts sufficient to read at roofs; next boundary dashed and text-labelled.
  No opaque energy dome, full-screen tint, bloom or dense wall hiding jumps/meteor rings.
- [ ] Separate zone-status row from existing two disaster chips: `Zone contracts in …`,
  `Zone contracting`, then `Final zone`. Outside indicator adds distance and compass-like
  direction toward nearest entry; visible inside houses/school, does not depend on color.
  Timer expires from authoritative time, not UI pause; reduced motion disables pulses.
- [ ] Prioritize warning audio without interrupting disaster cues. Spectators see zone
  timing but no personal damage claim. Results show distinct zone death cause.
- [ ] New hazard selection uses viable remaining area: bounded meteor/lightning strike
  sampling, tornado path segments and warned fire fronts. Delay an incompatible new
  hazard if no reachable refuge/exit remains; do not silently cancel active damage or
  existing warnings. Protect required remaining routes from new breakage, not all roofs.
  Flood damage/height stays unchanged; defer new flood warning if adequate reachable
  high ground has become unavailable. Preserve director seeded reproducibility/history.

Gate G8.3: inspect indoors/outdoors/on roofs and stage transition with two hazards at
720p/1080p, including late zone+Flood+Lightning. Warning geometry matches authority;
route/controller checks and director tests reject trapping schedules. Record an actual
shrink/leave/re-enter/death/spectate/rematch interaction clip, not static proof.

## 8.4 — Integrated regression, performance and matching local packages

- [ ] Full `tests/run_ui_regression.sh`, new zone integration regression, and relevant
  service tests pass with strict runtime-error checks. Keep public-behavior tests for
  regression risks above; use scratch scripts for tuning/one-time measurements.
- [ ] Real authoritative 2/4/8/20-client runs: both maps, real zone outside/re-entry damage,
  valid two-hazard overlap, last-survivor/shared/timeout results, five rematches, owner
  departure, dedicated crash/retry, profile restore/earned equip. Accelerated fixture
  clocks are disclosed and never claimed as human full-duration play. Serial heavy runs.
- [ ] Profile matching Phase 7 scenarios plus zone drawing at 720p/1080p; stable node
  counts/resources after rematches, bounded sampling and no growing physics budget.
  Report native GPU 60FPS as not_run unless actually executed; no software greenwashing.
- [ ] Commit validated integrated source before `tools/export_playtest.sh` (exports
  committed HEAD only). Check repeated Windows/Linux outputs, matching PCK, hashes,
  unpacking, standalone Linux lifecycle/profile persistence and exact exported scene.
  Review notes state Windows-native/input/audio and separate-network checks not_run.
  Do not use new clients with historical public Phase 5 server.
- [ ] Record final gate evidence, archive this phase and deliver local package links.
  No public-server restart, CI deployment, release publication, capacity or data change
  without explicit separate authorization; use `[skip ci]` for source/docs pushes here.

Gate G8.4: technical/visual/replication/package checks passed; real-device uncertainties
remain explicitly open under existing waiver. Failed runs retained with proven fixes;
no speculative fairness, human-fun or production-capacity claim.

## Failure handling and implementation boundaries

If shrinking causes no-route flood traps, correct geometry/center/radius or defer new
hazard selection; do not immunize in-zone players or relax strict errors. If snapshots
exceed transport budget, use existing reliable fallback and measure it, not unreviewed
protocol rewrites. No randomness in center means reproducibility is testable; moving
centers and smaller terminal zones are deferred until this version proves playable.
This plan is ready for implementation but makes no completed-feature claim.
