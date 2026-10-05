# Vertical Slice Implementation Checklist

This checklist executes the existing plan in `PROMPT.md` and `DESIGN.md`; it does not replace either document.

## Phase 1 — Core sandbox

- [x] Inspect local tools and select an engine/export pipeline.
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
- [ ] Add spectator target cycling after death.
- [x] Add restart cleanup and verify five consecutive rematches without leaked sandbox physics bodies.
