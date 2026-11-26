#!/usr/bin/env bash
# T44 A3 perf top-up (Architect A3 ruling section 3). Caller holds the heavy lock.
set -u
F=/home/box/game-factory; G=/home/box/bin/godot
A=$F/repos/idunno-T44-a2; B=$F/repos/idunno-T44-base; E=$A/evidence/T44-a3/perf
run() { timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" $G --path "$1" --script "$2" -- "${@:3}"; }
for i in 1 2 3 4 5 6; do
  if [ $((i % 2)) -eq 1 ]; then ORDER="B A"; else ORDER="A B"; fi
  for w in $ORDER; do
    if [ $w = A ]; then T=$A; L=A_T44a3_moving_run$i; else T=$B; L=B_ae933edd_moving_run$i; fi
    run $T res://.scratch/perf_bench_moving.gd --label=$L 2>&1 | grep -E "MOVING|PERF_4P"
  done
done
echo MOVING_PAIRS_DONE
for w in B A; do
  if [ $w = A ]; then T=$A; else T=$B; fi
  run $T res://tools/render_indoor_lighting.gd --mode=trace --out=$E/trace-$w 2>&1 | grep -E "INDOOR_TRACE" | sed "s/^/$w /"
done
echo TOPUP_DONE
