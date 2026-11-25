#!/usr/bin/env bash
# T44-a2 heavy session (caller holds the heavy lock): import A, perf pair B/A x2, interior trace B/A.
set -u
F=/home/box/game-factory; E=$F/repos/idunno-T44-a2/evidence/T44-a2; G=/home/box/bin/godot
A=$F/repos/idunno-T44-a2; B=$F/repos/idunno-T44-base
mkdir -p $E/perf
for T in $B $A; do mkdir -p $T/.scratch; cp $F/evidence/T44-a1/perf_bench.gd $T/.scratch/; done
$F/tools/godot-import.sh $A $E/perf/import-A > $E/perf/import-A.txt 2>&1; tail -1 $E/perf/import-A.txt
grep -c "ERROR" $E/perf/import-A/*.log 2>/dev/null | head -3
run() { timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" $G --path "$1" --script "$2" -- "${@:3}"; }
for i in 1 2; do
  run $B res://.scratch/perf_bench.gd --label=B_ae933edd_run$i 2>&1 | grep PERF_4P
  run $A res://.scratch/perf_bench.gd --label=A_T44a2_run$i 2>&1 | grep PERF_4P
done
run $B res://tools/render_indoor_lighting.gd --mode=trace --out=$E/perf/trace-B 2>&1 | grep -E "INDOOR_TRACE" | sed "s/^/B /"
run $A res://tools/render_indoor_lighting.gd --mode=trace --out=$E/perf/trace-A 2>&1 | grep -E "INDOOR_TRACE" | sed "s/^/A /"
echo HEAVY_DONE
