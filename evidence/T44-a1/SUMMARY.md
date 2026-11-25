# T44 attempt 1 evidence (SWE), branch feat/T44-plush-critter-character, PR #38
Base B = ae933edd, head A = 5a8a8d1 (asset/code commit). Godot 4.7.2, llvmpipe, xvfb, heavy lock held for all heavy runs.

## Suites (local, head 5a8a8d1)
test_phase1 PHASE1_TESTS_OK checks=1888 | test_character_animation OK 67 | test_player_integration OK 466 |
test_player_colliders OK 83 | test_cosmetic_collection OK 29 | test_critter_asset CRITTER_ASSET_OK 328
(test_critter_asset: worst limb-root SDF -0.0497 m, so >= 0.04 m inside the Body; Body 1337 verts / 2506 tris, deterministic hash 2796617833)
Tris: base <= 6000 gate passes; outfit totals 6076-6752 (<= 7000); each accessory < 800.
CI on PR #38: Godot import + fast suites, Python, Export smoke, Lint, Flaky: all pass.

## Perf 4P toy_town 1280x720 (perf_bench.gd, interleaved B,A,B,A in the same window)
B run1 avg 127.54 p95 138.32 prims 746,862 | A run1 avg 128.04 p95 132.88 prims 736,078
B run2 avg 125.58 p95 134.78               | A run2 avg 126.29 p95 132.68
=> avg +0.4..0.6%, p95 -1.6..-3.9%, prims -1.4%, draw calls 2425 -> 2391.

## Interior trace (tools/render_indoor_lighting.gd --mode=trace)
run1 overall p95 B 255.07 / A 283.65 (+11.2%, near miss); town-roof p95 B 200.27 / A 209.97 (+4.8%)
run2 overall p95 B 265.85 / A 276.12 (+3.9%); town-roof p95 B 195.69 / A 186.61 (-4.6%). B run2 had one 1504 ms pause frame (over 1 s, so it is trimmed per the plan; p95 is not affected).

## Images
before/ (ae933edd) and after/ (head): Town and Harbor, daylight front/3q/rear, plus indoor 3q/rear, with the held item on HandAnchor.
after-lineups/: lineup_12_front/rear (12 outfits), lineup_4p_colours_front/rear, close-ups (front/3q/rear/side), and pose_* at animation extremes.
