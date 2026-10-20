# Active phase decisions

## 2026-10-19 — Bounded toy sabotage, survival remains the win condition

Owner authorizes the remaining plan, per-unit commit/push and final release.
Start M20.1 with foam blaster, plunger rocket and squeaky hammer; preserve G shove,
E mechanisms, movement, existing outfits and disaster survival. Do not restore
grab/crouch, invent progression, give permanent loadouts or direct weapon HP damage.
Server owns slots/ammo/competition/aim eligibility/swept hits, effect IDs and reset.
Use a separate sabotage controller rather than putting every toy behavior in Main.
One held slot and finite visible pickups; shared cross-item/shove protection must
prevent alternating attackers bypassing recovery. Keep ordinary control loss≤1s
and protection≥1.5s; avoid routine hard stun.

[Phase19 evidence](old-docs/phase-19-multiplayer-frame-budget/final-controls.json)
provides an orb baseline, not native headroom. Begin with≤4 global/≤2 per-player
projectiles,≤6 placed/warning effects and no new loose rigidbodies. Reserve rocket
warning capacity before accepting its shot. Measure incremental draws/CPU/IPv4 and
resource cleanup against the trial ceilings in root progress before expanding.
Retain real warnings, cover and escape routes; no silent quality/server-rate cuts.

Native thermal/FPS, physical focus/minimize and extended diagnostic follow-up remain
unverified under the existing nonblocking waiver. The owner's device-specific
symptom is not claimed resolved. Phase19 source is pushed but not released/deployed;
public remains the Phase18 build linked in root progress. No release until the
remaining approved sabotage scope is integrated and verified.

## 2026-10-20 — Compact live state and visible counterplay

F takes/swaps the single held slot; captured left mouse uses a finite charge.
The first click after pointer release only recaptures it. G shove and E town
mechanisms remain independent. No gamepad/touch support is implied. Death,
departure and round/session changes clear actions; swapping does not cancel an
already fired projectile or its warning. Server-origin sphere sweeps include
initial world overlap and capsule-edge hits rather than a centre ray alone.

Use fixed-width bounded wire records, decoded/validated before applying a match,
instead of repeating toy dictionary keys. Local presentation retains full typed
values. Malformed counts/lengths/catalog IDs/nonfinite values are rejected. Session
receiver dedup resets with its source; rematches retain monotonic impulse IDs.
This avoids a reused local avatar ignoring early hits in a fresh network session.
Each item impulse also carries its round generation: monotonic IDs cannot reject
a previously unseen old event delayed across independent match/event channels.
The receiver rejects old rounds without advancing its current ID; a same-channel
fixture barrier proves rejection over real ENet after five rematches. Aim pitch
is checked after normalization so rescaling cannot turn a valid-length vector
into an otherwise illegal firing angle.

One-surface silhouettes and a shared warning/result pool avoid extra bodies and
per-part draw calls. Active warnings take priority over cosmetic results. Coral
telegraphs contrast against cream paving; swing text sits ahead of the avatar,
not inside it. Correctly clockwise top-facing warning geometry is retained.

[First-slice measurements](checklists/phase-20-first-slice-metrics.json) preserve
the initial failed separate-run apply sample as well as the alternating paired
replay investigation. Pairing the same full payload isolates toy apply work from
weather/scheduling variation; it is not native throughput or thermal evidence.
No native/Internet/human acceptance or final release is inferred from these tests.

## 2026-10-20 — Charged lane, return lane and temporary water

Batch2 reuses the same bounded authority/presentation/wire pools: glove2charges,
0.65s narrow3m warning and5.5 horizontal push; disc2throws,6m straight outward
then return lane, at most one victim per leg and no homing; soaker6short pulses,
1.8 push and a supported0.9x1.8m strip fading/drying over6s. All share existing
recovery, world cover, finite lifetimes and zero direct HP damage. Planar melee
normalizes horizontal aim after validating camera direction so pitch cannot
silently disagree with the rendered ground cone. Disc direction gets a merged
short tail, not another particle/body draw. Enlarged warning text follows render
review. Successful water ground contact is a splash, not a misleading blocked hit.

Water affects movement traction through replicated toy state only. It cannot
invent global precipitation, electrify disconnected water or persist through
WeatherSurfaces footsteps/covered residuals. The initial merged sample_surface
implementation failed the real dry render budget:4204→6156draws because footsteps
retained temporary toy water and enabled town-wide weather overlays. Moving the
toy contribution into movement_surface fixes ownership; same40sample real-client
render control returns4247draws (+43≤64). Keep the failed sample, regression for
empty weather residuals after a toy-wet footstep, and measured limits. Temporary
water beyond solid indoor dividers is rejected by an actual cover ray.

### M20.2 batch3 — Supported, temporary traps

Soap(2charges) changes local steering using the existing ice-braking path, not
weather accumulation or random ragdoll; jump or walk around its0.7m radius.
Spring(2charges) arms visibly for0.8s, launches one touching capsule at5.4m/s,
then disappears. Lift sets velocity, never stacks, and shares1.5s cross-toy
protection. Confetti(1charge) warns for1.4s before the existing2.4m covered
radial shove, no direct HP damage. All placed effects share the six reservations
and fixed record widths. Placement checks a clear forward line and nearby level
floor before spending ammo; unsupported/dead-owner traps clear instead of floating
after collapse. No solid obstruction can seal a door or refuge exit.

Short labels above/ahead of the avatar replace long body-occluded instructions;
striped soap, raised spring rails and confetti ring differ without relying only
on color. Eight actual public-use720p/1080p states inspected; authority98,
presentation15/audio11 pass. Real spring capsule rises0.684/0.774m then returns
to ground. Final real2/4-peer both-map nine-toy matrix passes finite charges,
production replicated lift and5rematches. Observe lift at production acceptance
in a test-only subclass, not later velocity after independent-channel movement;
wait on actual hammer protection expiry before the lift control. All four
both-map2/4-peer controlled delay/loss cases pass. Stable maximum-slot trial
passes+43draws,+0.268ms authority,+0.243ms paired apply,+20.71%IPv4; detailed
phase-20-batch3-metrics.json qualifies these as incremental orb controls, not
native thermal/FPS or human fun acceptance. Full staged gate passed and batch3
was committed/pushed as2f0059d, not released/deployed.

### M20.2 batch4 preparation — Foam blocks shots, not escape

Direct map inspection and focused Oracle consultation reject an endpoint-only
solid foam wall: Harbor gangway is1.5m wide, a transverse1.2m wall leaves0.3m
total versus the player's0.56m capsule diameter. Existing pickup validation
excludes route endpoints/exits, not full mutated-terrain corridor connectivity.
Jumping, ammunition or waiting cannot be prerequisites for disaster escape.

Revise proposed movement-lane obstruction to **firing-lane cover**: query-only
foam volumes intercept toy projectiles, never player/prop movement, camera,
support, weather or environmental cover rays. No slowing/steering penalty.
Communicate “Blocks toy shots. Walk through; shoot to pop.” This is an explicit
design revision, not a claim that a physical wall is safe. No additional bodies
or effect pools. Reserve a warning slot before firing,0.7s preview then at most6s
active; one projectile impact pops the screen. Owner shots also pop it. Compare
nearest radius-aware foam/world/player contacts and include mirrored foam in
reticle targeting, with no change to shared _world_clear behavior.

Pellets/water/foam seeds stop and pop it; water does not leave a strip on that
impact. Outbound frisbee returns/return leg ends. Rocket still warns0.8s at
impact and its later blast is not blocked by foam. Cancel on lost support or
owner death/departure/reset. Test no-jump/no-ammo walk-through on narrow routes,
interception ordering/edges/initial overlap, lifecycle, latency and budgets.
Batch4 now implements this query-only contract. Fan has one placement,0.8s
arming/4s active,3.5m narrow cone and2m/s bounded impulses on0.8s pulse boundaries,
with solid cover and shared recovery protection. Decoy is a harmless labelled
mechanical runner,6s/2m/s on supported ground; it cannot collide with players,
impersonate disaster warnings or leap a gap during a delayed frame.

Authority144/presentation15/audio11 and real2/4both-map twelve-toy matrix pass,
including observer replication and5rematches. Twelve actual-public-use captures
at720p/1080p inspected after raising/enlarging labels and coral fan arming cue.
The existing world props/paving remain outside this presentation change.
Maximum-slot mixed foam/fan/decoy trial passes+43draws,+0.408ms authority,
≤+0.317ms paired apply,+17.50%IPv4; details in phase-20-batch4-metrics.json.
Normal staged gate remains pending. No native GPU/audio/human acceptance inferred.

Review also reproduced a permanent intent lock:70valid local requests during
knockdown are correctly rejected by server eligibility, but advance the local
counter beyond the old arbitrary64-gap ceiling. Remove that ceiling, preserving
authenticated per-player monotonic sequence and round rejection. Same scratch
before/after changes held=false to held=true on sequence71; durable public-use
regression and real-client reliable same-channel barrier prove post-recovery
pickup works. This does not authorize another peer's stream or bypass cooldowns.

### Batch5 preparation — Reject persistent crate relocation, keep reversible toys

Focused Oracle safety consultation rejects the proposed magnet for this phase.
This is the checklist's explicit unsafe-design deferral, not an implemented toy.
A local3m clear patch can establish an immediate walk-around route for a0.6m
crate and0.56m capsule, but does not bound the crate's stopping pose or later
route changes. Existing Tornado/Earthquake forces, collapse and sequential crate
relocations invalidate a one-second attraction validator after it ends. Player
movement has no generic crate-push escape helper. No teleportation/collision-off
fallback or general navigation system is authorized to hide that problem.
Keep magnet and rigid-crate spring/rocket combo ideas deferred until a bounded
persistent-placement escape contract exists. Do not claim an executed magnet bug;
the failure here is inability to establish its required invariant before coding.

After batch4's staged gate and push, batch5 remains remote popper and reflector.
Popper:1charge,0.7s arming,8s supported lifetime,second click starts1s existing
2.4m covered blast warning without spending again or adding a reservation. Shots
defuse it; death/departure/lost support/reset cancel. Swapping stays allowed:
without its matching held controller the charge simply expires harmlessly.
Umbrella:1charge,0.25s visible preparation then0.9s directional window; flank/wait,
no melee/blast immunity. Server mutates the same projectile ID, direction and
owner credit; new reflected-kind tags encode at most one bounce in the existing
fixed-width wire. Only linear pellet/rocket/water/foam reflect; fixed-return
frisbees are absorbed, not retargeted. If recipient's2projectile quota is full,
absorb rather than exceed it. World/foam/umbrella/player sweeps select nearest
contact, not remote-reported hits; original lifetimes and rocket warning stay.
These are implementation contracts, not tested claims or permission to skip gates.

### Batch5 implementation and executed checks

Batch4's normal staged gate passed63Godot suites/8network matrices/managed20/
46Python; source226901b committed/pushed with skip-ci, not deployed. This
supersedes its earlier pending gate entry above.

Remote/umbrella contracts above now implemented. Controller remains meaningful
at0ammo; expiry/defuse/support loss clear its feedback without discarding a fresh
replacement's charge. Defuse returns a detonating charge to harmless armed/expired
state; its cosmetic feedback uses the capped outcome pool, not an extra outcome.
One umbrella window per owner prevents rapid pickups forming a shield circle.
Reflection reuses ID/lifetime/reservation, transfers credit and uses fixed-width
kind tags; max1 bounce or full recipient quota absorbs instead. No crate forces,
melee immunity, physics bodies, weather shelter or movement obstruction added.

Authority205/presentation15/audio11 pass. Real2/4both-map fourteen-toy catalog,
replicated remote countdown, reflected-owner state and credited return impulse,
5rematches and departure cleanup pass. Same four cases pass100ms each-way,
0..12ms jitter and1/97loss,61/202/57/188datagrams dropped. Short-window scenario
holds fixture physics time while real intents/snapshots cross ENet; this proves
protocol/credit, not native latency feel or general timing equivalence.

Twelve public-use720p/1080p renders inspected, including opponent-facing canopy.
Initial cyan canopy blended with avatar; use coral opening/violet active and
explicit HUD phase/controller feedback. Retain visible popper while countdown
ring is active so the defuse target does not disappear. HUD stays within margins.
Stable max-slot active-window trial passes+43draws,+0.257ms authority,
≤+0.292ms paired apply,+17.674%IPv4; phase-20-batch5-metrics.json. Preliminary
load used umbrella preparation; final active-window measurements supersede it.
Normal staged gate pending; no native/human acceptance or release claimed.
