# T47 A1 evidence (SWE · T47) — base f395fe84, A = feat/T47-lava-zones (PR #43)
Times in logs labelled "ICT" are really UTC (box has no Asia/Saigon tzdata for those scripts): add 7 h for ICT.
- Suites (local, heavy lock): run1..run6.txt + logs/ (per-suite logs of the last run; run6 = final head e521cb3 for test_lava_zones, test_volcano). run3/run5 cover the rest at e4d6173 (tile lift 0.03 -> 0.06 is render-only).
- captures/ (head e521cb3): A-* new build, B-* base f395fe84. capture_A.txt / capture_B.txt = layouts and traces. captures-e4d6173/ = same set before the 0.06 m lift (lava hidden under render-only paving).
  (a) B-/A-<map>-a-flood-street.png (+ -top): same camera, FLOOD at flow 28 s Town / 14 s Harbor.
  (b)(g) A-<map>-zones-seed300{0,1,2}-at150-top.png (spawn markers = blue posts), -at350 = 3 zones, -zones-seed3000-gameplay, -crater-seed3000.
  (c) A-<map>-flood-1-warning / -2-10s / -3-34s / -4-cooled.
  (f) A-<map>-f-cooled-heat{21,20,19}-flow.png + -heat19-crater.png; HP/escape text per step in capture_A.txt (heat 21: no damage yet, 21->20: 6 HP, 20->19: 0 HP, tiles 0 and HUD blank at 19).
  (d) client == server: test_lava_zones snapshot checks (client tile set == server tile set, same crater/zones/stage) in logs/test_lava_zones.log; no networked screenshot.
- perf.txt / perf_summary.txt: 4P moving bench (T44 A3 bench + lava), 6 interleaved B/A pairs, lava visible (B full flow plane, A FLOOD tiles). Az1-3 (ZONES info) ran with the flow already cooled (tiles=0): not informative.
- matrix.sh, matrix1.log/time, score-t47m1.log, gate_table_vs_T14.log: T3z Hard matrix (10 seeds x 2 maps x 4 controls) on A. Column labels in gate_table are the tool's: "baseline" = T14 main 27a35bf3, "T6" = this T47 run.
