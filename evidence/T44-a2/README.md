# T44 A2 evidence (KayKit Rogue_Hooded critter hoodie)

All Godot runs under the factory heavy lock; Linux, Godot 4.7.2 Compatibility, llvmpipe (xvfb).
B = ae933edd (`idunno-T44-base`), A = this branch.

- `camera/`: `tools/evidence/capture_t44_camera.gd` with the REAL `Player/CameraPivot/SpringArm3D/Camera3D`
  (pitch -0.28, spring 6.0, FOV 65), 1280x720. Town + Harbor daylight rear/3q/front (player turned) for bear/cat/bunny
  with a held hammer, indoor shelter rear/front, 4P colours front/rear, walk/run 8-frame cycle strips + 3 s timelines,
  `side_by_side_sheet_vs_ingame.png` (spike sheet above, in-game Town fronts below), `camera_log.txt`
  (spring hit length + projected eye diameter per shot; outdoor spring 6.00 m, eye 7.8-8.9 px; indoor Town 3.63 m).
- `lineup12_front.png`, `lineup12_rear.png`: 12 outfits x 4 player colours (`lineup_render.gd`, neutral stage).
- `suites/`: final logs of the 6 suites (critter_asset 218, phase1 1270, char_anim 263, player_integration 586,
  colliders 83, cosmetic 29 checks, all OK).
- `perf/`, `perf_heavy_run.log`, `perf_heavy_run2.log`: 4P toy_town bench + interior trace (scripts included).
- `frozen_diff.txt`: 0-line diff on frozen files. `license_check.txt`: LICENSE identical to upstream @672074b.

Honest notes: the A2 spike sheet rendered KayKit at yaw 0, so its face plate sat on the hood's back; integration uses
the true front (yaw 180) and the cream face covers the KayKit face. Eye diameter for rear shots is a projection of the
(occluded) bead, logged for completeness. Rendering is software (llvmpipe); no native-GPU claim.
