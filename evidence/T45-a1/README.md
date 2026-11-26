# T45 attempt 1 (A+B) evidence — SWE · T45, head see PR #40, base 77b7ae29
All captures 1280x720 native from the real gameplay camera (Player/CameraPivot/SpringArm3D, pitch -0.28,
toy_town daylight), produced by `scripts/capture_t45_arms.gd` on both trees (B = 77b7ae29 worktree, A = this branch).
- `captures-before/`, `captures-after/`: `<species>_o<outfit>_<idle|run|hold>_<front|3q|side>.png` for bear/cat/bunny
  (outfits 0/1/2), run = swing peak (phase 0), hold = hammer at HandAnchor; `4p_colours_idle_*` = player colours 0-3
  (outfits 0-3); `strip_walk_side_10f.png`, `strip_run_side_10f.png`, `strip_run_hold_side_10f.png` (10 frames/cycle,
  1:1 240x260 crops, no resize); `camera_log.txt` (sizes, anchor positions per shot/frame).
- `compare_sheet_before_after_1to1.png`: B/A pairs, 1:1 crops (no scaling), 3 species x 3 states x 3 views.
- Numbers: `arm_pose_before_77b7ae29.txt` / `arm_pose_after.txt` (scripts/arm_pose_probe.gd: elbow/wrist/hand root
  positions, chain flexion, abduction), `golden_hold.json` (77b7ae29 HandAnchor) — held-item anchor delta 0.000 mm on
  all idle/walk/run samples. Idle abduction 32.3-33.4° (was 20.0°), added elbow bend 0.38 rad = 21.8° (chain 28.1°
  incl. the 6.3° KayKit rest offset), pitch +6°. Swing peaks (test log): walk 0.300 rad, walk@2.25 0.150, run 0.520.
- Clearance (AC3): `clearance_before_77b7ae29.txt` / `clearance_after.txt` (scripts/arm_clearance.gd, all 12 outfits,
  idle/walk/run x 8 phases, arm centre line vs Rogue_Body + Belly/Tail verts in the un-waddled root frame).
  Worst wrist gap before -0.063 m (inside the body) -> after +0.016 m (outside); plan margin 0.04 NOT met on the
  left side where the KayKit belt pouch (x up to 0.27 at y~0.43) meets the run back-swing (other samples >= 0.050).
  Elbow gap is Info (near the shoulder; plan criterion unattainable below ~45° abduction). 0.26 rad abduction was
  tried: worst 0.029 (still < 0.04) and 35.7° measured, so reverted to the 0.21 default.
- `frozen_rehash.txt`: 884 non-whitelist files blob-identical; TCV hunks are pure additions.
- `PERF_SUMMARY.md`, `perf/` (6 interleaved 4P moving pairs + sync_rig micro). Interior trace not run.
- `suites/`: local logs test_character_animation (292 checks), test_critter_asset (219), test_phase1 (1273),
  test_toy_sabotage_visuals (15), test_toy_sabotage (345) — all exit 0.
