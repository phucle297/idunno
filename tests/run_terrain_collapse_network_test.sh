#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT/.tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
PORT="${PORT:-29820}"
PLAYER_COUNTS="${PLAYER_COUNTS:-2 4 8 20}"
MAP_IDS="${MAP_IDS:-toy_town toy_harbor}"
LOG_ROOT="$ROOT/.scratch/terrain-collapse-enet"

mkdir -p "$LOG_ROOT"
matrix_index=0
for map_id in $MAP_IDS; do
  for players in $PLAYER_COUNTS; do
    test_port=$((PORT + matrix_index))
    log_dir="$LOG_ROOT/$map_id/$players-players"
    mkdir -p "$log_dir"
    rm -f "$log_dir"/*.log
    timeout 180 "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/terrain_collapse_network_peer.gd -- --role=server --port="$test_port" --players="$players" --map-id="$map_id" --host-port="$test_port" >"$log_dir/server.log" 2>&1 &
    server_pid=$!
    client_pids=()
    sleep 0.4
    for ((client = 1; client < players; client++)); do
      timeout 180 "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/terrain_collapse_network_peer.gd -- --role=client --port="$test_port" --players="$players" --map-id="$map_id" --join-address=127.0.0.1 --join-port="$test_port" >"$log_dir/client-$client.log" 2>&1 &
      client_pids+=("$!")
    done
    status=0
    # T42 fast fail: poll every peer process. A client that exits nonzero (or
    # is killed) before the server finishes means the server can only wait out
    # its deadlines, so stop all peers now and name the cause instead of
    # waiting for `timeout 180`. Likewise a server that exits nonzero stops the
    # clients. Normal exits (exit 0) keep the original wait order.
    started=$SECONDS
    fast_fail=""
    declare -A client_done=()
    while kill -0 "$server_pid" 2>/dev/null; do
      for ((client = 1; client < players; client++)); do
        pid="${client_pids[client - 1]}"
        [[ -n "${client_done[$client]:-}" ]] && continue
        kill -0 "$pid" 2>/dev/null && continue
        ec=0; wait "$pid" || ec=$?
        client_done[$client]=$ec
        if [[ "$ec" -ne 0 ]]; then
          fast_fail="cause=client_exited client=$client exit=$ec log=$log_dir/client-$client.log"
          break 2
        fi
      done
      sleep 0.5
    done
    if [[ -z "$fast_fail" ]] && ! kill -0 "$server_pid" 2>/dev/null; then
      server_ec=0; wait "$server_pid" || server_ec=$?
      if [[ "$server_ec" -ne 0 ]]; then
        status=1
        if [[ "$server_ec" -ne 124 ]]; then
          fast_fail="cause=server_exited exit=$server_ec log=$log_dir/server.log"
        fi
      fi
    fi
    if [[ -n "$fast_fail" ]]; then
      kill "$server_pid" "${client_pids[@]}" 2>/dev/null || true
      wait "$server_pid" "${client_pids[@]}" 2>/dev/null || true
      printf 'TERRAIN_COLLAPSE_ENET_FAST_FAIL map=%s players=%d after=%ds %s\n' "$map_id" "$players" "$((SECONDS - started))" "$fast_fail" >&2
      tail -n 20 "${fast_fail##*log=}" >&2 || true
      exit 1
    fi
    for ((client = 1; client < players; client++)); do
      if [[ -n "${client_done[$client]:-}" ]]; then
        [[ "${client_done[$client]}" -eq 0 ]] || status=1
      else
        wait "${client_pids[client - 1]}" || status=1
      fi
    done
    unset client_done
    cat "$log_dir/server.log"
    rg 'TERRAIN_COLLAPSE_ENET_CLIENT_OK|SCRIPT ERROR|ERROR:|WARNING:' "$log_dir"/client-*.log || true
    if rg '^(SCRIPT ERROR|ERROR):' "$log_dir"/*.log | rg -v 'ERROR: [0-9]+ resources still in use at exit'; then status=1; fi
    [[ "$status" -eq 0 ]]
    grep -q "TERRAIN_COLLAPSE_ENET_SERVER_OK map=$map_id players=$players" "$log_dir/server.log"
    for ((client = 1; client < players; client++)); do grep -q "TERRAIN_COLLAPSE_ENET_CLIENT_OK map=$map_id players=$players" "$log_dir/client-$client.log"; done
    printf 'TERRAIN_COLLAPSE_ENET_PEERS_OK map=%s players=%d clients=%d\n' "$map_id" "$players" "$((players - 1))"
    matrix_index=$((matrix_index + 1))
  done
done
printf 'TERRAIN_COLLAPSE_ENET_MATRIX_OK maps=%s players=%s logs=%s\n' "${MAP_IDS// /,}" "${PLAYER_COUNTS// /,}" "$LOG_ROOT"
