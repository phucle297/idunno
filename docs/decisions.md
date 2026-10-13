# Disaster Party — Active Decisions

Phase 7 is completed and archived: character/world/camera/interface selections and
implementation defaults live in
[old-docs/phase-7-soft-creature-world-and-interface/decisions.md](old-docs/phase-7-soft-creature-world-and-interface/decisions.md).
Root [progress](../progress.json) now tracks Phase 8; its
[checklist](checklists/phase-8-shrinking-survival-zone.md) specifies execution and gates.
No Phase 8 implementation, deployment or renewed manual prerequisite is inferred from planning.

## Phase 8 — shrinking survival zone (owner-requested, not yet implemented)

- **Owner request:** add a PUBG-like safe zone that shrinks over match time for more
  competitive pacing. This is a gameplay change, not part of the Phase 7 art/interface refactor.
- **Contract (defaults to test, not proven balance):** one fixed-center horizontal circle
  per map covering every playable corner + 0.5m margin at round start, contracting in
  announced hold/shrink stages to a nonzero final radius (22m), never collapsing to a point.
- **Authority and timing:** server-authoritative zone state driven by the match's elapsed/
  duration fraction (never a separate wall clock); clients render replicated state and
  interpolation never changes authority, grants grace, or deals damage. Inside/outside uses
  the authoritative player root x/z distance with consistent numerical tolerance; vertical
  height, crouch, hats and cosmetic ragdoll bodies do not change it.
- **Damage:** outside deals gradual damage (`Outside survival zone`) after the initial grace
  and only to alive players during an active match; roofs/walls cannot shield it. Integrate
  elapsed exposure across stage boundaries (no per-FPS or single-tick burst).
- **Integration:** inside the zone remains vulnerable to disasters; new hazard selection
  should target remaining viable area rather than granting immunity or relocating announced
  strikes. Zone-boundary warning stays distinct from the existing two disaster chips and the
  existing whole-map out-of-bounds death rule stays separate.
- **Default stage schedule** (600s match; scale by fraction for other durations): 0–120s full
  coverage grace; 120–150s announce first shrink; then staged contraction 32m → 28m → 24m with
  short announces and outside damage escalating 2 → 4 → 6 HP/s. Center/radius candidates and
  final tuning remain design questions validated against both maps and 2–20-player matches.
- **Non-goals:** no new teleport, respawn, healing, weapon, loot, progression rule, random/
  moving center, or collapse-to-point finish. Existing result ties, reward rules and disconnect
  semantics are unchanged.

Generated images and prior concept references are concept material only; no zone behavior,
balance, camera, performance or safe-zone validation is claimed until Phase 8 executes its gates.
