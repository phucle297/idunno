#!/usr/bin/env bash
set -euo pipefail
mkdir -p /work
# Each process gets its own import cache and preferences; source stays read-only.
cp -a /source/project.godot /source/scenes /source/game /source/assets \
  /source/tests /source/tools /work/
cd /work
/opt/godot --headless --editor --path /work --quit > /tmp/import.log 2>&1
if grep -Eq '^(SCRIPT ERROR|ERROR):' /tmp/import.log; then
  cat /tmp/import.log
  exit 1
fi
if [[ "${1:-}" == --suite=regression ]]; then
  export GODOT_BIN=/opt/godot PYTHONDONTWRITEBYTECODE=1
  python3 -m unittest discover -s tests -p test_room_service.py -v
  /opt/godot --headless --path /work --script res://tests/test_dedicated_server.gd
  PLAYER_COUNTS='4 8 20' bash tests/run_playable_scale_test.sh
  echo CONTAINER_SOURCE_REGRESSION_OK
  exit 0
fi
touch /tmp/prepared
# The runner launches peers only after all private caches are ready. Import time
# must not consume the existing network fixture's registration deadline.
while [[ ! -f /tmp/start ]]; do sleep 0.1; done
exec /opt/godot --headless --path /work \
  --script res://tests/dedicated_network_peer.gd -- "$@"
