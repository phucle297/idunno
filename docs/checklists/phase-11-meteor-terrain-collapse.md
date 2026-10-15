# Phase 11 — Meteor Terrain Collapse

Status: active11.4 — all-district/Oracle fixes implemented; focused core/routes and both-map real-peer matrix pass. Staged-tree regression and committed-HEAD release verification pending. Owner now authorizes commit/push/release. This replaces the superseded shrinking-circle/gradual-HP-loss scope. Its complete prior checklist, decisions and progress snapshot are preserved byte-for-byte in [the cancelled archive](../old-docs/phase-11-superseded-zone/checklist.md). Prior zone passes are evidence for superseded code only; they are not gates for this phase. Phase12 remains planned and inactive.

## Product outcome

Warn players before a heavy meteor permanently removes a connected, bounded map district for the round. Removing its geometry and collision creates real holes; an authoritative player whose root falls below y=-0.8 dies immediately in one lethal batch. This is terrain loss, not a circle, gradual HP pressure, AOE damage, or a shelter bypass. Ordinary `MeteorShower` keeps its existing explosive contract.

Defaults are implementation decisions, not owner-tuned balance: use 3×3 districts. Town cuts are x±30 and z[-37,20]; Harbor cuts are x±12 and z[-10,14]; outer bounds are x±56/z±56 and x±32/z±32. Seams avoid cutting whole walkable structures, including the now-removable warehouse. All nine districts have equal initial eligibility, including centers and high refuges, even during Flood. Remaining sectors must stay connected; there is no privileged center for the connectivity traversal. Ground and overlapping foundations are physically partitioned; removed district geometry/collision stays absent until rematch. Reset restores it without rebuilding the world.

## 11.1 — Real holes, collision, fall death and reset

- [x] Partition authored ground and overlapping foundations by district, with stable map-specific sector IDs and no permanently protected districts.
- [x] On authoritative removal, hide/remove that district's geometry and collision until rematch; do not substitute a visual decal, invisible floor, respawn, or world rebuild. Restore intact geometry/collision during reset.
- [x] Apply exactly one authoritative lethal damage batch when an alive player's root enters the void below y=-0.8. Roofs/walls cannot save a player in a removed district; dead/results/lobby/reset players are immune and simultaneous falls retain existing shared-result behavior.
- [x] Delete old circle APIs and tests rather than retaining a fallback.

Gate G11.1: both maps demonstrate all nine real collision holes, reliable fall death and rematch restoration without rebuilding. Surviving high routes keep support, removed high routes lose support. Validation: **passed** — core4142, routes2818 walks18 legal_masks278; logs `/tmp/collapse-equal-core.log` and `/tmp/collapse-equal-routes2.log`. Includes center/warehouse escape, ordinary rubble depth cleanup, damage/snapshot updates cannot revive removed support, and broken-then-collapse rematch restores the authored lid collider top.

## 11.2 — Telegraph, schedule, escape and hazard fairness

- [x] Schedule four warned removals at normalized 120/270/390/510 seconds of a 600-second match. Each has a 30-second warning scaled for fixture duration. If a clock jump passes a warning boundary, issue the warning first and postpone removal; never collapse an unannounced district.
- [x] Render a readable warning rectangle and a separate HUD row indoors; spectators receive timing only. Keep ordinary disaster chips readable.
- [x] Exclude removed and pending ground from new hazard targeting. Protect remaining high-ground routes and connected escape sectors; defer an unsafe selection rather than trapping players. No gradual/AOE HP pressure from the collapse meteor.

Gate G11.2: schedule/clock-jump, warning-before-removal, connected-sector, route, HUD/indoor/spectator, and overlapping-hazard fairness checks pass. Validation: **passed** (schedule/clock-jump in core=3534; TERRAIN_COLLAPSE_PRESENTATION_OK checks16; full regression UI_REGRESSION_OK suites=52 matrices=5 managed_clients=20 persistence_restart=passed exit0 `/tmp/collapse-regression-v2.log` with MapSafety233/MapVariety424; rendered warning/indoor/hole/spectator captures visually inspected plus pixel evidence — warning amber present (5214 px), hole renders as pure sky absence (198633 background px in the Town hole crop vs 78210 intact; former slate/ink pit colors gone), reset==intact AE=0 `/tmp/collapse-render-v3.log`; escapes under 30s in the routes gate).

## 11.3 — Authoritative compact snapshots and real peers

- [x] Replicate compact authoritative map/district/warning state, including reset and stale/malformed-state rejection. Clients never select, remove, restore or kill.
- [x] Run real 2/4/8/20-peer both-map scenarios for warning, removal, fall death, results, reconnect/owner change where applicable, and five rematches.

Gate G11.3: real peers converge on the same warned/removal state and authoritative outcomes through rematches. Validation: **passed** (TERRAIN_COLLAPSE_ENET_MATRIX_OK cases=8 `/tmp/collapse-enet-matrix-v2.log` — maps2 players2,4,8,20 with client-side collision rays, serialized departures, five rematches, and the replicated fallen-prop despawn/restore stage; logs `.scratch/terrain-collapse-enet/`). Late/reconnect and owner-change remain covered by the general session suites, not this fixture.

## 11.4 — Rendered/regression/resource/matching committed-HEAD package evidence

- [x] Run focused/full regression and strict runtime-error checks; inspect rendered 720p/1080p indoor/outdoor warning, hole, fall, spectator and rematch states. Done: UI_REGRESSION_OK suites=52 matrices=5 managed_clients=20 persistence_restart=passed exit0 (`/tmp/collapse-regression-v2.log`); TERRAIN_COLLAPSE_RENDER_OK captures=24 with reset==intact AE=0 and hole states visually inspected as pure sky absence (`/tmp/collapse-render-v3.log`); 8-rematch soak COLLAPSE_RESOURCE_SOAK_OK checks=53 cycles=8, node/orphan deltas 0 (`/tmp/collapse-soak-v2.log`).
- [ ] Measure resources/rematch stability and validate matching committed-HEAD Windows/Linux packages, PCK/hash/unpack and standalone lifecycle evidence.

Gate G11.4: rendered, regression, resource and matching-package evidence passes. Status: **in_progress** — owner authorizes commit/push/release; exact-head exports, existing automatic server deployment and public release verification remain pending. Native Windows/GPU/audio/human/separate-network checks remain honestly not_run under the existing waiver.

## Validation log

- 2026-10-15 — Follow-up Oracle client-reset finding reproduced failing on Harbor2
  before the empty-quake reset and passing after it. Latest fixture breaks a real
  roof first, then requires restored intact visual/collider and a ray hitting that
  panel after all five rematches. Final matrix passes8/8 both maps2/4/8/20
  (`/tmp/collapse-reset-final-matrix.log`), plus a separate Harbor20 pass. An earlier
  Harbor20 rematch assertion failed intermittently; the diagnostic-only rerun passed,
  so its exact original predicate remains unknown. Ray queries now wait two physics
  frames for deferred shape restoration, matching removal probes. No tolerance or
  timeout was relaxed; failed logs are retained and per-stage diagnostics remain.
- 2026-10-15 — Latest all-district/Oracle iteration supersedes earlier protection rules:
  center and Harbor north removed first in the real-peer matrix (8/8 both maps,
  2/4/8/20 peers); parking uses the ordered prop stream only, not cross-channel RPC.
  Forty captures include center/north warnings and holes; center holes and warehouse
  absence visually inspected. Wide overview warning outline is thin but HUD readable.
  All-mask test exposed deferred reset/removal ordering re-enabling colliders; queue
  removal last. Three legacy escape waypoints crossed real walls/rails after restoring
  collision correctly; use the garden west exit and dock gangways. Routes rerun passes.
- 2026-10-15 — Owner feedback iteration: the slate pit walls/dark depth plane read as
  fake, so removed districts now render as pure absence (sky background shows through;
  `CollapsedDistrict` void boxes deleted, no fallback). Endless-fall crash class guarded:
  alive players die below y=-0.8 as before; networked props falling past `MAP_KILL_Y`
  park frozen/hidden below every support ray, despawn via reliable RPC, converge through
  the prop-snapshot stream for rebuilt clients, and unpark at spawn on rematch. Re-run on
  this change: core TERRAIN_COLLAPSE_OK checks=3534 (adds 45 fallen-prop checks),
  presentation 16, routes 1972 walks=15 legal_masks=194, 24 rendered captures with
  reset==intact AE=0 and hole sky-absence histograms (198633 sky px in the town hole crop
  vs 78210 intact; old pit colors gone), inspected town/harbor hole + warning + indoor +
  spectator captures, and the quick 2-player ENet case with the new prop_despawn stage.
  Full reruns on the same code: ENet matrix 8/8 PEERS_OK + MATRIX_OK (2/4/8/20 both
  maps, prop despawn/restore replicated), soak COLLAPSE_RESOURCE_SOAK_OK checks=53
  cycles=8, and UI_REGRESSION_OK suites=52 matrices=5 managed_clients=20
  persistence_restart=passed exit 0 with zero failures.
