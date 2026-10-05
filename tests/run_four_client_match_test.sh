#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT/.tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
PORT="${PORT:-29721}"
CLIENT_COUNTS="${CLIENT_COUNTS:-2 4 8 20}"
LOG_ROOT="$ROOT/.scratch/multiplayer-match"

mkdir -p "$LOG_ROOT"

run_client_count() {
  local client_count="$1"
  local test_port="$2"
  local log_dir="$LOG_ROOT/$client_count-clients"
  local server_log="$log_dir/server.log"
  local server_pid
  local status=0
  local client_index
  local client_pid
  local -a client_pids=()

  mkdir -p "$log_dir"
  rm -f "$log_dir"/*.log

  "$GODOT_BIN" --headless --path "$ROOT" \
    --script res://tests/four_client_match_peer.gd -- \
    --role=server --port="$test_port" --clients="$client_count" >"$server_log" 2>&1 &
  server_pid=$!

  sleep 0.3
  for ((client_index = 1; client_index <= client_count; client_index++)); do
    "$GODOT_BIN" --headless --path "$ROOT" \
      --script res://tests/four_client_match_peer.gd -- \
      --role=client --port="$test_port" --clients="$client_count" >"$log_dir/client-$client_index.log" 2>&1 &
    client_pids+=("$!")
  done

  for client_pid in "${client_pids[@]}"; do
    wait "$client_pid" || status=1
  done
  wait "$server_pid" || status=1

  cat "$server_log"
  for ((client_index = 1; client_index <= client_count; client_index++)); do
    cat "$log_dir/client-$client_index.log"
  done

  if [[ "$status" -ne 0 ]]; then
    echo "$client_count-client match test failed." >&2
    return 1
  fi

  grep -q "MULTIPLAYER_MATCH_SERVER_OK clients=$client_count alive=$client_count hazards=2" "$server_log"
  for ((client_index = 1; client_index <= client_count; client_index++)); do
    grep -q 'MULTIPLAYER_MATCH_CLIENT_OK' "$log_dir/client-$client_index.log"
  done
  printf 'MULTIPLAYER_MATCH_PEERS_OK clients=%d\n' "$client_count"
}

test_index=0
for client_count in $CLIENT_COUNTS; do
  run_client_count "$client_count" "$((PORT + test_index))"
  test_index=$((test_index + 1))
done

printf 'MULTIPLAYER_STABILIZATION_OK client_counts=%s\n' "${CLIENT_COUNTS// /,}"
