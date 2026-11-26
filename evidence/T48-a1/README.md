# T48 A1 evidence (base f395fe84 vs head)
Flipped to solid (7 colliders): GarageSignboard (toy_town); Warehouse Rack0, Rack1, Rack2, Workbench, CrateStackA, CrateStackB (toy_harbor).
- captures/: before/after_garage_{rear,side}.png (free camera at the garage deck; player holds +z for 3 s). Before: player ends at z 22.57 on the ground (walked through the sign plane and off the deck). After: stops at z 20.73 on the deck (`*_garage.txt`).
- target-*.log: test_map_detail_collision on base (new asserts FAIL) vs head (`MAP_DETAIL_COLLISION_OK checks=199`).
- suites_summary.txt: full CI-mode suite run on head, 83/83 PASS (`CI_SUITES_OK suites=83`).
- perf.txt / perf_summary.txt: 6 interleaved base/head pairs, toy_town 4P moving bench (xvfb software render): avg +5.1%, p95 +7.2%, primitives +0.00%, physics step +0.48%. nodes.txt: Sandbox nodes town +2, harbor +12 (total +14).
- Interior trace not run: collision-only change (no mesh/material/scene edits).
