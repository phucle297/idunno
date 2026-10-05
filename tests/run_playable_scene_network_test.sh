#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT/.tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
PORT="${PORT:-29730}"
LOG_DIR="$ROOT/.scratch/playable-scene-network"
SERVER_LOG="$LOG_DIR/server.log"
CLIENT_LOG="$LOG_DIR/client.log"

mkdir -p "$LOG_DIR"
rm -f "$SERVER_LOG" "$CLIENT_LOG"

"$GODOT_BIN" --headless --path "$ROOT" \
  --script res://tests/playable_scene_network_peer.gd -- \
  --role=server --port="$PORT" --host-port="$PORT" >"$SERVER_LOG" 2>&1 &
server_pid=$!
client_pid=""

cleanup() {
  kill "$server_pid" ${client_pid:+"$client_pid"} 2>/dev/null || true
}
trap cleanup EXIT

sleep 0.3
"$GODOT_BIN" --headless --path "$ROOT" \
  --script res://tests/playable_scene_network_peer.gd -- \
  --role=client --port="$PORT" --join-address=127.0.0.1 --join-port="$PORT" >"$CLIENT_LOG" 2>&1 &
client_pid=$!

status=0
wait "$client_pid" || status=1
wait "$server_pid" || status=1

cat "$SERVER_LOG"
cat "$CLIENT_LOG"

if [[ "$status" -ne 0 ]]; then
  echo "Playable-scene network test failed." >&2
  exit 1
fi

grep -q 'PLAYABLE_NETWORK_SERVER_OK spawned=2 remaining=1' "$SERVER_LOG"
grep -q 'PLAYABLE_NETWORK_CLIENT_OK' "$CLIENT_LOG"
printf 'PLAYABLE_SCENE_NETWORK_PEERS_OK clients=2 disconnect_cleanup=passed\n'
