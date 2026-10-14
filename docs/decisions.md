# Disaster Party — Active Decisions

The original Phase 7 archive is historical; its visual-completion claim is superseded.
Character/world/camera/interface selections and earlier implementation defaults live in
[old-docs/phase-7-soft-creature-world-and-interface/decisions.md](old-docs/phase-7-soft-creature-world-and-interface/decisions.md).
Root [progress](../progress.json) now tracks the
[Phase 7 visual correction](checklists/phase-7-visual-correction.md).
No Phase 8 implementation, deployment or renewed manual prerequisite is inferred from planning.

## Phase 7 visual correction — 2026-10-14

- Audit found no earlier Phase7 changes in `game/ui/` or `scenes/main.tscn`; functional regression was incorrectly presented as visual completion. Preserve the archive and supersede that claim here.
- Correct source of truth rather than layering a second UI: recompose the existing lobby, use actual catalog meshes for thumbnails, lighten existing panels and align HUD/settings/results with cream/teal matte direction.
- Selected B is a non-human broad continuous body. Increase visible base geometry to5992 triangles (5880 visible +112 compatibility anchor), retaining gameplay capsule, skeleton/clip IDs and physics contracts. This is an explicit visual-quality tradeoff, not a proven hardware-performance improvement.
- Environment additions are visual-only: small bevels, layered trim/windows/awnings, street furniture and paving. Collision/anchor snapshots remain identical (town107, harbor46). Keep playable ramps/cover/breakables; do not turn reference buildings into new gameplay obstacles.
- Store selected concept PNGs and provenance in `assets/references/phase7`; exclude from packaged runtime. Concepts are direction, not proof or pixel targets. Existing long-name ellipsis preserves layout with full tooltip text.
- All42 suites, five network matrices, managed20 and persistence restart passed. Render/real-pointer evidence covers the changed UI. Linux llvmpipe only; software shutdown-resource diagnostics remain documented by the existing runner. Human/native GPU/60FPS acceptance is not claimed.
- Owner explicitly authorized push after the correction. Commit with `[skip ci]` because the main workflow deploys automatically; no new deploy/release was requested.

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
