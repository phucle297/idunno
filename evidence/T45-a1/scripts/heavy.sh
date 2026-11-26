#!/usr/bin/env bash
# T45 A1 heavy runs (caller holds /home/box/game-factory/.heavy.lock via flock).
# Captures A/B, sync_rig micro A/B, 6 interleaved 4P moving perf pairs (B,A / A,B ...).
set -u
F=/home/box/game-factory
G=/home/box/bin/godot
A=$F/repos/idunno-T45
B=$F/repos/idunno-T45-base
E=$A/evidence/T45-a1
P=$E/perf
mkdir -p $P $E/captures-after $E/captures-before
X(){ timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" "$@"; }
echo "HEAVY start $(TZ=Asia/Saigon date '+%F %T') ICT A=$(git -C $A rev-parse HEAD) B=$(git -C $B rev-parse HEAD)"
rm -f $E/captures-after/*.png
X $G --path $A --script res://evidence/T45-a1/scripts/capture_t45_arms.gd -- --out=$E/captures-after > $P/capture_A.log 2>&1; echo "capture A ec=$?"
X $G --path $B --script res://t45tmp/capture_t45_arms.gd -- --out=$E/captures-before > $P/capture_B.log 2>&1; echo "capture B ec=$?"
$G --headless --path $A --script res://evidence/T45-a1/scripts/micro_sync_rig.gd > $P/micro_A.log 2>&1; echo "micro A ec=$?"
$G --headless --path $B --script res://t45tmp/micro_sync_rig.gd > $P/micro_B.log 2>&1; echo "micro B ec=$?"
one(){ local T=$1 R=$2 PP S; if [ $T = A ]; then PP=$A; S=res://evidence/T45-a1/scripts/perf_bench_moving.gd; else PP=$B; S=res://t45tmp/perf_bench_moving.gd; fi
  X $G --path $PP --script $S -- --label=${T}$R > $P/moving_${T}_run$R.log 2>&1; echo "moving $T run$R ec=$? $(rg -o 'PERF_4P.*' $P/moving_${T}_run$R.log)"; }
for r in 1 2 3 4 5 6; do if [ $((r % 2)) = 1 ]; then one B $r; one A $r; else one A $r; one B $r; fi; done
echo "HEAVY done $(TZ=Asia/Saigon date '+%F %T') ICT"
