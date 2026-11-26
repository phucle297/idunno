# A3 perf top-up (Architect A3 ruling §3), PR #39 head fa6b038 vs B=ae933edd
llvmpipe/xvfb, all runs under the heavy lock, evidence-only (no code change).
- (a) 4P toy_town, all 4 players moving (2 walk 4.5, 2 sprint 6.5 m/s, IK active; is_foot_planted toggled 67-98x/run), 6 interleaved pairs:
  avg A 134.59 vs B 130.38 ms (+3.2%), p95 145.75 vs 140.18 (+4.0%), prims 756,666 vs 744,945 (+1.6%). PASS (gates +10/+10/+5).
  Single pairs 4 and 5 had p95 +10.7% / +10.2% (noise; mean gates).
- (b) interior trace overall p95 A 276.53 vs B 271.33 ms (+1.9%). PASS (gate +10%). town_roof p95 191.52 vs 192.97.
  Note: the A trace's overall avg (175.58) and max (69.9 s) are inflated by a single stall frame (B also had an 18.8 s outlier); p95 is the gate.
- (c) sync_rig(1/60) x10,000: weight 1 0.00958 vs weight 0 0.00475 ms/call (median of 5), extra 0.0048 ms (gate 0.05), OBJECT_COUNT delta 0. PASS.
Files: moving_summary.txt, topup_run.log, micro_sync_rig.log, perf_bench_moving.gd, micro_sync_rig.gd, T44-a3-topup.sh, trace-A/, trace-B/.
