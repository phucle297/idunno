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

## Perf (llvmpipe/xvfb, heavy lock; see `perf/PERF_SUMMARY.md`, `heavy.log`, `perf/*.log`)
- 4P moving gate, A5 AA-off (uncommitted override.cfg msaa_3d=0) vs B ae933edd, 6 interleaved pairs: avg -0.8%, p95 -3.1%, prims +1.3% -> PASS (gates +10/+10/+5).
- Info, AA-on vs AA-off on the A5 tree, 6 interleaved pairs: avg +50.8% (0.8 pp over the +50% sanity ceiling, informational), p95 +49.3%, prims -0.2%.
- Interior trace gate, A5 AA-off vs B: only 3 complete interleaved pairs (plan asks >=6): p95 +16.0% / +2.4% / +7.4%, mean +8.4% (gate <=+10%) -> PASS on 3 pairs, NOT confirmed at 6 pairs
  (each trace took ~8-16 min and the 90-min cap was hit; run 4 aborted and discarded). Pair 1 alone breaches +10%, so the margin is thin. Interior AA-on vs AA-off info traces not run.
- Real-GPU cost is unmeasured (software rasteriser). A graphics-quality toggle is a follow-up if the Owner sees low-end GPU drops.

## Whitelist
Only `project.godot` (that one key) and `evidence/T44-a5/**` differ from `817824b`; see `frozen_proof.txt`. No override.cfg is tracked or left on disk.
