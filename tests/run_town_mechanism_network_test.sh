#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT/.tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
PORT="${PORT:-29910}"
LOG="$ROOT/.scratch/town-mechanism-enet"
mkdir -p "$LOG"; rm -f "$LOG"/*.log
timeout 45 "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/test_town_mechanisms.gd >"$LOG/control.log" 2>&1
timeout 75 "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/town_mechanism_network_peer.gd -- --role=server --port="$PORT" --host-port="$PORT" >"$LOG/server.log" 2>&1 & server=$!
client=""
trap 'kill "$server" ${client:+$client} 2>/dev/null || true' EXIT
sleep .4
timeout 75 "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/town_mechanism_network_peer.gd -- --role=client --port="$PORT" --join-address=127.0.0.1 --join-port="$PORT" >"$LOG/client.log" 2>&1 & client=$!
status=0; wait "$client" || status=1; wait "$server" || status=1
cat "$LOG/control.log" "$LOG/server.log" "$LOG/client.log"
if rg '^(SCRIPT ERROR|ERROR):' "$LOG"/*.log | rg -v 'resources still in use at exit'; then status=1; fi
[[ "$status" -eq 0 ]]
grep -q 'TOWN_MECHANISMS_OK' "$LOG/control.log"
grep -q 'TOWN_MECHANISM_ENET_SERVER_OK guest_bridge_rpc=accepted server_carriage=passed client_reset_acks=5' "$LOG/server.log"
grep -q 'TOWN_MECHANISM_ENET_CLIENT_OK guest_bridge=accepted client_carriage=passed rematch_reset_acks=5' "$LOG/client.log"
SNAPSHOT_PORT=$((PORT + 1))
timeout 45 "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/town_mechanism_snapshot_peer.gd -- --role=server --port="$SNAPSHOT_PORT" >"$LOG/snapshot-server.log" 2>&1 & snapshot_server=$!
for _attempt in {1..100}; do
  grep -q 'TOWN_MECHANISM_SNAPSHOT_SERVER_READY moving=true weather_wet=true' "$LOG/snapshot-server.log" && break
  sleep .05
done
grep -q 'TOWN_MECHANISM_SNAPSHOT_SERVER_READY moving=true weather_wet=true' "$LOG/snapshot-server.log"
timeout 45 "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/town_mechanism_snapshot_peer.gd -- --role=client --port="$SNAPSHOT_PORT" >"$LOG/snapshot-client.log" 2>&1 & snapshot_client=$!
status=0; wait "$snapshot_client" || status=1; wait "$snapshot_server" || status=1
cat "$LOG/snapshot-server.log" "$LOG/snapshot-client.log"
if rg '^(SCRIPT ERROR|ERROR):' "$LOG"/snapshot-*.log | rg -v 'resources still in use at exit'; then status=1; fi
[[ "$status" -eq 0 ]]
grep -q 'TOWN_MECHANISM_SNAPSHOT_SERVER_OK initial_mid_transition=passed weather_state=passed' "$LOG/snapshot-server.log"
grep -q 'TOWN_MECHANISM_SNAPSHOT_CLIENT_OK initial_mid_transition=passed weather_state=passed' "$LOG/snapshot-client.log"
printf 'TOWN_MECHANISM_ENET_PEERS_OK guest_bridge=accepted carriage=server_client rematch_reset_acks=5 logs=%s\n' "$LOG"
