# Phase 8 — Character, UI and Disaster Counterplay

Status: in progress; 8.1–8.2 technical gates passed; 8.3 is current.
Owner priority2026-10-14 supersedes the former
Phase8 safe-zone ordering. Current public baseline is Integrated Town revision
2619665ce31e02dd7233e9099c0d5a6e8c9a2e2d. No new deployment/release is authorized.

## Outcome and boundaries

Make the selected non-human Soft Creature B feel physically part of the rounded
town; make survival actions visible, useful and teachable. Fix existing hazards
before adding new ones. Keep Town112m/Harbor64m, server authority, solo exception,
existing cosmetics/hitboxes, two concurrent disasters and bounded physics.
Do not rewrite DESIGN, switch to human anatomy, add combat/inventory/progression,
start streaming or implement the shrinking zone. New numeric values below are
initial tuning proposals, not measured balance or promised human enjoyment.
Owner revision2026-10-14: remove crouch entirely and temporarily remove player
grabbing/holding. Future held hammer/wood interactions are backlog only, not a
replacement mechanic in this phase. Existing loose hazard props/static cover remain.

## Evidence versus reports

- `meteor_shower.gd:start_disaster` currently schedules3 cluster or4 lane strikes
  sequentially, each with2.5s warning and0.65s impact. Town area grew from4096 to
  12544m² without increasing those counts. This supports a density hypothesis;
  the owner's easy-dodge experience has not been reproduced in their session.
- `earthquake.gd:_apply_pulse` globally damages every living registered player,
  irrespective of crouch/contact/cover, and knocks down every third pulse. Defaults
  are5HP/pulse,1.25s interval,8s active; a normal fine-step event is about35HP,
  not an automatic100HP kill. Repeated events, falls, collapses and overlaps need
  traces before attributing the reported unavoidable death to one cause.
- Fire origin and graph-neighbor selection already use seeded randomness. Existing
  damage checks x/z radius only, not support height. Main's combination hooks have
  no Fire/Flood extinguishing. Reported insufficient variation is a balance/shape
  issue to measure, not proof that Fire uses no randomness.
- Released crouch lowers capsule/speed and suppresses jumping; carrying slows
  movement. These still exist in the public build but will be removed below.
- Owner reports arm snapping during rapid Shift press/release. Reproduced on the
  real controller/map by `tools/repro_phase8.gd`: every walk/run/idle reselection
  restarts the clip at `anim_pos=0.000` (32 restarts on a steady rapid-Shift run-up),
  because `toy_character_visual.gd:play_clip` calls AnimationPlayer without explicit
  blending on clip change. Local cause verified at the clip layer; remote two-client
  continuity is deferred to 8.6.

## 8.1 — Reproduce and lock survival contracts

Owners: existing disaster/player scripts, `game/main.gd`, relevant tests.

- [x] Record deterministic seed, map, preset, positions, HP causes, pulse/strike
  times, grounded/crouch/carry state and collapse routes for earthquake-alone,
  Flood+Earthquake, Fire+Flood, and meteor on both maps. Use actual controller
  and collision, not forced safe coordinates. Preserve failing and control traces.
  Evidence: `tools/repro_phase8.gd`, `.scratch/phase8-repro/repro.log`,
  `PHASE8_EQ`/`PHASE8_FLOODEQ`/`PHASE8_FIREFLOOD`/`PHASE8_METEOR` markers pass on
  both maps at seed811000.
- [x] Produce a counterplay trace sheet and the baseline captures used to pin it:
  recorded in `docs/decisions.md` "Phase 8.1 baseline reproduction". Character pipeline
  and references are unchanged; the animation-owner/generator history was read before
  this change and is untouched.
- [x] Lock the contracts in8.2–8.5 against traces; change provisional numbers only
  with evidence. Begin with earthquake global-pulse and fire submerged-zone cases.
  Locked: quake pulse is global5HP/1.25s (35 HP/event), submerged fire still burns,
  meteor density scales with map area.
- [x] Capture rapid Shift press/release while moving, plus sustained walk/run and
  stop/start controls; trace clip/time/limb poses on the local character
  (`PHASE8_SHIFT clip_restarts=32`, every edge `anim_pos=0.000`). Remote-character
  continuity is not reproducible in a single-client harness and remains for 8.6.
  Crouch/grab inputs and owning paths are inventoried in 8.2 before removal.

Gate G8.1: distinguish direct earthquake HP, fall, rubble and overlap causes;
measure strike density and seed variation, record exact reproduction commands.
Executed at seed811000 (see `docs/decisions.md`): direct quake HP separated from
Flood drowning and submerged Fire; no fall-damage path exists in the repository;
Burning Rubble (fire+quake) and Impact Debris (meteor) are the distinct rubble
causes, identified in code and watched for later overlap runs. An inability to
reproduce a user session stays unverified, not "fixed".

## 8.2 — Character model, animation and action feedback

Owners: `tools/asset_generation/generate_assets.gd`, character scenes,
`game/player/toy_character_visual.gd`, `player.gd`, HUD/UI tokens, manifest.

- [x] Preserve bean-like continuous body, cream face, short rounded limbs/rubber
  feet; improve body/limb joins, grounded foot placement, relaxed hands
  and material response. Match environment matte materials and restrained
  daylight. No collider enlargement, cosmetic advantage or gameplay camera reset.
- [x] Distinct readable walk, run, landing/get-up and hazard reaction
  poses. No T-pose, sliding feet at common speeds, snapping arms or clips
  fighting ragdoll. Keep one rig/body contract across eight outfits and remotes.
- [x] Make walk/run transitions interruptible without restarting gait on every Shift
  edge: preserve locomotion phase, blend arm/body pose at current speed and handle
  reversals during blending. Reuse the existing animation owner; choose blend timing
  after baseline reproduction, not by adding input delays or hiding arms. Preserve
  movement speed, jump response, knockdown priority and remote animation continuity.
- [ ] Remove crouch and temporarily remove grabbing/holding end to end: controls,
  capsule/speed branches, prediction/input/snapshot fields, authority handlers,
  carry slowdown/ownership/springs, prompts and dedicated-only clips/assets. Remove
  references that exist only for these actions; preserve loose-body hazard simulation,
  static cover, emotes and other independent player interactions. Update controls,
  tests and matching client/server build identity; stale packets cannot restore them.
  Source removal and migrated controller/prediction/network tests are implemented;
  matching package exports/identity remain part of8.6, not a published build claim.
- [ ] HUD explains the actual action: "Leave cracked roof", "Water
  cools this area", "Shelter from falling rocks"; do not imply immunity or show
  removed C/F actions. Icons + text + countdown,
  not color alone; no full-screen effects obscuring routes. Preserve reduced motion,
  warning audio priority, keyboard/focus behavior and readable720p/1080p layout.
  C/F prompts are gone now. Hazard-specific escape/cooling context will be implemented
  alongside the actual8.3–8.5 hazard rules; do not display unimplemented counters.

Intermediate evidence: `PLAYER_INTEGRATION_OK329`; original clip-reset32 edges
now retain phase, maximum sampled arm delta0.166rad after speed matching. Planted
foot contact128 samples/8 outfits: drift0.000513m and height error0.000774m at120Hz,
level ground (not terrain IK). Generator8/seed297 retains geometry, collider and
triangle/outfit contracts;10 clips. Actual in-map standing/walk/run/landing/ragdoll/
get-up/overlap, near and gameplay distances,720p/1080p and real OS-input videos are
in `.amp/in/artifacts/phase8`; inspected, no native GPU/aesthetic acceptance inferred.
Final full strict regression passed: 40 suites, five matrices, managed20 and
settings restart. Final recovery/landing recordings refreshed and inspected. Earlier failures
exposed a fixture-only rematch observer race. Two consecutive real two-peer/five-
rematch runs passed with reliable observation barriers and exact prop-reset wait;
no gameplay delay or weakened tolerance was added. See `reviewing-godot-gameplay`
for recovery. G8.2 source/visual gate passed; package and hazard-context obligations
remain explicitly tracked under 8.3–8.6.

Gate G8.2: actual in-map near/gameplay-distance renders and interaction clips of
standing/walk/run/rapid-Shift/ragdoll and overlapping warnings, two resolutions, all outfit
silhouettes. Check contacts and animation playback, authoritative hitboxes unchanged,
manifest provenance measured. Rapid Shift at different gait phases must not repeatedly
snap limbs to the initial pose; inspect real pointer/keyboard input clips as well as
pose traces. Former C/F input does nothing locally or remotely, no leftover ownership
or altered capsule/speed after rematch. Native Windows/GPU/user aesthetics remain unverified.

## 8.3 — Earthquake has an actionable escape strategy

Owners: `earthquake.gd`, player movement state, breakable structures, main/HUD.

- [ ] Replace unavoidable global HP pulses with warned localized fractures,
  structural collapse and debris exposure. Shake itself is bounded cosmetic feedback,
  not a whole-map HP tax or forced global knockdown. Actual dangerous contact/impact
  is authoritative; no new brace key, jump-spam immunity or cosmetic protection.
  Preserve existing hazard/prop force caps and normal knockdown recovery.
- [ ] Telegraph dangerous ground/support before damage or collapse; stable ground
  and a reachable relocation route must be identifiable with ordinary walking/running.
  Escaping the warned footprint protects against that quake exposure, not independent
  Fire/Flood/fall damage. Avoid failures where the only safe roof collapses or where
  water submerges all advertised safe ground. Delay incompatible selections if needed.
- [ ] Validate a surviving ordinary-controller strategy for a whole quake and a
  seeded full-duration solo match; no health reset/heal/debug teleport. Standing
  in-danger control must demonstrate relocation matters. Flood+quake retains reachable
  high refuges and does not break all escape routes or create recovery stun-lock.

Gate G8.3: inside/outside warned footprints, before/at/after activation, roof/ground,
collapse relocation, simultaneous deaths, five resets and real remote convergence.
Extend earthquake/integration/combination tests through observable HP/pose/routes;
retain reported full-round failures until their actual causes are resolved.

## 8.4 — Varied fire and coherent environmental water interaction

Owners: Fire/Flood, support/collision rules, main/HUD.

- [ ] Give fire zones real support elevation and bounded vertical exposure. Flood
  crossing a zone's burning surface extinguishes that zone, its pending ignition
  and submerged burning rubble; it does not extinguish a dry roof above water.
  Update visuals and authoritative damage together, before that frame's fire damage.
  Wet zones cannot reignite until dry; no old pending-front resurrection on draining.
- [ ] Seeded variation in eligible dry ignition sites, front shape/direction and
  propagation timing with minimum warning and capped burning area. Compare same
  seed replay/different-seed coverage, not RNG invocation counts. Keep connected
  fuel graph, route escapes and visible impending ignition, not silent teleport fire.

Gate G8.4: dry roof over flooded ground, just-before/at/after immersion, draining,
pending ignition cancellation, Fire+Tornado/rubble, remote convergence and5 rematches.
Measured variations across seeds; each extinguished visual corresponds to no damage.
No held shield, water pail, pour/refill or player-item dependency in phases8–10.

## 8.5 — Meteor pressure without unfair instant death

Owners: `meteor_shower.gd`, director pacing/selection, main snapshot/HUD/cover.

- [ ] More geographically distributed strikes on the initially wide map, with
  bounded waves rather than a fixed early/middle/late count escalation. Derive total
  count, concurrency and footprint pressure from usable navigable area and measured
  exposure, not elapsed time alone, player count alone or inverse zone area. As area
  shrinks, reduce/cap new strike budgets; never multiply late-match escalation by
  zone concentration. Initially cap4 concurrent warning/impact sets, tune with evidence.
  Without a zone use the full playable footprint; Phase11 supplies remaining area
  through the existing targeting owner, not a zone implementation in Phase8.
  Early pattern stays forgiving; unchanged warning floor
  ≥1.2s, default2.5s. Hard still changes pace rather than hidden damage multipliers.
- [ ] Mix cluster, lane and scatter with seeded terrain-aware targeting near occupied
  districts and routes, not uniform mostly-empty112m terrain or exact player-foot
  tracking. Freeze targets when warned. Preserve reachable exits/shelter; reject
  patterns that jointly carpet the only route during another disaster.
- [ ] Telegraph every real strike; cap effects/debris/impulses and aggregate a wave's
  overlapping hits explicitly (no accidental repeated damage from cosmetic fragments).
  Damage/cover tests discriminate direct hit, near miss, roof protection and rubble.

Gate G8.5: full/half/small usable-area fixtures on both maps (small area never has
greater strike density/concurrency from count escalation), seeded escape measurements, multiple
simultaneous warnings replicated correctly, same-seed replay, cover/overlap/cleanup.
A moving control is measurably safer than standing still but neither has unexplained
global immunity/death. Do not claim human difficulty from a synthetic survival rate.

## 8.6 — Integrated delivery gate

- [ ] Full source/UI regression, service/admission tests and relevant hazard matrices;
  actual2/4/8/20 clients for action removal/animation/quake/fire/waves, both maps,5 rematches, owner
  departure/crash retry, shared/timeout results and profile/equipment compatibility.
  Run heavy jobs serially; keep strict runtime errors and static-map rematch reuse.
- [ ] Render actual model/UI/hazards, inspect clips; measure CPU/physics/snapshot
  bytes, peak warning/body counts and memory growth. Preserve32 authoritative loose
  bodies and existing transport fallback. GPU60FPS stays not_run without hardware.
- [ ] Commit source, export matching Windows/Linux local bundles twice, verify hashes,
  PCK equivalence/identity, unpack and standalone lifecycle/profile restart. Preserve
  limitations and failed evidence. Source/docs pushes use `[skip ci]`.

Gate G8.6: all required technical/render/package gates passed; no unexecuted human
acceptance invented. Public deploy/release requires a new explicit authorization.
