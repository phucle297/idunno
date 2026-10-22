# Phase21 proposal — Social chaos, not a larger weapon catalogue

Status: planning only; owner accepts the bomb direction and requires a hidden
random fuse, including immediate detonation after receipt with no grace. Other
mechanics and the added UI/UX candidates await selection. No implementation,
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
| Hot Potato | Distinct social chase; environment reviewer ranks second | Loop reviewer: grief/visibility; player reviewer suggests per-pass consent | Owner supersedes visible fuse/final window: hidden random fuse, immediate receipt detonation accepted; prototype before commitment |
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

**Moment:** one player picks up a wind-up parcel and chases a rival. A visible lob
passes it; the recipient may pass it onward or it may burst immediately. Nobody
can read an exact remaining fuse and deliberately dump it at a known final second.

This is an **optional lobby-selected variant**, announced before Ready/Start,
not an unannounced hazard in default survival. All participants opt into the rules
before starting; no per-pass modal confirmation. One parcel globally; the server
privately samples a random fuse once on creation. Trial range 5–15 s is a tuning
hypothesis, not approved balance or a recipient safety window. No timer reset,
reroll or extension on transfer. Solo disables it.

Owner decision: no recipient grace, minimum possession time or final transfer
embargo. Receipt followed immediately by detonation is an accepted random outcome,
not a bug to fix. The prior visible 12 s fuse and 2.5 s cutoff are superseded.
Hidden timing prevents exact-deadline dumping, not all possible toxic behavior;
target harassment or inference from elapsed age still needs ordinary playtesting.

- Transfer: prototype a short, visible, dodgeable lob at up to 3 m, validated
  server-side with LOS/sweep and alive-target checks. No instant remote assignment,
  through-wall pass or client-selected victim. Reuse analytical sweep principles,
  not a new networked rigidbody. Failure leaves ownership with the carrier.
- Privacy: deadline, duration, remaining time and RNG state/seed stay server-only;
  do not include them in replicated state, client debug overlays or client logs.
  Do not derive the fuse from a public map seed. No countdown, age-progress bar,
  accelerating tick/flash or other presentation that encodes remaining fuse.
- Keep the carrier and a constant danger footprint visible, with a steady cue
  identifying the parcel rather than its age. Reject duplicate/rate-spam intents;
  there is one owner and no same-tick multi-hop transfer. Do not add a time gate
  that promises a newly receiving player immunity from detonation.
- Expiry: one bounded burst through the existing impulse/protection rules,
  no direct HP damage or forced ragdoll. Keep environmental damage and death credit
  truthful. Do not claim the burst cannot cause a fall or void elimination.
- Counter: dodge/cover the lob, open distance, bait a return, then leave the visible
  carrier footprint. There is deliberately no guaranteed reaction time after
  receipt. Test ordinary lob evasion separately from this accepted random risk.
- Resolve expiry and an arriving transfer in one deterministic server event order;
  clients cannot backdate a pass. Test both immediate-receipt detonation and expiry
  before a pass, with one burst/owner/outcome and no deferred safety grace.
- No arbitrary discard into a void. If the carrier dies/disconnects, release only
  onto validated supported ground with the original fuse; otherwise visibly cancel
  the event. Clear at match end; do not spawn a replacement to change the winner.
- Admission: defer new events when too little safe supported area remains, at an
  unsafe collapse/Flood transition or when no validated placement exists. Existing
  fuse deadlines never silently shrink. A safety cancellation is globally signaled.
- Modules: bounded parcel controller + presenter, lobby ruleset selection/validation,
  session epoch/snapshot integration, existing `ShoveManager` impulse path. Separate
  global parcel ownership from the existing personal toy slot; do not add inventory.
- Stop/rework if ordinary lob dodging is impossible at controlled latency, carrier
  identity is lost
  in 20-player crowds, all players camp until deadline, or the mode is merely a
  confetti bomb with a different skin. Compare 2-player chase with 20-player behavior.

## Additional UI/UX and existing-game improvements — proposed, not selected

Source review: `pause_settings.gd` already exposes audio buses, camera settings,
resolution, fullscreen and reduced motion. `toy_sabotage_card.gd::present` already
shows ammo/cooldown/basic feedback and a reticle. Results/spectator and room retry
already exist. Improve those contracts rather than presenting them as missing.
No new visual design or rendered verification was performed for these proposals.

| ID / idea | User-visible change and actual gap | Likely modules / acceptance |
| --- | --- | --- |
| U1 — Performance controls | Low/Balanced/High local detail/shadow presets, 30/60/120 FPS cap, a separate unfocused/minimized cap, optional small frame-time/ping panel. Current display options are not quality/FPS controls. | `pause_settings.gd`, existing local detail/shadow setup; never remove collision, authoritative hazards or readable warnings. Save/restart test, compare same-scene solo/two-client focus states and show CPU/GPU/frame evidence where measurable. Native heat/FPS remains unresolved. |
| U2 — Toy clarity and request acknowledgement | On a new toy, show one short purpose/counter hint; distinguish request pending, server accepted and rejected. Keep existing ammo/cooldown feedback, avoid repeated tutorial popups. | `toy_sabotage_card.gd`, Main input/snapshot acknowledgement; persistent action IDs only if needed. Slow/lost/reordered response tests: no false hit, double-use, stuck pending or obscured warning. Hint suppression while in personal danger. |
| U3 — Consistent warning/audio priority | Align the HUD's selected urgent danger with audio; briefly duck music/effects for a critical cue. Add optional concise warning captions, never an omniscient through-wall radar. | `gameplay_hud.gd`, `gameplay_audio_controller.gd`, music/bus integration. Current HUD prioritizes nearest warning, audio independently plays entering disaster warnings. Verify overlap ordering, voice limits, user volumes/reduced motion and no lost critical cue. Do not expose hidden parcel time through sound or captions. |
| U4 — Explain a death, not just name it | Short factual receipt such as "player shove → fall → impact damage", with the final cause and credited source only where supported by server evidence. Current elimination text has cause/time, not a causally supported chain. | Match/session bounded event history, existing shove/toy credit and results/HUD. No video replay or full position recording. Test stale/overwritten credit, self-fall, simultaneous events, assist vs kill and rematch clearing. Unknown attribution must stay unknown. |
| U5 — Controls and accessibility | Rebind actions with conflict detection, dynamic prompt labels, larger text options and shape/contrast alternatives to color-only cues. Existing reduced motion and focus navigation remain. | Input actions, `pause_settings.gd`, HUD/toy/mechanism prompt sites. Rebind/save/restart/reset controls; typing in menus must not fire actions. Check 720p/1080p layout, warning visibility and no cosmetic setting changing gameplay rules. Scope text scale vs full localization separately. |
| U6 — Room status and safer retry | Show connecting/admitting/failed states, preserve non-secret room context on failure, copy room code and offer a clear retry/back action. Existing disconnect handling clears room ID and asks users to create/join again. | Main room lifecycle and existing room UI/tests. Do not silently auto-rejoin an ACTIVE round or reuse stale credentials/peer IDs; only retry existing allowed admission, with current readiness/security checks. Test timeout, deleted room, restart, rapid clicks and cancellation. |
| U7 — Vietnamese/English interface | Translate visible action/settings/error/toy instructions consistently and remember language. Existing inspected settings/toy/results strings are inline English; this needs a string inventory, not only translated button labels. | Existing UI text sites and translation resources; audit scope before changing schema. Check fallback/missing keys, long Vietnamese text, fonts/diacritics, rebinding placeholders and room error coverage. Never translate wire IDs, save keys or server authority identifiers. |

Proposed priority for existing-game value: U1 + U2 first, then U3 + U4, then
U5/U6/U7 as separately selectable units. Do not expand all seven into mandatory
Phase21 milestones or silently reopen earlier rejected UI/director proposals.

Each selected UI unit gets its own contract, focused tests and rendered inspection
of default/error/pending/long-text states where relevant. No visual mockup is an
implementation or proof. Gameplay A/C remain candidates, not prerequisites for UX.

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
| M21.0 — Baseline and selected contract | Existing performance/network tools; choose A/B/C and/or UI units and explicit input/rules | Reproduce Phase20 control scene in orb; record solo/two-client active vs unfocused/minimized behavior where supported, CPU/frame/draw/IPv4 metrics; no native-resolution claim. Agree caps and record hypothesis. |
| M21.1 — First playable A | Shove/player/stance/snapshot | Front/side/rear, expiry and cooldown boundaries; fake/stale/duplicate intents; toy/disaster controls unchanged; rendered ready/block/expired/crowd states. Reject camping-dominant contract before expanding it. |
| M21.2 — Optional B experiment | Parcel controller, presenter, lobby/session | Hidden random server-only fuse, immediate-receipt detonation accepted, deterministic transfer/expiry ordering, one owner/burst, no timer disclosure or slot conflict; departure/tiny area/Flood/collapse controls. Mode explicit before Start; default unchanged. |
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
