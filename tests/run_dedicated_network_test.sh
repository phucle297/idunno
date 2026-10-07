#!/usr/bin/env bash
set -euo pipefail
ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
GODOT_BIN="${GODOT_BIN:-godot}"
PORT="${PORT:-29760}"
LOG_DIR="$ROOT/.scratch/dedicated-network"
mkdir -p "$LOG_DIR"
pids=()
cleanup() { kill "${pids[@]}" 2>/dev/null || true; }
trap cleanup EXIT
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/dedicated_network_peer.gd -- \
  --role=server --server-port="$PORT" >"$LOG_DIR/server.log" 2>&1 &
pids+=("$!")
# Wait for positive server startup instead of assuming a fixed launch time.
for attempt in {1..100}; do
  if rg -q 'DEDICATED_SERVER_READY' "$LOG_DIR/server.log"; then break; fi
  sleep 0.1
done
rg -q 'DEDICATED_SERVER_READY' "$LOG_DIR/server.log"
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/dedicated_network_peer.gd -- \
  --role=owner --join-address=127.0.0.1 --join-port="$PORT" >"$LOG_DIR/owner.log" 2>&1 &
pids+=("$!")
for attempt in {1..100}; do
  if rg -q 'DEDICATED_CLIENT_CONNECTED role=owner' "$LOG_DIR/owner.log"; then break; fi
  sleep 0.1
done
rg -q 'DEDICATED_CLIENT_CONNECTED role=owner' "$LOG_DIR/owner.log"
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/dedicated_network_peer.gd -- \
  --role=guest --join-address=127.0.0.1 --join-port="$PORT" >"$LOG_DIR/guest.log" 2>&1 &
pids+=("$!")
status=0
for pid in "${pids[@]}"; do wait "$pid" || status=1; done
for role in server owner guest; do
  cat "$LOG_DIR/$role.log"
  rg -q "DEDICATED_NETWORK_${role^^}_OK .*rematches=5" "$LOG_DIR/$role.log" || status=1
  if rg '^(SCRIPT ERROR|ERROR):' "$LOG_DIR/$role.log" | rg -v '^ERROR: [0-9]+ resources still in use at exit'; then status=1; fi
done
if [[ "$status" -ne 0 ]]; then exit 1; fi
printf 'DEDICATED_NETWORK_OK processes=3 clients=2 movement=passed rematches=5 recovery=passed\n'
