#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT/.tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
PORT="${PORT:-29721}"
LOG_DIR="$ROOT/.scratch/four-client-match"
SERVER_LOG="$LOG_DIR/server.log"

mkdir -p "$LOG_DIR"
rm -f "$LOG_DIR"/*.log

"$GODOT_BIN" --headless --path "$ROOT" \
  --script res://tests/four_client_match_peer.gd -- \
  --role=server --port="$PORT" >"$SERVER_LOG" 2>&1 &
server_pid=$!
client_pids=()

cleanup() {
  kill "$server_pid" "${client_pids[@]}" 2>/dev/null || true
}
trap cleanup EXIT

sleep 0.3
for client_index in 1 2 3 4; do
  "$GODOT_BIN" --headless --path "$ROOT" \
    --script res://tests/four_client_match_peer.gd -- \
    --role=client --port="$PORT" >"$LOG_DIR/client-$client_index.log" 2>&1 &
  client_pids+=("$!")
done

status=0
for client_pid in "${client_pids[@]}"; do
  wait "$client_pid" || status=1
done
wait "$server_pid" || status=1

cat "$SERVER_LOG"
for client_index in 1 2 3 4; do
  cat "$LOG_DIR/client-$client_index.log"
done

if [[ "$status" -ne 0 ]]; then
  echo "Four-client match test failed." >&2
  exit 1
fi

grep -q 'FOUR_CLIENT_MATCH_SERVER_OK clients=4 alive=4 hazards=2' "$SERVER_LOG"
for client_index in 1 2 3 4; do
  grep -q 'FOUR_CLIENT_MATCH_CLIENT_OK' "$LOG_DIR/client-$client_index.log"
done
printf 'FOUR_CLIENT_MATCH_PEERS_OK clients=4\n'
