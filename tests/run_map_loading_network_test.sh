#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
PORT="${PORT:-29820}"
LOG_DIR="$ROOT/.scratch/map-loading-network"
mkdir -p "$LOG_DIR"
for role in server owner departing replacement; do : > "$LOG_DIR/$role.log"; done
pids=()
cleanup() { kill "${pids[@]}" 2>/dev/null || true; }
trap cleanup EXIT
run_peer() {
  local role="$1"
  shift
  timeout 45 "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/map_loading_network_peer.gd -- \
    --role="$role" --port="$PORT" "$@" >"$LOG_DIR/$role.log" 2>&1 &
  pids+=("$!")
}
run_peer server --server-port="$PORT"
for _ in {1..100}; do rg -q 'DEDICATED_SERVER_READY' "$LOG_DIR/server.log" && break; sleep 0.1; done
rg -q 'DEDICATED_SERVER_READY' "$LOG_DIR/server.log"
run_peer owner --join-address=127.0.0.1 --join-port="$PORT"
for _ in {1..100}; do rg -q 'MAP_LOADING_CONNECTED role=owner' "$LOG_DIR/owner.log" && break; sleep 0.1; done
rg -q 'MAP_LOADING_CONNECTED role=owner' "$LOG_DIR/owner.log"
run_peer departing --join-address=127.0.0.1 --join-port="$PORT"
for _ in {1..150}; do rg -q 'MAP_LOADING_CLIENT_DEPARTING_OK' "$LOG_DIR/departing.log" && break; sleep 0.1; done
rg -q 'MAP_LOADING_CLIENT_DEPARTING_OK' "$LOG_DIR/departing.log"
run_peer replacement --join-address=127.0.0.1 --join-port="$PORT"
status=0
for pid in "${pids[@]}"; do wait "$pid" || status=1; done
for role in server owner departing replacement; do
  cat "$LOG_DIR/$role.log"
  rg -q "MAP_LOADING_NETWORK_${role^^}_OK|MAP_LOADING_CLIENT_${role^^}_OK" "$LOG_DIR/$role.log" || status=1
  if rg '^(SCRIPT ERROR|ERROR):' "$LOG_DIR/$role.log" | rg -v '^ERROR: [0-9]+ resources still in use at exit'; then status=1; fi
done
rg -q 'MAP_LOADING_SERVER_BARRIER_OK held_ack=passed departure_abort=passed stale_ack=passed retry_map=toy_town' "$LOG_DIR/server.log" || status=1
[[ "$status" -eq 0 ]]
printf 'MAP_LOADING_NETWORK_OK peers=4 maps=2 held_ack=passed departure_abort=passed stale_ack=passed retry=passed\n'
