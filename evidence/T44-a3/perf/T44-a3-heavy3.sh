#!/usr/bin/env bash
set -u
F=/home/box/game-factory; G=/home/box/bin/godot
A=$F/repos/idunno-T44-a2; B=$F/repos/idunno-T44-base
run() { timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" $G --path "$1" --script "$2" -- "${@:3}"; }
for i in 7 8 9; do
  run $B res://.scratch/perf_bench.gd --label=B_ae933edd_run$i 2>&1 | grep PERF_4P
  run $A res://.scratch/perf_bench.gd --label=A_T44a3_run$i 2>&1 | grep PERF_4P
done
echo HEAVY_A3_3_DONE
