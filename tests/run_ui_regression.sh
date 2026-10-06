#!/usr/bin/env bash
set -euo pipefail

ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
GODOT_BIN="${GODOT_BIN:-godot}"
LOG_DIR="$ROOT/.scratch/ui-regression"
mkdir -p "$LOG_DIR"

# Import first: script-mode tests need Godot's global class cache.
"$GODOT_BIN" --headless --editor --path "$ROOT" --quit > "$LOG_DIR/import.log" 2>&1
if rg -q '^(SCRIPT ERROR|ERROR):' "$LOG_DIR/import.log"; then
  cat "$LOG_DIR/import.log"
  exit 1
fi

count=0
for suite in "$ROOT"/tests/test_*.gd; do
  name="$(basename "$suite" .gd)"
  log="$LOG_DIR/$name.log"
  if ! "$GODOT_BIN" --headless --path "$ROOT" --script "res://tests/$name.gd" \
      -- --settings-path=user://ui-regression-settings.cfg > "$log" 2>&1; then
    cat "$log"
    exit 1
  fi
  # Some Godot Dummy-audio runs retain shutdown-only WAV/playback resources.
  # Never ignore parser/runtime/assertion errors or a missing positive marker.
  if ! rg -q '_OK( |$)' "$log" || \
      rg '^(SCRIPT ERROR|ERROR):' "$log" | rg -v '^ERROR: [0-9]+ resources still in use at exit'; then
    cat "$log"
    exit 1
  fi
  rg '_OK( |$)' "$log"
  count=$((count + 1))
done

"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/test_pause_settings.gd \
  -- --settings-path=user://ui-regression-settings.cfg --save-for-restart
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/test_pause_settings.gd \
  -- --settings-path=user://ui-regression-settings.cfg --verify-restart

for script in run_network_authority_test run_four_client_match_test run_playable_scene_network_test run_playable_scale_test; do
  GODOT_BIN="$GODOT_BIN" "$ROOT/tests/$script.sh"
done
printf 'UI_REGRESSION_OK suites=%d matrices=4 persistence_restart=passed\n' "$count"
