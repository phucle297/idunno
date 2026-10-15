# Phase 12 — Random In-Match Movement Power-Ups

Status: implementation active after owner continuation2026-10-15; not deployed.
Number12 preserves the existing roadmap numbering without renumbering9–11.

## Outcome / boundaries

Random visible pickups give temporary running/jumping advantages during a match.
This explicitly extends the former cosmetic-only scope, not the persistent cosmetic
loot boxes/rewards in Phase6. No paid items, inventory, equipment advantage, permanent
stats, classes, currency, held objects or new grab action. Cosmetics remain equal.
Use existing player tuning, authority, match clock and replication owners; no new
backend/profile schema. Supports solo and2–20 players on Town/Harbor.

## Provisional rules to validate, not promised balance

- First implementation contains only **Speed** (+20% walk/sprint for12s) and
  **Jump** (+20% jump height for10s). With current tuning this means walk5.4m/s,
  sprint7.8m/s, jump height1.62m. Derive launch velocity from height/gravity rather
  than increasing velocity20% (which would increase height44%). Values centralized.
- One active power-up per player: same type refreshes to its original duration,
  never adds duration or strength; another type replaces it. No multiplicative stacks.
- Effect starts on authoritative collection; expires on match time, death, round
  end, disconnect/map switch. Rematch restores base stats with no residual timer.
- Speed affects intended locomotion only, not tornado/shove impulses, gravity,
  knockdown recovery, capsule/hitbox or emote priorities. Jump modifies a new launch,
  not an already airborne character's velocity. Ordinary map routes remain usable
  without any pickup; no immunity or mandatory powered jump to reach a refuge.
- Initial spawn proposal: seeded eligible-anchor selection every30s after first30s,
  at most6 live pickups across either map,60s expiry. No player-count or shrinking-
  area multiplication. Decline when no valid anchor; do not silently spawn on a player.
- Place on reachable real support, away from spawn capsules, doorways/ramp landings,
  reserved exits and current lethal Fire/Flood/meteor/fracture exposure. Revalidate
  terrain/zone state when spawning; an existing pickup does not turn hazards safe.
  If terrain disappears or the support becomes submerged, despawn it. No rigidbody
  simulation; bounded pickup visuals/Area3D and server queries, not networked debris.
- Server collects only for living ACTIVE players within a proposed1.1m radius and
  line of sight; choose closest then stable peer-ID tie-break when claims occur on
  the same tick. Consume atomically once. Clients cannot set type/strength/expiry or
  manufacture IDs; stale round/duplicate packets never create another effect.
- Replicate pickup ID/type/position and active buff ID/type/expiry/round sequence.
  Integrate movement prediction/reconciliation so local boost matches authority;
  observers animate the effective speed. Use current transport limits/fallbacks.

## 12.1 — Authoritative seeded drops and atomic collection

Owners: `game/main.gd`, map anchors, match manager and network snapshots.

- [x] Eligible support/route/hazard/zone checks, seeded selection and spawn/expiry cap.
- [x] Actual authoritative proximity/line-of-sight collection and concurrent claim
  resolution. No benefits in LOBBY, RESULTS, spectator or eliminated states.
- [x] Round-qualified replication, late join/reconnect and all cleanup transitions.

Gate: same-seed replay; invalid/occupied/wet/destroyed/zone-excluded anchors decline;
duplicate/stale/fabricated claims rejected; simultaneous2-client collection grants
exactly one effect; one-player behavior works without enabling competitive respawn.

## 12.2 — Temporary effective movement tuning

Owners: `game/player/player_tuning.gd`, `player.gd`, input prediction/authority.

- [x] Effective walk/sprint/jump derived from base tuning plus one buff, with capped
  refresh/replace/expiry and no change to cosmetics, impulse or collision contracts.
- [x] Predicted/authoritative speed convergence, phase-preserving visual playback.

Gate: measure grounded distance and actual jump apex before/during/after each buff;
unbuffed controls unchanged. Test expiry while airborne/sprinting, ragdoll/death,
disconnect, map switch and5 rematches. Powered movement cannot bypass boundaries,
tunnel through new rail/shrub collision or break ordinary route/shelter fairness.

## 12.3 — Readable pickup / buff feedback

Owners: project-authored assets/manifest and current HUD/audio/settings.

- [x] Distinct icon + name, collection feedback and remaining-time indicator; no
  color-only identification, control grab prompt or full-screen hazard obstruction.
- [x] Reduced-motion behavior, warning audio priority and bounded visual counts.

Gate: real720p/1080p gameplay renders of Speed/Jump/refresh/replace/expiry and
overlapping hazard advice; inspect visuals and input, not just node structure.
Load asset-validation skill before creating pickup visuals and record provenance.

## 12.4 — Integration / package gates

- [ ] Both maps actual2/4/8/20 peers, simultaneous claims, late snapshots,5 rematches,
  crash retry/owner departure; cosmetics/profile/rewards remain unchanged.
- [ ] Hazard/boundary/route regression, CPU/snapshot/body/effect/memory measurements.
- [ ] Matching client/server exports and standalone lifecycle; source delivery separate
  from public deploy/release. No unexecuted GPU/human difficulty approval inferred.

Evidence so far:105 movement/authority assertions,111 presentation assertions and24
inspected captures; eight real ENet cases across both maps2/4/8/20 players with five
rematches.83 room-UI and82 powered-collision checks pass. Scratch negative cases
cover occupied/meteor/invalid support/skip backlog/expiry/cap/knockdown/boundary.
Forced20buffs+6drops p95 tick219us Town/197us Harbor; serialized snapshots4324/4148B
use the existing oversized-packet fallback. Eight warmed rematches per map retain
zero node/orphan growth;204 mesh triangles/token, no pickup bodies. Full regression,
managed crash-retry/owner departure and committed-HEAD packages remain pending.

Human feel/balance and native GPU acceptance remain unverified under the existing
waiver; do not add mandatory human checklists or treat proposed defaults as tested.
