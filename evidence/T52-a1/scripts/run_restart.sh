#!/usr/bin/env bash
# T52 A1: real two-process restart (pick -> quit -> launch) plus colour_taken save probe.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT="${OUT:-$ROOT/evidence/T52-a1}"
G="${GODOT_BIN:-/home/box/bin/godot}"
USERDATA="${USERDATA:-$(mktemp -d /tmp/t52-userdata-XXXX)}"
export XDG_DATA_HOME="$USERDATA/xdg"
mkdir -p "$OUT" "$XDG_DATA_HOME"
cd "$ROOT"
echo "# T52 A1 restart  $(TZ=Asia/Saigon date '+%F %T ICT')" | tee "$OUT/restart.log"
echo "# head=$(git rev-parse HEAD)" | tee -a "$OUT/restart.log"
echo "# userdata=$XDG_DATA_HOME" | tee -a "$OUT/restart.log"
run_phase() {
  local phase="$1"
  local log="$OUT/${phase}.proc.log"
  timeout 180 xvfb-run -a -s "-screen 0 1920x1080x24" \
    "$G" --path "$ROOT" --script res://evidence/T52-a1/scripts/restart_t52.gd \
    -- "--out=$OUT" "--phase=$phase" > "$log" 2>&1
  local ec=$?
  echo "# phase=$phase exit=$ec" | tee -a "$OUT/restart.log"
  cat "$log" | tee -a "$OUT/restart.log"
  return $ec
}
ec=0
run_phase pick || ec=$?
run_phase restore || ec=$?
# colour_taken probe gets its own userdata so it cannot clobber the restart file mid-log
TAKEN_USER="${USERDATA}-taken"
export XDG_DATA_HOME="$TAKEN_USER/xdg"
mkdir -p "$XDG_DATA_HOME"
timeout 180 xvfb-run -a -s "-screen 0 1920x1080x24" \
  "$G" --path "$ROOT" --script res://evidence/T52-a1/scripts/restart_t52.gd \
  -- "--out=$OUT" --phase=taken > "$OUT/taken.proc.log" 2>&1 || ec=$?
{
  echo "# T52 A1 colour_taken does not overwrite save  $(TZ=Asia/Saigon date '+%F %T ICT')"
  echo "# head=$(git rev-parse HEAD) exit see restart.log"
  cat "$OUT/taken.proc.log"
} | tee "$OUT/colour-taken-save.log"
# Merge partial logs if the script wrote them (already printed via proc logs)
exit $ec
