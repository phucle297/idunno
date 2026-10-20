# Phase20 — Toybox sabotage and chain-reaction chaos

Status: M20.1 in progress after the Phase19 automated baseline checkpoint. Owner explicitly wants
more player sabotage, including guns/rockets and many chaotic interactions, and
now authorizes implementation followed by release after integrated checks. This
opens the earlier hammer/wood backlog as a toy arsenal; it does NOT restore
grabbing/crouching. DESIGN stays unchanged. The [Phase19 archive](../old-docs/phase-19-multiplayer-frame-budget/checklist.md)
records measured optimizations, sustained controls and trial ceilings, not native
headroom or resolution of the owner's thermal/FPS symptom. Expanded diagnostics
remain partial; existing hardware acceptance waiver permits bounded continuation.

## Direction and game loop

Keep disaster survival as the win condition. Fight for a route, displace someone,
steal a safe timing window, bounce them into a puddle or turn their trap on them;
not realistic guns/gore or a permanent deathmatch loadout. Cartoon foam, suction
cups, springs and confetti fit the toy-town palette and silhouette.

Proposed first rules (tuning hypotheses, not tested balance):
- One held item slot, finite charges, visible world pickups; choose take/swap/use.
  No buying, rarity grind, cosmetic stat bonus or permanent inventory advantage.
- Start with shove plus pickups, no spawn firing. Brief protected opening and
  respawn/rematch cleanup; no respawns invented for the existing survival mode.
- Server owns pickup competition, aim/rate/ammo eligibility, projectile/trigger
  hits, HP/impulse and effect IDs. Clients may predict presentation, not damage.
- Ordinary weapon hits prioritize push/position. First slice has no direct weapon
  HP damage; environmental/fall damage still applies. Later tiny direct damage is
  an explicit balance decision, not assumed zero total lethality near a void.
- Shared shove/item recovery protection and total impulse caps stop alternating
  attackers bypassing anti-chain-lock. Hard-lock duration and protected get-up are
  bounded; repeated taps must not refresh control loss forever.

## M20.1 — Action framework and complete first vertical slice

- [x] Specify pickup/slot/aim/use/cancel and HUD controls, including gamepad/touch
  only if actually supported; preserve movement, E mechanisms and existing shove.
  Rejected intents explain empty ammo/cooldown/protection/range rather than fake hits.
- [x] First three items: **foam blaster** (3 visible slow pellets; jump/strafe/cover),
  **plunger rocket** (1 slow whistling rocket; impact marker0.8s before one blast,
  no homing/through-wall force; leave marker/solid cover), **squeaky hammer**
  (2 swings,0.35s windup, short forward cone; backstep/side-step/cover).
  Windup/blast numbers are starting trials; measure escape using real capsule speed.
- [x] Add server-validated aim origin/direction, line of sight and swept projectile
  collision; reject forged targets/transforms/ammo, duplicate/stale/rapid RPCs and
  dead/stunned/out-of-range users. No wall penetration or client-reported kills.
- [x] Use existing item/action modules only where contracts fit; proposed separate
  sabotage controller owns slot/use and effects rather than expanding main.gd into
  all weapon behaviors. Reuse powerup placement/eligibility patterns, not its buff
  semantics. Do not revive removed grabbing code as an implicit dependency.
- [ ] Validate real2/4-player pickup races, use/cover/vertical boundary, latency,
  disconnect, late join/state recovery, cross-weapon protection and5 rematches.
  Held visuals must follow existing animation/ragdoll ownership with no hand jitter.

Exit: three distinct working tools, readable miss/block/hit, no repeated control
lock, network regressions absent and measured Phase19 headroom respected.

Evidence so far: focused authority50/presentation15/audio11 and existing powerup105
checks; real2/4-player ENet both maps with5rematches, replicated hammer hit and
delayed old-round rejection. Earlier8/20 correctness predates epoch hardening;
full staged regression will rerun it. F take/swap, pointer
recapture without firing and subsequent captured use exercised through viewport
input. Six rendered held/warning/empty captures at720p/1080p inspected; fixture
camera and foot height corrected, coral warnings/text refined. Controls/cancel
semantics are in [decisions](../decisions.md). No gamepad/touch claim.
[Measured incremental budgets](phase-20-first-slice-metrics.json) include+42draws,
+0.264ms authority physics,≤+0.199ms paired apply and+11.586% actual IPv4.
Maximum16-effect Rain/4client follow-up adds0.184ms authority, at most0.243ms paired
apply and15.784% actual IPv4, within ceilings. Real capsule walking escapes the
blast/windup and strafes pellets; no weapon HP damage. Normal staged-tree regression
is being rerun after fixing synthetic Room UI snapshots to include mandatory toy
wire state (focused85 passes). Controlled latency/loss/native animation feel are not
inferred from localhost correctness or static captures.

## M20.2 — More toys through a few reusable interaction families

Each later batch contains2–3 items, reviewed/profiled before the next; this roster
is a prioritized design proposal, not a promise to ship everything simultaneously.

| Batch | Toy / intent | Warning and counter / constraint |
| --- | --- | --- |
| 2 | Spring boxing glove: charged directional shove | Visible charge, narrow lane; dodge/cover, shared protection |
| 2 | Boomerang frisbee: outward/return path | Bright trail; step aside twice, once-per-leg bounded hit, finite lifetime |
| 2 | Water soaker: push jet and local wet strip | Obvious stream; use cover/walk; finite tank, no self-generated electric damage |
| 3 | Banana peel / soap slick: short traction trap | Large readable patch; walk/jump around; no random full ragdoll lottery |
| 3 | Spring pad: pop self or opponent upward | Marked plate and armed delay; avoid/jump, capped safe launch apex |
| 3 | Wind-up confetti bomb: timed radial shove | Loud countdown + marker; run/cover, bounded blast and no through-wall impulse |
| 4 | Sticky foam launcher: temporary lane obstruction | Expanding preview; break/expire/go around; never seal sole refuge exit |
| 4 | Toy fan: short directional gust | Blade/corridor cue; cross behind/cover, one bounded impulse per pulse |
| 4 | Decoy toy runner: distraction, not fake lethal HUD | Distinct toy silhouette; short life, does not forge global disaster warnings |
| 5 | Magnet gadget: attracts loose props, not players | Visible tether/radius; break LOS, capped speed/mass and no physics pile explosion |
| 5 | Remote popper: one visible placeable charge | Arming delay/beep; destroy/avoid; owner death/disconnect clears it |
| 5 | Reflector umbrella: timed directional projectile deflect | Readable open window; flank/wait, server transfer credit, max1 reflection |
| 6 | Rocket cart: short straight moving obstruction | Engine windup, fixed lane; step aside, swept collision, no new vehicle ownership |
| 6 | Party balloon: attach after visible hit, mild lift | Break LOS before attach; pop/free window, safe lift ceiling, no indefinite suspension |

Exit per batch: unique tactical choice rather than reskinned damage, implemented
counters and measured object/network/render budgets. Defer/remove designs that
cannot preserve escape routes, authority or performance after profiling.

## M20.3 — Controlled chain reactions with the world

- [ ] Author an explicit allowlist: rocket → loose crate impulse; water → small wet
  strip; fan → existing cosmetic confetti/projectile drift if server models it;
  spring pad → crate/player limited launch. Keep effects authoritative when they
  influence hits. No arbitrary global explosion propagation.
- [ ] Propose wet strip + existing warned Lightning puddle only where its connected
  volume and warning support it; never electrify the entire rain-covered town.
  Water may clear soap; rain can wash it over time; snowfall may mark rather than
  invisibly conceal traps. Interactions remain proposals until separately tested.
- [ ] Explicitly audit every batch with Flood, Tornado, collapse/void edges, bridges,
  wet/snow/ice, narrow indoor doors and reduced safe area. Cap chain depth/event
  work; large blasts cannot recursively spawn unbounded blasts or rewrite districts.
- [ ] Example goal: hammer knocks crate onto marked spring pad → crate pops up →
  rocket redirects crate beside an opponent. Each link remains visible, avoidable,
  bounded and attributable; don't simulate cosmetic fragments as gameplay bodies.

Exit: combo table with intended/unintended outcome, surviving escape route, credited
cause and bounded cost. Toy Town and Harbor controls, real clients and rematch reset.

## M20.4 — Chaos density, readability and release readiness

- [ ] Use the measured Phase19 render baseline before increasing density: optimized dry
  Toy Town orb samples show4089–4098 draws/client, down from8618–8627.
  These software-render numbers do not define native capacity. First slice should
  share meshes/materials, bound/expire warnings and avoid individual shadow-casting
  rigidbody confetti. Report incremental render/physics/network cost per active toy
  and combined with weather; retain visible projectiles/counters, not just headless
  pass results. No arsenal batch starts on an assumed final12-projectile budget.
- [ ] Proposed initial caps for M20.1 profiling:1 held item/player,≤2 active
  projectiles/player with≤4 total,≤6 placed/warning effects (reserve rocket warning
  capacity before firing), no new loose rigidbodies,≤3s cosmetic fragments,
  ≤1s ordinary weapon-induced control interruption then≥1.5s cross-item protection.
  These are candidate ceilings, not measured capacity. All dynamic props/traps
  share the existing32-authoritative-loose-body limit; measure rather than add32
  on top. Prefer analytical/swept projectiles, not a rigidbody per pellet.
  Initial incremental ceilings:≤64 draws/client,≤0.5ms mean authority physics and
  snapshot apply,≤25% matched4-peer IPv4 traffic. Measure against archived controls;
  these are acceptance ceilings, not measured toy capacity or native headroom.
- [ ] Register/expire pooled effects, serialize bounded state and clean up ammo,
  ownership, projectiles, reflect credit, traps and action sequences on round reset.
  No stale hit from previous match, invisible persistent trap or disconnect exploit.
- [ ] Stress real2/4 players,8/20 correctness, mixed spam and5 rematches; collect
  frame percentiles, snapshot bytes, event/physics cost and resource trends against
  Phase19. If target fails, reduce presentation/active concurrency before adding
  content; retain gameplay warning clarity. Late-round shrink must reduce density.
- [ ] Inspect world pickups/held/aim/warning/hit/miss/blocked/empty/protected states
  at720p/1080p, color-independent symbols, audio warning priority and reduced motion.
  Human fun/readability and hardware feel remain unverified without actual feedback.
- [ ] Run staged regression, provenance checks for generated assets, matching build
  package checks; release/deployment requires owner authorization at delivery time.

No realistic warfare, gore, permanent progression, PvP grabbing, unlimited stun,
unbounded terrain destruction or new hosting infrastructure. Maximize combinations
and meaningful toys within measured budgets, not maximum simultaneous physics.
