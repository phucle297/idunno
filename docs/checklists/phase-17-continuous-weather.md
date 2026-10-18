# Phase17 — Continuous Weather and Roof-Correct Shelter

Status: implemented on 2026-10-18; focused checks passed; full staged gate rerunning
after a real cross-district bridge-landing defect was found and corrected.
Scope: prior proposal sections1–5 (current limitations, continuous coverage,
Rain, Snow and weather combinations), plus the reported precipitation indoors.
Toy Town is the primary redesign target; preserve existing Harbor behavior and
shared multiplayer/reset contracts. No map expansion is implied.

## Outcome and boundaries

Rain/Snow cover a coherent large outdoor region, accumulate on actual surfaces,
then dry/melt gradually. Terrain, cover and surface type explain variation;
random isolated discs and one blanket world-height plane are not the solution.
Rain changes route/traction choices; deep snow and ice have different behavior.
Never use random slip/ragdoll chances, ordinary rain HP drain, invisible damage,
forced control loss, or cosmetic equipment stat advantages.

Previous proposal groups B/C (extra HUD/status explanations, adaptive warning
system, death-chain presentation, pacing/director redesign, weather variants)
are rejected scope, not scheduled work. Existing readable warnings and escape
safety remain constraints, not permission to build those features.
Owner additionally approved A (rotating awning) and B (rotating shortcut bridge),
subagent implementation and release after completion. Other interactive ideas
remain proposals. No infrastructure change, advanced fluid simulation,
temperature meter, inventory or grabbing reintroduction is authorized here.

## Evidence and suspected indoor defect

- `game/main.gd::_configure_weather_patches` selects flat2.4m candidates from fire
  zones/refuges, not continuous outdoor coverage.
- `game/disasters/weather_surfaces.gd` already accumulates/melts/dries and ray-tests
  support exposure. Sampling distinguishes stacked support heights.
- Its precipitation presentation checks exposure at the patch center, then places
  moving drops/flakes at horizontal offsets and a fixed5m height. That is a
  candidate source of particles crossing a roof/awning boundary, not a reproduced
  diagnosis of the owner's affected room.
- Existing `tests/test_weather_surfaces.gd` and `test_weather_integration.gd`
  check sampled indoor dryness; they do not prove every real building's rain/snow
  particles stop at its actual roof. Owner reports water indoors beneath a roof;
  reproduce visual precipitation versus ground wetness separately, without Flood.

## M17.1 — Precipitation respects actual shelter

- [x] Reproduce Rain and Snow separately in Toy Town buildings, garage, awnings,
  doorways, stacked floors and exposed rooftops. Record offending coordinates,
  visible roof, collider/cover result, particle paths and sampled surface state.
- [x] Use a shared surface/exposure contract for authoritative accumulation and
  client presentation. Test each precipitation trajectory against actual cover;
  a center-point exposure test cannot authorize drops beneath neighboring roofs.
- [x] Intact cover stops rain/flakes before they enter rooms. Interior floors
  initially dry remain dry without a real water source; no wet decals leak from
  rooftops, through walls or between floors. Covered outdoor routes also shelter.
- [x] Roof destruction exposes only the actual opening; rebuilt roofs stop new
  precipitation. Existing legitimate moisture dries rather than vanishing.
- [x] Flood may enter roofed spaces by its separate water-level rule; no invented
  rain seepage through walls, roof leaks or interior runoff in this scope.

Gate (passed): old-head reproduction and current41 surface/76 integration checks;
20 Town shelters/280 Rain/Snow interior and roof controls; inspected15 render states.
Regression reproduces the defect before the fix; real-map indoor,
doorway/awning edge and roof controls pass Rain/Snow independently, no Flood;
inspect rendered interior/exterior and destroyed/restored-roof captures.
Owners/modules: WeatherSurfaces, map roof/cover geometry, weather integration tests.

## M17.2 — Coherent terrain-aware coverage and recovery

Depends on M17.1. Decide representation against real map geometry before coding:
bounded surface regions/cells with distinct height layers and batched rendering,
not unbounded per-drop physics or per-frame full-map raycasts. Server owns surface
state; cosmetic particles never decide traction or damage. Record measured budget.

- [x] Cover connected outdoor roads, courts, ramps, bridge decks and roofs with
  smooth transitions; no unintended dry gaps or effects bridging empty space.
- [x] Wetness increases over the outdoor surface; deeper puddles occupy authored
  low spots/curbs. Detail follows drainage/topography rather than uniform noise.
- [x] Drying varies predictably by exposure/surface; puddles linger after the sheen
  fades. Snow thins gradually into residual wetness; no abrupt disappearance.
- [x] Preserve support changes under collapse, volcanic terrain and map rebuilds;
  visual/contact boundaries agree, including sloped and stacked surfaces.
- [x] Update asset provenance for new/changed presentation via the asset workflow.

Gate (passed):41 surface checks include timestep/retained-moisture controls;
actual slope/stacked support and continuous render states inspected. Bounded1m
render cache/128 retained contacts, not material-specific hydrology.
Deterministic accumulation/recovery and boundary controls,
same elapsed time at different tick sizes, route-wide samples and inspected
early/peak/recovery views. No claim of physical drainage/fluid simulation.

## M17.3 — Distinct Rain, deep Snow and Ice movement

Depends on M17.2. Tune centrally; proposed curves are not measured balance results.

- [x] Rain affects sprint braking/cornering mildly; normal walking remains
  responsive. Wet ramps/bridges and covered/grippy alternatives create choices.
- [x] Authored deeper puddles apply readable, bounded traversal slowdown.
- [x] Deep snow slows traversal; ice reduces braking/turn traction instead of
  treating all snow as ice. Show the difference before it affects movement.
- [x] Add coherent roof/prop snow coverage and bounded cosmetic footprints/run
  trails; decorative banks never block doors, stairs or mandatory escape routes.
- [x] Audit garage–bridge–plaza and alternate covered routes; add only targeted
  canopy/grip/drainage detail needed for these choices, not a full map rebuild.
- [x] Preserve jump/air control, shove recovery and server/client prediction;
  ordinary weather does not randomly knock down or directly damage players.

Gate (passed): actual10m capsule dry/wet/deep-snow/ice trials100/102/140/118ticks;
braking0.792/1.029/0.874/2.762m. Integration76 checks; real-ENet movement/carriage
and five resets passed. Matched dry/wet/snow/ice route trials, sprint-versus-walk braking,
slopes/airborne controls, reachable escapes and real-client movement agreement.
Human fun/control feel stays unverified until reported, with existing waiver intact.
Owners/modules: player.gd, player_tuning.gd, WeatherSurfaces, Toy Town routes.

## M17.4 — Bounded weather combinations and full regression

Depends on M17.3. Retain Rain/Snow mutual exclusion and the existing overlap cap;
do not redesign disaster selection or schedule extra hazards.

- [ ] Rain limits outdoor Fire ignition/spread; dry interiors remain eligible.
- [ ] Fire melts nearby snow into wetness without falsely presenting fire as safe.
- [ ] Lightning can briefly electrify a warned local connected puddle, never every
  damp surface across town. Define puddle connectivity separately from wet sheen;
  retain a dry escape and existing Flood electrical semantics.
- [ ] Meteor clears snow visibly in its impact area without extra hidden damage.
- [ ] Flood washes away submerged snow and owns its own interior water contact;
  roofs above water keep independent surface state.
- [ ] Define duration, footprint, warning, surviving counter and reset for each
  combo; compare each hazard alone before overlaps. Prevent compounded unavoidable
  slow/slip/knockdown/damage, not by adding a new director system.
- [ ] Execute existing weather/map/hazard/full regression, both-map compatibility,
  real-client late join and five rematches; inspect wet/snow/ice/indoor/overlap
  states, and measure bounded update/render/network cost at representative20 peers.

Gate (not run): authoritative combo controls, no stale electrification/snow/wetness
after rematch, no route/collision or Harbor regression, full relevant suites pass.
Performance on software rendering does not establish native GPU60FPS.

## M17.5 — Player-operated rotating awning and shortcut bridge

Depends on validated weather milestones; module preparation may be delegated
separately, but gameplay integration/gates remain sequential.

- [ ] Add a Toy Town awning with two useful orientations and nearby crank controls.
  Rotation trades which route has shelter; roof geometry and precipitation agree.
- [ ] Add a wide optional bridge rotating between two destinations. Players on its
  deck travel with it; signals announce slow motion and a cooldown prevents spam.
- [ ] Validate live-player proximity/alive/standing intent on the server; clients
  request actions, never choose arbitrary transforms or other players' IDs.
- [ ] Preserve fixed ordinary routes, two exits and flood approaches. No crushing,
  trapping at endpoints, crowd launch, unbounded forces or door blocking.
- [ ] Replicate transition progress/state, late join, client deck carriage and
  rematch reset; deny dead/ragdolled/remote/spam activation. Respect terrain loss.
- [ ] Use shared toy palette, rounded supported geometry and clear controls;
  record deterministic generated provenance in the asset manifest.

Gate (not run): real-client accepted/rejected action cases, moving deck passenger
and endpoints, five rematches, all fixed-route/collapse checks and inspected
awning/bridge resting and moving states. No claim of human fun from automation.

## M17.6 — Integrated validation and authorized release

- [ ] Complete all preceding gates; run full regression and review source diff.
- [ ] Commit/push scoped source with Conventional Commits, matching Windows/Linux
  packages, checksum and exact-pack runtime checks.
- [ ] Release matching version and deploy using the existing EC2 workflow only;
  inspect exact-head completion and public smoke, do not alter capacity/settings.
- [ ] Record delivery URLs/hash/evidence separately and archive phase only after
  technical gates and delivery pass. Preserve unverified human/device limits.

## Delivery and acceptance

Remaining full-regression and delivery boxes stay open. Focused evidence and the
failed first full gate are recorded in root progress. Public Phase16 remains
unchanged until the integrated source passes and matching packages are delivered.
Human/device/network reporting follows [NEED_REAL_CHECK.md](../../NEED_REAL_CHECK.md),
without adding mandatory user checks or converting the existing waiver into a pass.
