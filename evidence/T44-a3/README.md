# T44 A3 evidence — AC12 A3 amendment (hop-step legs, arms still)

Godot 4.7.2 Compatibility on llvmpipe (xvfb), all runs under the factory heavy lock. B = ae933edd.
- `strip_{walk,run}_{side,3q}_cycle*.png`: 10 frames over one cycle of a moving critter (red block = left foot
  planted, blue = right). Script: `capture_t44_a3_gait.gd`.
- `foot_trace_side_{walk,run}.png` + `foot_trace_*.csv` + `*_summary.txt`: side-view world z vs foot height over
  two cycles at dt 1/960 s with the root moving at 4.5 / 6.5 m/s; thick dots = planted samples (world-fixed point
  contacts on the ground line), thin = swing arcs. Max planted slide walk 0.0000 m, run 0.0006 m.
- `suites/`: the 6 suites (critter_asset, phase1, character_animation, player_integration, colliders, cosmetic).
- `perf/`: 4P perf pairs vs B (scripts + logs). `frozen_diff.txt`: frozen files 0-line diff.

Deviations from the Architect A3 delta (measured, see PR): the KayKit leg is nearly straight at rest
(hip->ankle 0.232 m vs leg 0.234 m), so the plan's reach clamp would give a 0.029 m half step; a 0.045 m
stepping knee bend (`STANCE_CROUCH`, body lowers while stepping) lets STEP_HALF 0.10 pass the clamp. The
opposite-thigh-pitch assert is checked at phases 0.0/0.5 (feet at opposite stride ends); at 0.25/0.75 one foot is
planted under the hip and the other mid-swing, so both thighs pitch forward.

Perf (4P toy_town bench, players idle so the IK path is not exercised; 9 interleaved pairs vs B, 3 batches):
mean avg 139.93 vs 133.34 ms (+4.9%), mean p95 156.77 vs 144.38 ms (+8.6%), prims 756,166 vs 746,862 (+1.25%).
Single pairs are noisy on llvmpipe: p95 ranged -9.7% to +25.6% (runs 3, 5, 6 above +10%). See perf/*.log.
