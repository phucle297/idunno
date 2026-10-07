#!/usr/bin/env bash
set -euo pipefail
ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
export GODOT_BIN="$(realpath "${GODOT_BIN:-$(command -v godot)}")"
LOG_DIR="$ROOT/.scratch/container-network"
compose=(docker compose -f "$ROOT/tools/container-tests/compose.yml")
# Fail before building or creating anything when the runtime is unavailable.
docker info >/dev/null
mkdir -p "$LOG_DIR"
cleanup() {
  "${compose[@]}" logs --no-log-prefix > "$LOG_DIR/all.log" 2>&1 || true
  "${compose[@]}" down --remove-orphans
}
trap cleanup EXIT
"${compose[@]}" build alpha
"${compose[@]}" up --no-build -d --wait --wait-timeout 120
wait_marker() {
  local service="$1" marker="$2"
  for attempt in {1..50}; do
    if "${compose[@]}" exec -T "$service" grep -q "$marker" /tmp/peer.log; then return; fi
    sleep 0.1
  done
  echo "Missing startup marker for $service: $marker" >&2
  return 1
}
for room in alpha bravo; do
  "${compose[@]}" exec -T "$room" touch /tmp/start
  wait_marker "$room" DEDICATED_SERVER_READY
done
for room in alpha bravo; do
  "${compose[@]}" exec -T "$room-owner" touch /tmp/start
  wait_marker "$room-owner" 'DEDICATED_CLIENT_CONNECTED role=owner'
done
for room in alpha bravo; do
  "${compose[@]}" exec -T "$room-guest" touch /tmp/start
done
status=0
for service in alpha bravo alpha-owner bravo-owner alpha-guest bravo-guest; do
  id="$("${compose[@]}" ps -aq "$service")"
  # docker wait has no deadline; bound the test, not the game server lifecycle.
  result="$(timeout 180 docker wait "$id")" || result=timeout
  "${compose[@]}" logs --no-log-prefix "$service" > "$LOG_DIR/$service.log"
  cat "$LOG_DIR/$service.log"
  [[ "$result" == 0 ]] || status=1
  role="${service#*-}"
  [[ "$role" != "$service" ]] || role=server
  grep -Eq "DEDICATED_NETWORK_${role^^}_OK .*rematches=5" "$LOG_DIR/$service.log" || status=1
  if grep -E '^(SCRIPT ERROR|ERROR):' "$LOG_DIR/$service.log" | \
      grep -vE '^ERROR: [0-9]+ resources still in use at exit'; then
    status=1
  fi
done
[[ "$status" == 0 ]] || exit 1
printf 'CONTAINER_NETWORK_OK rooms=2 clients_per_room=2 rematches=5 movement=passed recovery=passed\n'
"${compose[@]}" run --rm --no-deps --entrypoint bash alpha \
  /entrypoint.sh --suite=regression 2>&1 | tee "$LOG_DIR/regression.log"
grep -q CONTAINER_SOURCE_REGRESSION_OK "$LOG_DIR/regression.log"
# Only the occupied-port negative fixture and known shutdown resource diagnostic
# are expected. A suite's assertions passing must not hide other runtime errors.
if grep -E '^(SCRIPT ERROR|ERROR):' "$LOG_DIR/regression.log" | \
    grep -vE "^ERROR: ([0-9]+ resources still in use at exit|Couldn't create an ENet host\.|Unable to start requested network session: Can't create)"; then
  echo 'Container regression emitted unexpected runtime errors.' >&2
  exit 1
fi
echo CONTAINER_VALIDATION_SLICE_OK
