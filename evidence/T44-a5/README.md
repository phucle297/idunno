# T44 A5 evidence — gameplay MSAA 2x (AC13)
Godot 4.7.2 Compatibility on llvmpipe (xvfb), under the factory heavy lock. Base A4 head `817824b`.
Change: `project.godot` `[rendering] anti_aliasing/quality/msaa_3d=1` (Viewport.MSAA 2x). Home preview SubViewport left alone.
AA-off evidence frames and the perf gate used a temporary uncommitted `override.cfg` (`msaa_3d=0`), deleted after the session.

## Visual (native 1280x720, 1:1, no upscale)
Script: `capture_t44_a5_aa.gd`. Town daylight (`toy_town` plaza) + House interior (`Sandbox/House` at -18,0,27).
A4 sheet framing (spot+(0,1.1,-2.3) look_at spot+(0,0.8,0), fov 65, yaw 0) and the gameplay camera (CameraPivot pitch -0.28, visual yaw PI).
- `{town,interior}_{sheet,game}_aa{off,on}.png` — full 1280x720 frames
- `side_by_side_*.png` and `crop_side_by_side_*.png` — AA-off | AA-on at 1:1
- `{town,interior}_{sheet,game}_2560_aa{off,on}.png` plus `*_2560_lanczos_*.png` (Lanczos 2560x1440 → 1280x720) and `refstrip_*.png`
- `msaa_3d.log`: fresh-launch `project_setting=1` and `root.msaa_3d=1`
- `edge_pixels.csv`: hard-stair edge pixels (luma |Δ|≥32 on isolated 1-px runs) in the plate/hood/body 1:1 crops

| view | AA-off stairs | AA-on stairs | drop |
| town sheet | 6453 | 3873 | 40.0% |
| town gameplay | 4316 | 1347 | 68.8% |
| interior sheet | 5073 | 2291 | 54.8% |
| interior gameplay | 1921 | 1304 | 32.1% |
| all crops | 17763 | 8815 | 50.4% |

All ≥20% (pass). Crops: sheet (440,130)-(840,550); gameplay (500,280)-(780,640).

## Perf
See `perf/PERF_SUMMARY.md` (filled after the heavy session) and `heavy.log`.
Gate: A5 AA-off (`override.cfg`) vs B `ae933edd`, 4P moving ≥6 interleaved pairs (mean avg/p95 ≤ B+10%, prims ≤ B+5%) and interior overall p95 ≤ B+10%.
Info: AA-on vs AA-off on the A5 tree, ceiling +50%. Prims should match. llvmpipe cost is not a real-GPU figure.

## Whitelist
Only `project.godot` (that one key) and `evidence/T44-a5/**` differ from `817824b`. `frozen_proof.txt` after the final commit.
