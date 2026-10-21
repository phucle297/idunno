# Phase21 proposal — Social chaos, not a larger weapon catalogue

Status: planning only, awaiting owner selection. No gameplay implementation,
prototype, balance test, new release or deployment is authorized by this plan.
Phase20 remains the published build. DESIGN.md remains authoritative.

## Outcome and constraints

Create decisions between people: bluff, chase, temporary cooperation and betrayal,
while disasters remain the reason positioning matters. Start with one mechanic,
not all three at once. All numbers below are trial hypotheses, not measured feel.
Default competitive survival still has no respawns and ends by its existing rules.
No new economy, classes, inventory, accounts, director redesign or loose bodies.
Preserve existing anti-chain-lock, real collision, roof correctness, ordinary
escape routes and collapse safety. Bounded knockback can still cause environmental
death; "no direct HP damage" must never be presented as "cannot kill near a void".

## Evidence and two-round agent discussion

Three research agents inspected player interactions, environment/hazards and the
match loop independently; three follow-up assignments cross-reviewed their ideas.
These were source audits, not new runtime verification or human fun acceptance.

- `game/session/toy_sabotage.gd`: 16 existing toys, analytical projectiles,
  placement/impulse caps and bounded snapshots. More guns alone add little novelty.
- `game/player/shove_manager.gd`: `request_shove`,
  `apply_replicated_shove`, `apply_replicated_item_impulse`, shared recovery
  protection and monotonically sequenced application already exist; brace does not.
- `game/world/town_mechanisms.gd`: awning/bridge are single-operator mechanisms;
  `create_snapshot` explicitly serializes two IDs. A third mechanism or two-player
  activation is a real schema/validation change, not just a new mesh.
- `game/disasters/meteor_shower.gd::_is_sheltered` uses a real upward physics ray.
  `game/disasters/tornado.gd::is_position_covered` uses authored cover volumes.
  A new canopy must reconcile both, not grant cosmetic shelter.
- `game/disasters/weather_surfaces.gd::is_exposed/invalidate_cover` and
  `game/main.gd::_activate_mechanism` already handle changing awning exposure.
- `game/main.gd::_meteor_routes_clear` reserves exits/route landings;
  `TerrainCollapse.supports_point/supports_path` supplies support checks.

Disagreement retained rather than called consensus:

| Candidate | Support | Objection | Parent synthesis |
| --- | --- | --- | --- |
| Brace / Bluff | Player and environment reviewers: bounded extension | Loop reviewer: passive play, weak crowd readability | First low-cost prototype; direct shove only |
| Hot Potato | Distinct social chase; environment reviewer ranks second | Loop reviewer: grief/visibility; player reviewer suggests per-pass consent | Optional pre-selected variant, dodgeable transfer, strict final window; prototype before commitment |
| Buddy Bunker | Player reviewer prefers temporary truce; loop reviewer sees value | Environment reviewer: repeats awning and adds dynamic-cover complexity | Conditional third candidate with shelter feasibility gate |
| Seesaw | Loop reviewer prefers shared environmental action | Other reviewers: spring-pad duplication, launch/landing burden | Defer; do not add another launcher now |
| Last-Second Catch | Strong rescue story | Latency, fall attribution and void/hazard rescue boundaries | Defer; no revival or midair safety override |
| Route ping / rematch ballot | Small coordination conveniences | Weak creative gameplay value; no reported need | Not Phase21 priorities |

Parent rejects a universal brace that affects disasters and a canopy without a real
roof. Native heat/FPS uncertainty is not a mandatory new owner-testing prerequisite
under the existing waiver, but also is not a resolved performance claim.

## Candidate A — Brace / Bluff: bait the shove

**15 seconds:** a rival approaches a rooftop edge; you visibly brace, they waste
a shove, then circle to your side while you decide whether to retreat or attack.

Trial: a grounded, living player deliberately enters a visible 0.6 s front guard
(about 100 degrees total), sacrifices sprint and cannot shove/use toys during it.
It consumes one direct player shove from the front; blocked attackers spend their
normal shove cooldown. Expiry also spends the proposed 3 s brace cooldown. First
slice has no automatic counter-hit, reflection or extra recovery immunity.

- Counter: flank, wait out the window, bait it, or use an existing toy. It does not
  stop projectiles, fan, springs, fall damage, props, Flood, Tornado or knockdown.
- Authority: server derives facing/contact and eligibility; snapshot carries a
  bounded stance/expiry/consumption state. Never trust a client "I blocked" claim.
- Feedback: readable pose/front silhouette, short BLOCK sound/text on acceptance;
  immediate cosmetic anticipation must not imply a rejected action succeeded.
- Reset: cancel on airborne transition, knockdown, death, disconnect and rematch;
  delayed intent/outcome packets must not recreate a prior-round stance.
- Modules: `ShoveManager` acceptance, `PartyPlayer` input/state, character stance
  presenter and existing session snapshots. Audit all snapshot fixtures first.
- Stop/rework if it becomes repeatable rooftop camping, requires freezing normal
  camera control, masks all toy counters or cannot be read in a 20-player crowd.

## Candidate B — Hot Potato: visible wind-up parcel chase

**15 seconds:** one player deliberately picks up a ticking parcel, chases a rival,
passes it with a visible lob; the rival dodges toward a ramp and returns it before
the final transfer window closes. Everyone then scatters from the carrier.

This is an **optional lobby-selected variant**, announced before Ready/Start,
not an unannounced hazard in default survival. All participants opt into the rules
before starting; no per-pass modal confirmation. One parcel globally, fixed trial
12 s server fuse, no timer reset or extension on transfer. Solo disables it.

- Transfer: prototype a short, visible, dodgeable lob at up to 3 m, validated
  server-side with LOS/sweep and alive-target checks. No instant remote assignment,
  through-wall pass or client-selected victim. Reuse analytical sweep principles,
  not a new networked rigidbody. Failure leaves ownership with the carrier.
- A transfer must complete with at least 2.5 s remaining. From that point onward,
  no new transfer starts/completes. Keep the carrier for the final warning; do not
  fizzle merely because nobody is in range (that would reward avoidance exploits).
  Trial 1 s transfer cooldown prevents same-frame ping-pong and simultaneous owners.
- Expiry: one warned, bounded burst through the existing impulse/protection rules,
  no direct HP damage or forced ragdoll. Keep environmental damage and death credit
  truthful. Do not claim the burst cannot cause a fall or void elimination.
- Counter: dodge/cover the lob, open distance, bait a return, then leave the visible
  final footprint. Reachability must be tested with the actual capsule and latency.
- No arbitrary discard into a void. If the carrier dies/disconnects, release only
  onto validated supported ground with the original fuse; otherwise visibly cancel
  the event. Clear at match end; do not spawn a replacement to change the winner.
- Admission: defer new events when too little safe supported area remains, at an
  unsafe collapse/Flood transition or when no validated placement exists. Existing
  fuse deadlines never silently shrink. A safety cancellation is globally signaled.
- Modules: bounded parcel controller + presenter, lobby ruleset selection/validation,
  session epoch/snapshot integration, existing `ShoveManager` impulse path. Separate
  global parcel ownership from the existing personal toy slot; do not add inventory.
- Stop/rework if dodging is impossible at controlled latency, carrier/fuse is lost
  in 20-player crowds, all players camp until deadline, or the mode is merely a
  confetti bomb with a different skin. Compare 2-player chase with 20-player behavior.

## Candidate C — Buddy Bunker: two rivals need one another

**15 seconds:** two rivals hold separate pins as Meteor approaches; a short-lived
canopy opens for everyone. They temporarily share shelter, but Flood pressure makes
one leave early for a roof while the other chooses when to follow.

Trial: one authored Toy Town site, two distinct living grounded players holding
separate pins for 0.75 s, 7 s active canopy, then at least 25 s cooldown. Releasing
before deployment cancels activation; leaving afterward does not instantly remove
other players' shelter. No ownership/team lock, doors, floor lift or enclosing walls.

- Real visible roof/collider must match Meteor cover and Rain/Snow exposure. It
  should reduce Tornado pull using explicit cover state, not grant immunity. Do not
  invent a special "rain passes through this roof" exception to Phase17's contract.
- No new protection against Flood, Fire, Lightning, fall or collapse. Remove cover
  on expiry/support loss; invalidate weather cover on both activation and removal.
- No canopy collision may intersect an occupied capsule or its required clearance.
  It is not a new walkable roof or obligatory refuge; all ordinary routes remain
  usable during inactive, deploying, active, expiring and lost-support states.
- Counter: use ordinary shelter, leave before expiry, pressure the pin approach,
  or trade the temporary low shelter for a higher but exposed route. Cancelled
  activation never consumes another player's movement or traps them at a pin.
- Modules: `TownMechanisms` activation/snapshot validation, main integration,
  Meteor collision, Tornado dynamic-cover seam, weather invalidation, one map anchor.
- Feasibility gate first: compare against existing awning with the same hazard
  sequence. Drop if it produces no new two-person choice or needs broad shelter
  rewrites. Other kill criteria: permanent cover chaining, solo deadlock, primary
  route obstruction, invisible shelter after expiry or crowd readability failure.
- Solo retains the existing game; bunker is unavailable, never an escape requirement.

## Proposed phase hierarchy and validation (all not run)

Order is risk-first, not a commitment to ship all candidates. No calendar estimate
until the first prototype reveals actual input/network and presentation cost.

| Milestone | Deliverable / owner modules | Exit gate |
| --- | --- | --- |
| M21.0 — Baseline and selected contract | Existing performance/network tools; choose A/B/C and explicit input/rules | Reproduce Phase20 control scene in orb; record solo/two-client active vs unfocused/minimized behavior where supported, CPU/frame/draw/IPv4 metrics; no native-resolution claim. Agree caps and record hypothesis. |
| M21.1 — First playable A | Shove/player/stance/snapshot | Front/side/rear, expiry and cooldown boundaries; fake/stale/duplicate intents; toy/disaster controls unchanged; rendered ready/block/expired/crowd states. Reject camping-dominant contract before expanding it. |
| M21.2 — Optional B experiment | Parcel controller, presenter, lobby/session | Single owner/fuse, miss/cover/late-transfer, no slot conflict; carrier departure, tiny usable area, Flood/collapse, two-player and crowd controls. Mode explicit before Start; default unchanged. |
| M21.3 — Conditional C feasibility then prototype | Town mechanisms/map/cover/weather | Two distinct actors, pin release, disconnect, activation clearance, expiry/support loss, real roof behavior and ordinary walk-only exits. No broad cover rewrite without a new design decision. |
| M21.4 — Integrated regression and decision | Existing test runners + package workflow | Selected mechanics only; focused authority then real 2/4-client latency/loss, 8/20 stress, five rematches, both-map controls and full normal staged gate. Reject regressions; explicitly choose keep/rework/drop per candidate. |

Cross-cutting checks: dead/ragdolled users, paused lobby/results, epoch rollover,
out-of-order updates, equal-tick contention, support loss, overlapping warning
visibility, reduced motion, and rejection feedback. ACTIVE player admission stays
prohibited; replica snapshot recovery is not permission to join mid-round.

Performance gate: compare to the same Phase20 workload, not solo idle. Preserve
existing total ceilings instead of allocating the entire budget again per feature.
Record authority/apply cost, draw calls, actual IPv4 bytes, effect/voice/body counts
and variance separately. No added loose rigidbodies and no claim of native 60 FPS
from llvmpipe. Instrument/reproduce where tools permit; do not guess a Windows GPU
or create new mandatory human checklists. Existing hardware limits remain open.

Delivery gate is separate: selected feature passes do not mean release/deployment.
Implementation, packaging and a new public release need owner approval of scope;
this planning commit does not change the deployed game. Human fun/comprehension
remains unverified even if all scripted scenarios pass.
