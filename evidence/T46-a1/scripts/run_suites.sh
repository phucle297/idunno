#!/usr/bin/env bash
set -u
A=/home/box/game-factory/repos/idunno-T46
E=/home/box/game-factory/evidence/T46-a1/suites
G=/home/box/bin/godot
mkdir -p "$E"
cd "$A"
ec=0
for s in test_critter_asset test_character_animation test_phase1; do
  start=$(date +%s)
  timeout 600 $G --headless --path . --script res://tests/$s.gd -- --settings-path=user://t46-$s.cfg > "$E/$s.log" 2>&1 || true
  e=${PIPESTATUS[0]}
  marker=$(rg -o '[A-Z0-9_]+_OK' "$E/$s.log" | tail -1 || true)
  checks=$(rg -o '[0-9]+ checks' "$E/$s.log" | tail -1 || true)
  errs=$(rg -c '^(SCRIPT ERROR|ERROR):' "$E/$s.log" | head -1 || true)
  echo "$(TZ=Asia/Saigon date '+%F %T') ICT $s exit=$e marker=${marker:-NONE} ${checks:-} errors=$errs wall=$(( $(date +%s) - start ))s"
  if [[ $e != 0 ]]; then ec=$e; fi
done
exit $ec
