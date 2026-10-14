# Phase 8 Follow-Up — Solid Environment Collision

Status: completed technical source gates; separate owner-requested follow-up,
completed Phase8 archive unchanged. No new packages, deployment or release.
Scope: rail bars/posts and sloped stair handrails/balusters, shrubs/planter containers, lamps, roof vents and Harbor
bollards/cargo. Use simple static boxes and baked26-point convex shrub hulls;
no invisible blanket walls, foliage triangle mesh or extra dynamic/network props.
Thin paint/paving/window trim remains decorative. Existing authored routes,
breakable panel holes, map bounds, hitboxes and rematch ownership must remain valid.

## C.1 — Implement and verify collision

- [x] Explicit solid-detail collision in existing runtime geometry builders.
- [x] Real player-capsule obstacle sweeps, foliage-only ray check above container,
  flat-overlay control and both-map5-rematch lifetime regression.
- [x] Existing both-map routes/refuges/spawns/Flood escapes and breakable reset checks.
- [x] Record collision provenance/limitations; random movement drops remain plan-only.

Gate: obstacle contact blocks instead of passing through; no new hidden route
barrier, spawn overlap, central breakable panel support or collider accumulation.
No appearance redesign, new hazards, pickup implementation or public deployment.

Evidence: original source reproduces passing through rail/lamp/shrub. Final
MAP_DETAIL_COLLISION_OK82 includes rotated stair handrails and sustained walking
against the supported ParkRail, both maps/five rematches; Town963/Harbor69 static
detail bodies. Map variety424 passed before final stair collision; all routes and
refuge exits reran on final source (58 checks). Final map safety231, combinations102,
actual2/4-peer five-rematch matrices on each map passed. Rendered ramp/contact/shrub
states720p/1080p inspected. Headless20-avatar/four-synthetic-hazard120-warmup/600-sample
p95physics7.311ms/process5.481ms; snapshot3280bytes, peak6 loose/4 meteor effects,
final static memory plateau103787649bytes. Not native GPU/60FPS acceptance.

Extra scene-network runner passed once, failed once on transient prop-reset
observation; the latter is retained, not counted as Harbor coverage (that runner
ignores MAP_ID). Map-aware scale fixtures passed both maps without tolerance changes.
Known shutdown-only audio resource diagnostics remain; no gameplay runtime errors
accepted in final focused checks. Full41-suite regression and native/human checks
were not rerun for this follow-up. Existing local Phase8 bundles predate this source.
