#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT/.tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
PORT="${PORT:-29740}"
PLAYER_COUNTS="${PLAYER_COUNTS:-4 8 20}"
LOG_ROOT="$ROOT/.scratch/playable-scale"

mkdir -p "$LOG_ROOT"

run_player_count() {
  local player_count="$1"
  local test_port="$2"
  local client_count=$((player_count - 1))
  local log_dir="$LOG_ROOT/$player_count-players"
  local server_log="$log_dir/server.log"
  local server_pid
  local status=0
  local client_index
  local client_pid
  local -a client_pids=()

  mkdir -p "$log_dir"
  rm -f "$log_dir"/*.log

  "$GODOT_BIN" --headless --path "$ROOT" \
    --script res://tests/playable_scale_peer.gd -- \
    --role=server --port="$test_port" --players="$player_count" --host-port="$test_port" >"$server_log" 2>&1 &
  server_pid=$!

  sleep 0.4
  for ((client_index = 1; client_index <= client_count; client_index++)); do
    "$GODOT_BIN" --headless --path "$ROOT" \
      --script res://tests/playable_scale_peer.gd -- \
      --role=client --port="$test_port" --players="$player_count" --join-address=127.0.0.1 --join-port="$test_port" >"$log_dir/client-$client_index.log" 2>&1 &
    client_pids+=("$!")
  done

  for client_pid in "${client_pids[@]}"; do
    wait "$client_pid" || status=1
  done
  wait "$server_pid" || status=1

  cat "$server_log"
  for ((client_index = 1; client_index <= client_count; client_index++)); do
    grep -E "PLAYABLE_SCALE_CLIENT_OK|Playable scale client failed|ERROR:|WARNING:" "$log_dir/client-$client_index.log" || true
  done

  if [[ "$status" -ne 0 ]]; then
    echo "$player_count-player playable-scale test failed." >&2
    return 1
  fi

  grep -q "PLAYABLE_SCALE_SERVER_OK players=$player_count movement=passed match_hud=passed disaster=passed disconnect_cleanup=passed" "$server_log"
  for ((client_index = 1; client_index <= client_count; client_index++)); do
    grep -q "PLAYABLE_SCALE_CLIENT_OK players=$player_count" "$log_dir/client-$client_index.log"
  done
  printf 'PLAYABLE_SCALE_PEERS_OK players=%d clients=%d\n' "$player_count" "$client_count"
}

test_index=0
for player_count in $PLAYER_COUNTS; do
  run_player_count "$player_count" "$((PORT + test_index))"
  test_index=$((test_index + 1))
done

printf 'PLAYABLE_SCALE_MATRIX_OK players=%s\n' "${PLAYER_COUNTS// /,}"
