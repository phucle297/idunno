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
