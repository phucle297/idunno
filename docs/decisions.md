# Disaster Party — Active Decisions

Phase 7 is planned, starting at the representative in-engine slice. Phase 6 is completed and its full
[decisions](old-docs/phase-6-cosmetic-loot-box-drops-and-customization/decisions.md),
[checklist](old-docs/phase-6-cosmetic-loot-box-drops-and-customization/checklist.md)
and [evidence](old-docs/phase-6-cosmetic-loot-box-drops-and-customization/progress.json)
are archived together. Root [progress](../progress.json) tracks planned Phase 7;
[Phase 7](checklists/phase-7-soft-creature-world-and-interface.md) and dependent
[Phase 8](checklists/phase-8-shrinking-survival-zone.md) specify execution and gates.
No implementation, deployment or renewed manual prerequisite is inferred from planning.

## Next-scope design selections and proposals

- **Selected by owner:** A's tactile toy-kit direction, refined toward restrained
  lighting and consistent materials across buildings, infrastructure, roads and UI.
  Preserve the liked concept environment; this is not acceptance of current engine art.
- **Selected character:** B, Soft Creature: continuous rounded head/body, simple
  face patch, short arms and distinct feet. No human worker anatomy. Cosmetics must
  adapt to this silhouette without changing gameplay hitboxes or ownership rules.
- **Camera:** owner accepts the camera exploration generally; no specific A/B/C view
  or numerical camera setting is selected. Compare actual engine views before locking it.
- **Required planning scope:** detailed usable interiors for houses, a school and other
  buildings, not facade-only detail. Existing Toy Town has Shop/Hall/Garage; Toy Harbor
  has Warehouse/CraneDeck/docks. Houses and school are new content, not existing assets.
  Specify their placement, room purposes, entrances, vertical routes and shelter rules
  before replacing or expanding map geometry.
- **Requested gameplay proposal:** a PUBG-like playable zone shrinking over match time
  to concentrate survivors. No competitive zone exists today; fixed square map bounds
  and local disaster rings are different systems. Treat this as a separate gameplay
  milestone, not a behavior-preserving art refactor.
- **Recommended zone contract, not yet implemented or tuned:** server-authoritative
  horizontal boundary independent of building/roof elevation; early grace, announced
  hold/shrink stages, gradual outside-zone damage rather than immediate elimination,
  and full rematch reset. Inside the zone remains vulnerable to disasters. Warn clearly
  indoors and outdoors, preserve reachable routes and viable refuge choices, and integrate
  director targeting with remaining playable space. Do not introduce weapons or loot.
  Center/radius schedule, damage, last-stage behavior and camera presentation remain
  design questions to validate on both maps and 2–20-player matches.

Generated images are concept references only; no asset, engine-camera, performance,
interior or safe-zone validation is claimed by these selections.

## Implementation-plan defaults — 2026-10-13

Owner requests careful planning for one continuing implementation effort. The detailed
checklists supersede unresolved proposal details above with reversible defaults:

- Phase 7 includes all art, maps/interiors, character/outfit/animation/ragdoll adaptation,
  every UI state and cross-system validation. Phase 8 separately changes zone behavior
  and delivers matching integrated local packages. Complete each milestone before advancing.
- Camera B/high three-quarter is a proposed default, conditional on actual clearance,
  traversal and readability captures; not an owner selection of one precise camera.
- Restyle existing Hall as School while preserving stable breakable/route IDs; add one
  8×8m house in the southwest edge space, with measured collision clearances. No new map.
- Fixed map-specific zone centers, full initial corner coverage and staged contraction
  to a nonzero 22m final radius. First two minutes grace; damage 2/4/6 HP per second;
  advance notices and existing timeout ranking. No random moving center in first version.
- Require two reachable high refuges and remaining exits during zone contraction;
  defer incompatible new hazard selection rather than grant universal immunity or
  relocate already-announced strikes. Details/numbers are defaults to test, not proven balance.
- Keep source/asset provenance and historical evidence; do not rewrite DESIGN or
  waive automated correctness checks. Commit/push with `[skip ci]` to avoid deployment.
