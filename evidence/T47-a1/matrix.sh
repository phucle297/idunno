#!/usr/bin/env bash
# T47 A1: T3z Hard matrix on A (run1 gate, run2 same-seed replay), caller holds heavy lock.
F=/home/box/game-factory; E=$F/evidence/T47-a1; R=$F/repos/idunno-T47; Q=$F/games/idunno/qa
export GODOT_BIN=/home/box/bin/godot
log(){ echo "$(TZ=Asia/Saigon date '+%F %T ICT') $*" >> $E/matrix-progress.txt; }
mkdir -p $E/matrix; cd $R
log "START head=$(git rev-parse --short HEAD)"
for n in 1 2; do
  s=$(date +%s); JOBS=6 tests/run_rooftop_baseline.sh $E/matrix t47m$n > $E/matrix$n.log 2>&1; ec=$?
  echo "exit=$ec wall=$(( $(date +%s)-s ))s" > $E/matrix$n.time; log "matrix t47m$n $(cat $E/matrix$n.time)"
  [ $ec -eq 0 ] || break
  if [ $n = 1 ]; then M=$E/matrix; python3 $Q/T3z/score_t3z.py $M/T3b-t47m1.json $M/T3b-t47m1-samples.jsonl $Q/T3-baseline.json $E/score-t47m1.json > $E/score-t47m1.log 2>&1; log "score exit=$?"; fi
done
M=$E/matrix
[ -f $M/T3b-t47m2.json ] && python3 $Q/T3z/compare_runs.py $M/T3b-t47m1.json $M/T3b-t47m1-samples.jsonl $M/T3b-t47m2.json $M/T3b-t47m2-samples.jsonl > $E/replay_determinism.log 2>&1 && log "replay compare done"
log END
