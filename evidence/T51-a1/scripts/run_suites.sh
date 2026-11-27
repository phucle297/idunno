#!/usr/bin/env bash
# T51 A1 targeted suites -> evidence/T51-a1/suites/ (exit code + marker per suite)
set -u
A="$(cd "$(dirname "$0")/../../.." && pwd)"
E=$A/evidence/T51-a1/suites
G=${GODOT_BIN:-/home/box/bin/godot}
mkdir -p "$E"
cd "$A"
echo "# head=$(git rev-parse --short HEAD)" >> "$E/suite_summary.txt"
ec=0
for s in "$@"; do
  start=$(date +%s)
  timeout 600 $G --headless --path . --script res://tests/$s.gd -- --settings-path=user://t51-$s.cfg > "$E/$s.log" 2>&1
  e=$?
  marker=$(rg -o '[A-Z0-9_]+_OK.*' "$E/$s.log" | tail -1 || true)
  errs=$(rg -c '^(SCRIPT ERROR|ERROR):' "$E/$s.log" | head -1 || true)
  echo "$(date -u -d '+7 hours' '+%F %T') ICT $s exit=$e marker=${marker:-NONE} errors=${errs:-0} wall=$(( $(date +%s) - start ))s" | tee -a "$E/suite_summary.txt"
  if [[ $e != 0 ]]; then ec=$e; fi
done
exit $ec
