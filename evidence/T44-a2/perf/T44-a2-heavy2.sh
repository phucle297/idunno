#!/usr/bin/env bash
set -u
F=/home/box/game-factory; E=$F/repos/idunno-T44-a2/evidence/T44-a2; G=/home/box/bin/godot
A=$F/repos/idunno-T44-a2; B=$F/repos/idunno-T44-base
cd $A && .scratch/suites.sh $E/suites test_critter_asset test_phase1 test_character_animation test_player_integration test_player_colliders test_cosmetic_collection
run() { timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" $G --path "$1" --script "$2" -- "${@:3}"; }
for i in 3 4 5; do
  run $B res://.scratch/perf_bench.gd --label=B_ae933edd_run$i 2>&1 | grep PERF_4P
  run $A res://.scratch/perf_bench.gd --label=A_T44a2_sync_cached_run$i 2>&1 | grep PERF_4P
done
echo HEAVY2_DONE
