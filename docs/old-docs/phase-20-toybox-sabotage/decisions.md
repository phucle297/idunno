# Phase20 decisions — completed historical log

Earlier pending/delivery statements are chronological. Final matching release
verification at the end supersedes them; native/human/thermal limits remain open.

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

[Phase19 evidence](../phase-19-multiplayer-frame-budget/final-controls.json)
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

[First-slice measurements](phase-20-first-slice-metrics.json) preserve
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

### Batch6 preparation — Reversible cart and delayed balloon lift

Implementation waits for batch5's normal staged gate and push. These are next
contracts, not executed results or a reason to release the partial arsenal.

Revise rocket cart from physical obstruction to a **non-solid toy bumper**.
Persistent movement barriers share the rejected foam/magnet escape problem.
One charge places on supported ground;1s visible fixed-lane engine windup then
at most2s at4m/s. Reserve both projectile and warning capacity before accepting;
moving phase consumes the same projectile slot, no new body or vehicle owner.
Support-constrained steps cap at0.25m to avoid jumping a corridor-sized void on a
delayed frame. Solid walls/crates stop it without moving props. First swept
capsule contact gets at most3m/s horizontal impulse/shared protection and ends
the cart. Players can walk through; foam/umbrella are shot counters, not physical
cart barriers. No owner steering, recursive impacts or shield-like route denial.

Balloon: one slow visible dart, capped projectile and reserved warning slot.
A hit starts0.6s attaching/inflating warning; no immediate forced motion. Jump,
move1m from the attachment origin, shoot/pop it, or use solid cover before hit.
Jump/meaningful vertical separation or a new protected/knocked-down state cancels
pending lift. Lift requires actual grounded capsule contact at trigger time and
clear overhead; set3m/s upward once through the existing reliable item impulse,
not continuous per-frame velocity overrides or a new movement-prediction state.
Current gravity20m/s² gives a nominal0.225m rise, below the3m fall-safe threshold;
this arithmetic is a tuning bound, not an executed capsule/ceiling result.
Short cosmetic float/fade afterwards, no indefinite suspension or extra force.
Only one pending balloon per victim; cross-item1.5s protection prevents chains.
Target identity/original anchor stay in bounded server-only metadata; snapshots
carry the authoritative balloon position in existing37byte effect records.
Reset/death/departure/pop/expiry remove metadata. Umbrella absorbs balloon darts
instead of adding another reflection family; no new bounce/pool/audio voices.

Require public pickup/use, physical floor/ceiling/escape/apex checks, both-map
real-client lift acceptance, rematches/delayed peers, inspected720p/1080p cues and
matched incremental budgets before accepting either item. Do not infer native
feel from arithmetic, a frozen fixture, loopback or llvmpipe throughput.

### Batch6 executed validation

Batch5 normal staged gate completed and sourcecd681508 committed/pushed with
skip-ci; it is not deployed. This supersedes the pending batch5 gate above.
Cart/balloon now implement the preparation contract. Public-intent authority283,
presentation15/audio11 pass. Capsule walk/jump escape,low-ceiling rejection,
ordinary-shot pop,departure/duplicate/lifetime controls and mild physical apex/
same-floor return pass. Cart warning/reservation,first bounded bumper hit,wall
and destroyed-floor cancellation pass. Delayed4s dart originally attached a9m
target past its7.5m lifetime; same regression passes after bounding shared linear
projectile travel to its remaining lifetime,not adding a balloon-only exception.

Real2/4both-map16toy catalog,cart windup/running snapshots and reliably accepted
3m/s balloon lifts pass with5rematches. Same four cases pass100ms each-way,
0..12ms jitter and1/97loss,70/63/233/215datagrams dropped. Short state barriers
hold authority physics while real packets travel; not latency-feel proof.
Ten public-use720p/1080p frames inspected. Refined compact airborne seed so its
ribbon cannot extend below floor,and mark full8m maximum cart lane. Attached
balloon retains long string and explicit jump/move/pop counter;float cyan.
Stable max-slot trial:+42draws,+0.433ms authority,≤+0.364ms paired apply,
+15.872%IPv4,zero kernel drops/fragments;phase-20-batch6-metrics.json.
Normal staged gate pending; native/human acceptance and release remain pending.

### M20.3 contract — Wash, drift and reduced-area admission

Batch6 normal staged gate passed63Godot/8matrices/managed20/46Python;
sourcef92fc78 committed/pushed skip-ci. Public remains Phase18.
Implement only water-strip overlap clearing same-height uncovered soap;
active exposed Rain adds2s/s soap lifetime erosion (natural expiry still runs).
Use the real roof ray,not precipitation at an unrelated outdoor location. Neither
interaction changes retained weather,snow,electricity,HP or impulse credit.

Fan pulses may rotate unreflected pellet/water/foam/balloon dart direction at most
0.2rad toward their fixed forward lane. Same3.5m cone,vertical reach and solid
cover apply; preserve original owner,speed,lifetime,ID and reservation. At most
one fan deflection per projectile per simulation tick,even with overlapping fans.
No rocket/cart/frisbee/reflect-chain steering,new effects or recursive propagation.
Do not run covered-player gust rays during shared recovery protection.

Audit reduced-area density here as part of bounded-chain safety: derive admission
limits from actual remaining meteor usable area including pending collapse.
Floor the intact4projectile/6warning/6pickup ceilings by that area fraction,minimum
one for nonzero support. Remove only surplus pickups; existing warned effects
retain their published deadline and expire naturally within10s. Never silently
erase a warning or reject a remote detonation of an already reserved popper.

Keep magnet/rigid-crate spring/rocket outcomes deferred for persistent-route
safety. Do not electrify toy wet strips: authored-puddle-only Lightning warning
and volume cannot authorize a larger connected damage surface. Snow cannot
cover the separate toy warning meshes with the world surface overlay. These are
explicit reviewed exclusions,not implemented combos or human balance acceptance.

M20.3 hazard audit reproduced two missing cleanup contracts: a wet strip survived
actual floor removal, and a submerged confetti warning/placement remained active.
All supported floor effects now reject submerged placement/creation and cancel
before actions when Flood covers their support. Rocket impact warnings also cancel
when submerged, rather than hiding a delayed blast below the water. Dry elevated
toys remain ordinary actions; this is not global weapon immunity during Flood.
Use a narrow Flood visibility callback, not the broad pickup-anchor validator:
the latter also bans current hazard areas/refuge routes and would erase valid
existing toys merely because a new weather warning appeared nearby.
Wet strips join the actual floor-support check, without entering retained weather.
Umbrella absorption of balloon darts now emits ordinary BLOCKED feedback instead
of silently removing the shot; it still never creates a reflected balloon.

The first M20.3 staged gate found a pre-existing pickup competition fixture race
at Harbor20. A rejected pickup legitimately stores an empty-kind,zero-ammo slot
with range feedback. Dictionary presence was incorrectly treated as ownership;
whether the losing request arrived before the assertion determined the result.
An ordered production-request barrier reproduced this at2peers:one foam holder
plus one feedback record. Count actual held kinds,accept empty feedback records,
and wait for both intents before observing the winner. No gameplay contract or
network timeout was weakened. Focused Harbor2/20 now pass; the normal full gate
must pass again before committing. Failure logs remain in .scratch/phase20-chain-commit-gate.log
and .scratch/phase20-competition-barrier-before.log.

Follow-up gate passed63Godot suites/8network matrices/managed20/settings restart/
46Python on staged tree abf4fecc8c974c22fbb46813efcd3d3fff9a2ddc;
M20.3 committed/pushed as e096672 with skip-ci. This supersedes pending gate
statements above/in provenance without modifying validated asset content.
Final rotating fan/shot,popper expiry and Rain soap-wash stress remains within
incremental trial ceilings:44draws,0.402046ms authority,at most0.391316ms paired
snapshot apply,19.427323%IPv4. Preserve unpaired client1 variance0.533080ms and
software rendering far below60FPS; neither is silently replaced by a native
performance claim. Local committed Windows/Linux154-entry exports and standalone
Linux lifecycle/profile controls pass. Final CI exact-PCK/public smoke and release
re-download remain delivery gates; no infrastructure or profile-store change.

## 2026-10-21 — Matching public delivery verified

Release4279650 deployed through successful workflow39626771256 and published as
[Toybox Chaos](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-21-4279650).
Exact CI-PCK authority345/weather96/audio11 and all six720p/1080p soap/water/Snow
captures pass; warning outlines and HUD inspected. Standalone exported Linux
allocator/lifecycle/profile restart checks pass. Public two-client equipment,
Ready/Start,mutual movement and disconnect pass with the same deployed PCK.
Windows ZIP uses that byte-exact CI PCK;Linux archive unchanged from CI.
Published assets re-downloaded:bytes/hashes/tag match. No public profile-store
or infrastructure/capacity changes. Full [delivery evidence](progress.json#delivery_followup).
Minor lower-right dry pavement seam artifacts were observed,not diagnosed;
they are not silently marked fixed by this toy release. Native Windows/GPU/heat,
physical audio,human fun and separate-network acceptance remain unverified.
