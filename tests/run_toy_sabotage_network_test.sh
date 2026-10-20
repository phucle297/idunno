#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT/.tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
PORT="${PORT:-29940}"
PLAYER_COUNTS="${PLAYER_COUNTS:-2 4 8 20}"
MAP_IDS="${MAP_IDS:-toy_town toy_harbor}"
LOG_ROOT="$ROOT/.scratch/toy-sabotage-enet"

mkdir -p "$LOG_ROOT"
index=0
for map_id in $MAP_IDS; do
  for players in $PLAYER_COUNTS; do
    test_port=$((PORT + index)); log_dir="$LOG_ROOT/$map_id/$players-players"
    mkdir -p "$log_dir"; rm -f "$log_dir"/*.log
    timeout 180 "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/toy_sabotage_network_peer.gd -- --role=server --port="$test_port" --players="$players" --map-id="$map_id" --host-port="$test_port" >"$log_dir/server.log" 2>&1 &
    server=$!; clients=(); sleep .4
    for ((client = 1; client < players; client++)); do
      timeout 180 "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/toy_sabotage_network_peer.gd -- --role=client --port="$test_port" --players="$players" --map-id="$map_id" --join-address=127.0.0.1 --join-port="$test_port" >"$log_dir/client-$client.log" 2>&1 &
      clients+=("$!")
    done
    status=0; for pid in "${clients[@]}"; do wait "$pid" || status=1; done; wait "$server" || status=1
    cat "$log_dir/server.log"
    rg 'TOY_SABOTAGE_ENET_CLIENT_OK|SCRIPT ERROR|ERROR:|WARNING:' "$log_dir"/client-*.log || true
    if rg '^(SCRIPT ERROR|ERROR):' "$log_dir"/*.log | rg -v 'ERROR: [0-9]+ resources still in use at exit'; then status=1; fi
    [[ "$status" -eq 0 ]]
    grep -q "TOY_SABOTAGE_ENET_SERVER_OK map=$map_id players=$players" "$log_dir/server.log"
    for ((client = 1; client < players; client++)); do grep -q "TOY_SABOTAGE_ENET_CLIENT_OK map=$map_id players=$players" "$log_dir/client-$client.log"; done
    printf 'TOY_SABOTAGE_ENET_PEERS_OK map=%s players=%d clients=%d\n' "$map_id" "$players" "$((players - 1))"
    index=$((index + 1))
  done
done
printf 'TOY_SABOTAGE_ENET_MATRIX_OK maps=%s players=%s logs=%s\n' "${MAP_IDS// /,}" "${PLAYER_COUNTS// /,}" "$LOG_ROOT"
