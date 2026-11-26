#!/usr/bin/env bash
# T47 A1: run named Godot suites in repos/idunno-T47 (caller holds the heavy lock).
F=/home/box/game-factory
E=$F/evidence/T47-a1
G=/home/box/bin/godot
TREE=$F/repos/idunno-T47
mkdir -p "$E/logs"
echo "START $(date '+%F %T') head=$(git -C $TREE rev-parse --short HEAD) dirty=$(git -C $TREE status --porcelain | wc -l)"
"$F/tools/godot-import.sh" "$TREE" "$E/import" || { echo IMPORT_FAILED; exit 2; }
for name in "$@"; do
  s=$(date +%s)
  timeout 900 "$G" --headless --path "$TREE" --script "res://tests/$name.gd" -- "--settings-path=user://t47-$name.cfg" > "$E/logs/$name.log" 2>&1
  ec=$?
  errs=$(grep -E '^(SCRIPT ERROR|ERROR):' "$E/logs/$name.log" | grep -cvE '^ERROR: [0-9]+ resources still in use at exit')
  marker=$(grep -oE '^[A-Z0-9_]+_OK( |$)' "$E/logs/$name.log" | tail -1)
  echo "$name exit=$ec errors=$errs wall=$(( $(date +%s) - s ))s marker=${marker:-NONE}"
done
echo "END $(date '+%F %T')"
