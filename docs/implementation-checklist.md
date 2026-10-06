# Vertical Slice Implementation Checklist

This checklist executes the existing plan in `PROMPT.md` and `DESIGN.md`; it does not replace either document.

## Phase 1 — Core sandbox

- [x] Inspect local tools and select an engine/export pipeline.
- [x] Bootstrap fresh checkouts with a headless editor import so global script classes exist before script-mode validation.
- [x] Launch the selected engine and import one deterministic generated asset.
- [x] Validate the shared palette, base character proxy, wall, prop, and disaster-effect proxy together.
- [x] Implement an authority-ready third-person controller, camera, jump, sprint, and crouch.
- [x] Assemble a compact traversal greybox with physics props.
- [x] Implement and recover from a bounded ragdoll/knockdown state.
- [x] Run automated checks and visually inspect the playable sandbox.

Later phases remain governed by section 17 of `DESIGN.md` and must not begin until Phase 1 passes.

## Phase 2 — Match

- [x] Add authoritative lobby readiness, health, damage, death causes, winner rules, timeout ties, and solo-safe match state.
- [x] Connect the local sandbox to HP, alive count, timer, active state, and lethal results presentation.
- [x] Add deterministic spectator target cycling after death and inspect the rendered state.
- [x] Add restart cleanup and verify five consecutive rematches without leaked sandbox physics bodies.
- [x] Add server-arbitrated object grabbing, one-owner contention, bounded spring holding, and forced release.

## Phase 3 — Slice disasters

- [x] Implement Meteor Shower with an authoritative warning, impact damage, bounded impulse, ragdoll trigger, and cleanup.
- [x] Implement Flood with authoritative water level, breathing grace, damage, buoyancy, and cleanup.
- [x] Implement Tornado with an authoritative path, bounded pull/lift/throw forces, cover reduction, and cleanup.
- [x] Validate each disaster independently before enabling director selection or overlap.

## Phase 4 — Additional disasters

- [x] Implement Earthquake with predefined breakable structures and debris.
- [ ] Implement Lightning with fair telegraphs and authoritative strikes.
- [ ] Implement Fire with predefined zone/neighbor propagation.

## Director and overlap groundwork completed ahead of Phase 5

- [x] Add a server-owned Disaster Director with randomized selection and immediate-repeat suppression.
- [x] Add disaster metadata, minimum-time/difficulty gates, and symmetric compatibility checks.
- [x] Escalate intensity from solo opening hazards to a hard cap of two simultaneous disasters.
- [x] Require each hazard to complete solo before it can participate in an overlap.
- [x] Validate overlap behavior, separate-peer authority, five-rematch cleanup, and the rendered multi-hazard HUD.

## Phase 5 — Disaster combinations

- [ ] Add named cross-disaster events and shared hazard queries.
- [ ] Implement Flood + Lightning electrified water.
- [ ] Implement at least one additional physical interaction such as Tornado + Fire or Earthquake + Flood.

Current Flood + Tornado validation proves simultaneous coexistence and readable presentation, not a true cross-disaster interaction.

## Slice polish and validation completed ahead of Phase 7

- [x] Validate one authoritative server plus four separate local clients against the same active Flood + Tornado match snapshot.
- [x] Render and inspect a four-player overlap HUD with both hazards, readable danger geometry, and a dry refuge.
- [x] Profile 600 representative overlap frames at 1280 × 720 and record renderer, CPU, draw calls, node count, frame time, and physics time.
- [x] Validate the 60 FPS target with native Windows Godot on Intel UHD 630 hardware; two uncapped 600-frame runs measured p95 frame times of 11.74 ms and 11.37 ms.

## Phase 6 — Multiplayer stabilization

- [x] Validate authoritative ready, match, health, alive, damage, and overlapping-disaster snapshots with 2, 4, 8, and 20 separate clients.
- [x] Connect the playable scene to ENet create/join, authoritative player spawning, local camera ownership, and disconnect cleanup.
- [x] Submit playable client input to the host, simulate movement authoritatively, and batch player snapshots back to clients.
- [x] Replicate playable match state, health, elimination, alive count, local HUD, and spectating.
- [x] Replicate Meteor, Flood, and Tornado presentation into a two-peer playable session.
- [ ] Validate representative playable 4/8/20-player sessions rather than state-only probes.

## Phase 7 — Polish

- [x] Present HP, alive count, timer, active-disaster names, warnings, and baseline disaster VFX.
- [ ] Add gameplay audio and verify warnings remain audible during overlap.
- [ ] Add a complete winner/results screen with survival summary and network rematch flow.
- [ ] Perform final UI/VFX/feedback tuning after Phases 4–6 are complete.
