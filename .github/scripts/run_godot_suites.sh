#!/usr/bin/env bash
# CI Godot suites: headless import, then tests/test_*.gd, in parallel with a
# per-suite timeout. Pass criteria mirror tools/test_changed.py: exit 0, a
# *_OK marker, no ERROR lines (except Godot's shutdown-only
# "resources still in use at exit").
# blocking (default): every suite except the slow list (manual full regression)
# and Godot names listed in tests/FLAKY.md (those run in the non-blocking
# flake job). flaky: only the Godot names in tests/FLAKY.md.
# Remove a FLAKY.md id to make that suite blocking again. Nothing is skipped
# or deleted.
set -euo pipefail
GODOT_BIN="${GODOT_BIN:-godot}"
JOBS="${JOBS:-$(nproc)}"
SUITE_TIMEOUT="${SUITE_TIMEOUT:-600}"
LOG_DIR="${LOG_DIR:-.scratch/ci-suites}"
SLOW_LIST="${SLOW_LIST:-.github/slow-suites.txt}"
FLAKE_LIST="${FLAKE_LIST:-tests/FLAKY.md}"
MODE=blocking
for arg in "$@"; do
  case "$arg" in
    --mode=blocking|--mode=flaky) MODE="${arg#--mode=}" ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done
mkdir -p "$LOG_DIR"
export GODOT_BIN SUITE_TIMEOUT LOG_DIR

"$GODOT_BIN" --headless --editor --path . --quit > "$LOG_DIR/import.log" 2>&1 || { cat "$LOG_DIR/import.log"; exit 1; }
if grep -E '^(SCRIPT ERROR|ERROR):' "$LOG_DIR/import.log"; then
  echo "::error::Headless import reported errors"; exit 1
fi
echo "IMPORT_OK"

mapfile -t slow < <(grep -vE '^\s*(#|$)' "$SLOW_LIST" || true)
mapfile -t flaky_godot < <(python3 .github/scripts/run_python_tests.py --list-godot)
suites=()
if [[ "$MODE" == flaky ]]; then
  suites+=("${flaky_godot[@]}")
else
  for path in tests/test_*.gd; do
    name="$(basename "$path" .gd)"
    [[ " ${slow[*]} " == *" $name "* ]] && continue
    [[ " ${flaky_godot[*]} " == *" $name "* ]] && continue
    suites+=("$name")
  done
fi
echo "MODE=$MODE Running ${#suites[@]} suites with JOBS=$JOBS timeout=${SUITE_TIMEOUT}s (slow, manual-only: ${slow[*]}; flaky-godot: ${flaky_godot[*]})"
if [[ ${#suites[@]} -eq 0 ]]; then
  echo "No Godot suites in this mode; OK"
  exit 0
fi

run_one() {
  local name="$1" log="$LOG_DIR/$1.log" start ec errs marker
  start=$(date +%s)
  ec=0
  timeout "$SUITE_TIMEOUT" "$GODOT_BIN" --headless --path . --script "res://tests/$name.gd" \
    -- "--settings-path=user://ci-$name.cfg" > "$log" 2>&1 || ec=$?
  if [[ "$name" == test_pause_settings && $ec == 0 ]]; then
    for mode in --save-for-restart --verify-restart; do
      timeout "$SUITE_TIMEOUT" "$GODOT_BIN" --headless --path . --script "res://tests/$name.gd" \
        -- "--settings-path=user://ci-$name.cfg" "$mode" >> "$log" 2>&1 || ec=$?
    done
  fi
  errs=$(grep -E '^(SCRIPT ERROR|ERROR):' "$log" | grep -cvE '^ERROR: [0-9]+ resources still in use at exit' || true)
  marker=$(grep -oE '^[A-Z0-9_]+_OK( |$)' "$log" | tail -1 | tr -d ' ' || true)
  local status=PASS
  if [[ $ec != 0 || $errs != 0 || -z "$marker" ]]; then status=FAIL; fi
  printf '%s %s exit=%s errors=%s wall=%ss marker=%s\n' "$status" "$name" "$ec" "$errs" "$(( $(date +%s) - start ))" "${marker:-NONE}"
}
export -f run_one
printf '%s\n' "${suites[@]}" | xargs -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {} | tee "$LOG_DIR/summary.txt"

fails=$(grep -c '^FAIL ' "$LOG_DIR/summary.txt" || true)
total=$(wc -l < "$LOG_DIR/summary.txt")
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  { echo "### Godot suites: $((total - fails))/$total passed"; echo '```'; sort "$LOG_DIR/summary.txt"; echo '```'; } >> "$GITHUB_STEP_SUMMARY"
fi
if [[ "$fails" != 0 ]]; then
  for name in $(awk '/^FAIL /{print $2}' "$LOG_DIR/summary.txt"); do
    echo "::group::$name.log (tail)"; tail -60 "$LOG_DIR/$name.log"; echo "::endgroup::"
  done
  echo "::error::$fails/$total Godot suites failed"; exit 1
fi
echo "CI_SUITES_OK suites=$total"
