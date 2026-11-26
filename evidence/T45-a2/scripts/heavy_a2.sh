#!/usr/bin/env bash
# T45 A2 heavy runs (caller holds /home/box/game-factory/.heavy.lock). A = this branch, B = f432e8a6 worktree.
set -u
F=/home/box/game-factory; G=/home/box/bin/godot
A=$F/repos/idunno-T45; B=$F/repos/idunno-T45-base; E=$A/evidence/T45-a2; P=$E/perf
X(){ timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" "$@"; }
echo "HEAVY start $(date -u +%T) UTC A=$(git -C $A rev-parse --short HEAD)+wt B=$(git -C $B rev-parse HEAD)"
X $G --path $A --script res://evidence/T45-a2/scripts/capture_t45_a2.gd -- --out=$E/captures-after > $P/capture_A.log 2>&1; echo "capture A ec=$?"
X $G --path $B --script res://t45tmp/capture_t45_a2.gd -- --out=$E/captures-before > $P/capture_B.log 2>&1; echo "capture B ec=$?"
X $G --path $A --script res://evidence/T45-a2/scripts/mitten_visible_fraction.gd -- --out=$E/captures-after --outfits=0,1,2,3,4,5,6,7,8,9,10,11 > $P/vis_A.log 2>&1; echo "vis A ec=$?"
X $G --path $B --script res://t45tmp/mitten_visible_fraction.gd -- --out=$E/captures-before --outfits=0,1,2 > $P/vis_B.log 2>&1; echo "vis B ec=$?"
one(){ local T=$1 R=$2 PP S; if [ $T = A ]; then PP=$A; S=res://evidence/T45-a1/scripts/perf_bench_moving.gd; else PP=$B; S=res://t45tmp/perf_bench_moving.gd; fi
  X $G --path $PP --script $S -- --label=${T}$R > $P/moving_${T}_run$R.log 2>&1; echo "moving $T run$R ec=$? $(rg -o 'PERF_4P.*' $P/moving_${T}_run$R.log)"; }
for r in 1 2 3; do if [ $((r % 2)) = 1 ]; then one B $r; one A $r; else one A $r; one B $r; fi; done
echo "HEAVY done $(date -u +%T) UTC"
