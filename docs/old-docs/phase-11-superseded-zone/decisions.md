# Disaster Party — Active Decisions

## Phase11 activation — 2026-10-15

The owner's “Continue implement” activates the next roadmap phase, Shrinking
Survival Zone. Milestone11.1 measures collision routes and hazard feasibility
before enabling damaging pressure. Phase12 remains planned. The public server
continues running Phase10; unfinished Phase11 work is not a deployment candidate.

### Measured geometry, not a smaller circle at any cost

The old 22m Town candidate excludes the roof-ramp ground landings: the outside
edge at(-17.5,-29.3) is27.57m from(0,-8). Keep that center but increase the final
Town radius to28m, with intermediate targets36/32/30/28m. Harbor keeps its candidate
center(0,-10) and32/28/24/22m targets, pending full route checks. Initial coverage
uses the furthest square-map corner plus0.5m, not a half-extent radius.

Store the footprint beside the map's existing route anchors. It is geometry data
only at this milestone: no damage, HUD, replication or new hazard scheduling is
enabled prematurely. Regression walks must use the real controller without jumps
or crates, include all20 actual spawn slots, refuge centers/exits, major rooms,
both presets and intact/damaged/broken structures. Two broad structural refuges
and their entire approach/return routes must survive inside each final circle.

Exploratory straight-line routes hit actual Garden benches/planters and civic
lamps/planters. These are invalid proposed test paths, not evidence that the map
has no exit. Read their collision geometry and walk the open promenade/civic
stairs instead; do not remove solid scenery to make a fixture pass. A focused
corrected probe walks GardenCafe in11.53s and NorthWest in6.37s. Full matrix and
mutated-terrain/weather coverage were required before accepting the footprint.
The subsequent durable matrix passes14414 checks/672 walks, longest12.78s,
including both presets and damaged/broken structures with cooled Volcano/Rain/Snow.
Both independent high refuges and their approaches/returns stay within the final
circle. G11.1 now passes; earlier probes alone were not gate evidence.

Town's volcanic district lies inside the candidate final footprint; Harbor's
boardwalk volcano lies outside it(30–34.93m from center). Future selection must
defer an unusable new Harbor eruption, not enlarge the final zone merely to retain
every hazard or move already-announced warnings.

### Conservative area and bounded new hazards

Credit only authored accessible immutable planar colliders, with2m cells expanded
for the0.28m player capsule and standing clearance. Keep eligible support heights
for indoor versus roof targets, but count each horizontal cell once. Do not credit
inaccessible roofs, breakable panels, ramps or complex volcanic surfaces. Cache
collision clearance at max16 queries/frame and1500us soft budget; shrinking only
filters cached cells. Eruption immediately excludes the district plus1.8m access
margin; cooling does not restore ground credit. Actual terrain removal rebuilds.

From first shrink, new targets must fit their predicted circle plus1.5m escape
margin and avoid mandatory high-ground approach segments. Meteor allowance uses
cached navigable area/3072m2, never a forced minimum1; final maps therefore defer
new Meteor waves. Lightning/Tornado use at most16 attempts. Tornado clips authored
segments, preserves at least one available independent high refuge, then freezes
the announced path. Fire reserves half the remaining viable sites. Bee/UFO/Quake
filter new targets, not existing pursuits/warnings. New Flood requires both high
patches; new Rockslide/Volcano must keep their authored footprint inside forecast
coverage. Before first shrink the original hazard behavior remains unchanged.

The hazard fixture passes1289 checks and eleven related suites pass. These are
headless feasibility checks, not rendered zone, active-zone multiplayer or human
fairness acceptance. The Phase10 overlap fixture now runs at120s, before zone
pressure can legitimately defer the Harbor eruption; late deferral has its own test.

### One authoritative clock and pre-timeout exposure batch

SurvivalZone owns the normalized radius/stage/rate curve and analytically integrates
fixed-root exposure across every radius/rate boundary. Height is irrelevant; roots
within0.0001m of the boundary are inside. Main computes all alive authority roots'
events before advancing time. MatchManager advances the capped clock/participation,
applies one damage batch, then ranks timeout only if still ACTIVE. There is no
separate exposure timer to carry across re-entry, death, lobby or rematch. Existing
hazard process order and shared-final-elimination policy remain unchanged.

Snapshots carry seven floats: schedule identity, center x/z, radius, next radius,
stage and authoritative remaining time. Validate type/length/finite/ranges and
agreement with map configuration and match time before mutating map or consuming
sequence. Client presentation uses the same curve over replicated time, never a
local damage clock. No compatibility fallback for hand-built old test snapshots.

334 authority assertions and real ENet2/4/8/20 total peers on both maps/five rematches
pass. Ten-second accelerated fixture clock is disclosed; no full-duration/human
claim. Actual Town20/Harbor20 snapshots1648/1472 bytes execute the existing reliable
fallback above1200, while small rosters exercise ordered-unreliable. Fixture failure
history is retained in root progress: wrong inside coordinate, clock freeze blocking
transport cadence, winner ordering, teardown RPC lifetime and simultaneous listen-
host peer relay departure. Stop producers and serialize acknowledged test departures;
do not alter production listen-host relay or weaken runtime checks.

### Restrained terrain-following presentation

Use96 ground segments and16 dotted posts per current/next circle. Amber current and
cream dashed next match the HUD legend; no collider, opaque wall, local clock,
pulse or damage logic. Query at most16 heights per physics frame and rebuild mesh
at10Hz; headless skips geometry work. Map/rematch/Volcano/structure changes invalidate
cached supports on authority and client snapshots. Walls legitimately hide ground
marks: indoor entry guidance is HUD text, not a through-wall overlay. Root x/z and
the authority tolerance determine outside distance; positive Godot yaw is opposite
compass bearing, covered by all eight actual camera forward directions.

Zone status occupies its own centered row, leaving both hazard chips and major
warnings available. Spectators retain timing but never get personal HP/s claims.
One quiet existing synthesized cue per stage waits behind reserved disaster audio
and uses the existing four effect voices. No new audio source or aesthetic/human
recognition claim. Presentation175 checks,32 inspected real-engine720p/1080p captures
and a15s controller-driven shrink/outside/re-entry/death/spectate/results/rematch clip
pass. Clip stages230→550s and reduces fixture health for timely death; it is not a
full-duration or network playtest. G11.4 remains open for combined regression,
performance/resource measurements and matching local delivery.

## Previous delivery (historical context)

Phase10 and its volcanic-relief refinement completed their agent-owned technical
gates. The refinement's [checklist](old-docs/phase-10-volcanic-relief-followup/checklist.md),
[decisions](old-docs/phase-10-volcanic-relief-followup/decisions.md) and
[evidence](old-docs/phase-10-volcanic-relief-followup/progress.json) are archived
separately from the original Phase10 snapshot.

The owner subsequently authorized check/commit/push/deploy on2026-10-15.
Source [945aa9f](https://github.com/phucle297/idunno/commit/945aa9f69631439c46b78983270b016f6668676c)
passed the fresh staged-tree full gate and was deployed by the existing EC2 workflow.
Exact deployed-PCK/public two-client checks pass; matching Windows/Linux bundles
are supplied as thread artifacts, not a new GitHub Release. Old local packages and
archive no-deployment statements remain historical. No infrastructure capacity/store
changes. Phase11 activation above followed this completed delivery; Phase12 remains
planned. Native GPU/human acceptance is still unverified
under the preserved waiver. Root `progress.json` owns delivery evidence and state.
