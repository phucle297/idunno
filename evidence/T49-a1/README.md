# T49-a1 evidence (SWE, head build, 60 Hz, headless)
Option A: `DEEP_SNOW_JUMP_HEIGHT_MULTIPLIER = 0.72`, applied at the jump-fire site only when `movement_surface().deep_snow` (snow >= 0.55). Base f395fe84.

Measured rise (apex - takeoff), from `tests/test_snow_jump.gd` (`snow_jump_test_output.txt`):
| case | base f395fe84 (arch probe) | head |
|---|---|---|
| dry (no weather) | 1.4122 | 1.4122 |
| dry, weather node, snow=0 | 1.4122 | 1.4122 |
| light snow 0.40 | 1.4122 | 1.4122 |
| ice (0.25, 0.25) | 1.4122 | 1.4122 |
| deep snow (snow=1) | 1.4122 | **1.0254** (plan est. 1.0245; -0.387 m, -27%) |
| dry jump power-up | 1.6883 | 1.6883 |
| deep snow + jump power-up | n/a (base has no snow modifier by code reading; not measured) | 1.2248 (plan est. 1.224) |

Takeoff vy: dry 7.348469 (unchanged), deep snow 6.235383 (= sqrt(2*20*1.35*0.72)). 1.0254 m clears the 0.93 m picnic top.
`jump_apex_dry_vs_snow.png`: rise-vs-time of both jumps (side-by-side apex). Base numbers are from `evidence/T49-arch/snow_jump_probe_output.txt` (0.000 delta dry vs snow).
`suite_summary.txt`: required suites, local exit/marker lines. Unrun here: full T9 80-seed baseline (heavy lock NO), in-engine picnic-table hop, perf bench (not required by plan).
