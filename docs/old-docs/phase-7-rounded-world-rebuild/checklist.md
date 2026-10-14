# Phase 7S — Rounded world rebuild

Owner rejected the previous correction as still too boxy and supplied a rounded town/camera reference. Source/test delivery of7R was real; its appearance is not accepted. Pause planned Phase8; do not overwrite7R history.

- [x] 7S.1 Replace tiny single-step bevels with visibly curved, multi-segment architecture/props; remove the canopy BoxMesh exception. Use coherent rounded awnings, planters, railings, foliage and furniture. Preserve gameplay volumes and route contracts.
- [x] 7S.2 Capture unchanged/changed town, storefront, house/school interiors and harbor from identical cameras; compare actual collider/anchor snapshots and run map/carry/breakage/rematch regressions. Inspect both gameplay-distance and close views before deciding it looks improved.
- [x] 7S.3 Keep owner's exact reference PNG and provenance in source; update manifest and evidence, commit/push `[skip ci]` without deployment. Delivered [source commit](https://github.com/phucle297/idunno/commit/78aa2a85eac6be297ac5ef653f40125ec3a96a3b); remote main matched local HEAD.

Owner's request overrides the old0.08m architecture bevel cap for render geometry only. No claim of exact image equivalence, real-GPU performance, human acceptance or new safe-zone functionality.

Evidence: `ROUNDED_WORLD_COLLIDERS_IDENTICAL` (town107/harbor46), measured972 triangles/module;
`UI_REGRESSION_OK suites=42 matrices=5 managed_clients=20 persistence_restart=passed`;
final-refinement reruns `MAP_SAFETY_OK251`, `MAP_VARIETY_OK303`, `CARRY_PRESENTATION_OK41`.
Inspected same-camera before/after storefront/town and school/house/garage/harbor renders.
Interior views are clearly labeled roof-hidden inspection cutaways, not normal game camera.
Geometry rises from108 to972 triangles/module; cache sharing remains, but GPU budget is not
proven. Shadows, scene density and main layout still differ from the concept; do not turn
source completion into the owner's visual acceptance. Existing shutdown-only resource
diagnostics remain recorded by the unchanged strict runner.
