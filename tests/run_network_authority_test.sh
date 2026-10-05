#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT/.tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
PORT="${PORT:-29720}"
LOG_DIR="$ROOT/.scratch/network-authority"
SERVER_LOG="$LOG_DIR/server.log"
CLIENT_LOG="$LOG_DIR/client.log"

mkdir -p "$LOG_DIR"
rm -f "$SERVER_LOG" "$CLIENT_LOG"

"$GODOT_BIN" --headless --path "$ROOT" \
  --script res://tests/network_authority_peer.gd -- \
  --role=server --port="$PORT" >"$SERVER_LOG" 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT

sleep 0.3
set +e
"$GODOT_BIN" --headless --path "$ROOT" \
  --script res://tests/network_authority_peer.gd -- \
  --role=client --port="$PORT" >"$CLIENT_LOG" 2>&1
client_status=$?
wait "$server_pid"
server_status=$?
set -e

cat "$SERVER_LOG"
cat "$CLIENT_LOG"

if [[ "$server_status" -ne 0 || "$client_status" -ne 0 ]]; then
  printf 'Network authority test failed: server=%d client=%d\n' "$server_status" "$client_status" >&2
  exit 1
fi

grep -q 'NETWORK_AUTHORITY_SERVER_OK' "$SERVER_LOG"
grep -q 'NETWORK_AUTHORITY_CLIENT_OK' "$CLIENT_LOG"
printf 'NETWORK_AUTHORITY_PEERS_OK\n'
